import { QueryFailedError } from 'typeorm';

import { BookingsService } from '../src/modules/bookings/bookings.service';
import { BookingProviderRegistry } from '../src/modules/bookings/booking-provider.registry';
import { BookingException } from '../src/modules/bookings/booking.exception';
import {
  BookingProvider,
  BookingRevalidation,
  CreatedBooking,
  CreateBookingInput,
  ProviderConfirmationState,
} from '../src/common/providers/booking-provider.interface';
import { ProviderResult } from '../src/common/providers/provider.result';
import {
  classifyBookingTransportFailure,
  failureKindFromHttpStatus,
  failureKindFromProviderMessage,
} from '../src/common/providers/booking-failure';
import { PrepareBookingDto } from '../src/common/dto/booking.dto';

/**
 * Booking lifecycle — ambiguous provider outcomes (reconciliation).
 *
 * A provider create call that times out, loses its response, returns 5xx or
 * returns an unclassified failure may already have created a booking. Such an
 * outcome MUST:
 *  - persist a durable reconciliation-pending state and keep the idempotency
 *    key;
 *  - never submit the provider booking again, even on retry or a concurrent
 *    request;
 *  - never claim the booking failed (failure invites a retry);
 *  - expose only the explicit, admin-only reconciliation path.
 *
 * A definitive rejection keeps the old safe-to-retry behaviour; a definitive
 * success confirms and stores the provider reference.
 */

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

function deferred<T = void>() {
  let resolve!: (value: T) => void;
  let reject!: (error: unknown) => void;
  const promise = new Promise<T>((res, rej) => {
    resolve = res;
    reject = rej;
  });
  return { promise, resolve, reject };
}

class FakeBookingRepo {
  rows: any[] = [];
  private seq = 0;
  private findOneBarrier?: {
    n: number;
    entered: number;
    release: () => void;
    promise: Promise<void>;
  };

  setFindOneBarrier(n: number): void {
    const gate = deferred<void>();
    this.findOneBarrier = {
      n,
      entered: 0,
      release: gate.resolve,
      promise: gate.promise,
    };
  }

  create(obj: any): any {
    return {
      ...obj,
      id: obj.id ?? `b${++this.seq}`,
      createdAt: new Date(),
      updatedAt: new Date(),
    };
  }

  async save(booking: any): Promise<any> {
    if (booking.idempotencyKey != null) {
      const clash = this.rows.find(
        (r) =>
          r.id !== booking.id &&
          r.userId === booking.userId &&
          r.idempotencyKey === booking.idempotencyKey,
      );
      if (clash) {
        throw new QueryFailedError('INSERT', [], { code: '23505' } as any);
      }
    }
    const idx = this.rows.findIndex((r) => r.id === booking.id);
    if (idx >= 0) this.rows[idx] = booking;
    else this.rows.push(booking);
    booking.updatedAt = new Date();
    return booking;
  }

  async findOne({ where }: any): Promise<any | null> {
    if (this.findOneBarrier) {
      const barrier = this.findOneBarrier;
      barrier.entered += 1;
      if (barrier.entered >= barrier.n) barrier.release();
      await barrier.promise;
    }
    return (
      this.rows.find((r) => {
        if (where.id !== undefined && r.id !== where.id) return false;
        if (where.userId !== undefined && r.userId !== where.userId) return false;
        return true;
      }) ?? null
    );
  }

  /** Models a conditional Postgres UPDATE (current row state decides). */
  async update(criteria: any, partial: any): Promise<{ affected: number }> {
    const statusCriteria = criteria.status;
    let allowed: any[] | null = null;
    if (statusCriteria && typeof statusCriteria === 'object') {
      const value = (statusCriteria as any).value;
      allowed = Array.isArray(value) ? value : [value];
    } else if (Array.isArray(statusCriteria)) {
      allowed = statusCriteria;
    } else if (statusCriteria !== undefined) {
      allowed = [statusCriteria];
    }
    const matches = this.rows.filter((r) => {
      if (criteria.id !== undefined && r.id !== criteria.id) return false;
      if (criteria.userId !== undefined && r.userId !== criteria.userId) return false;
      if (allowed && !allowed.includes(r.status)) return false;
      return true;
    });
    for (const row of matches) Object.assign(row, partial);
    return { affected: matches.length };
  }
}

class FakeOperationRepo {
  rows: any[] = [];
  private seq = 0;
  findOneCalls = 0;
  updateAttempts: Array<{
    criteria: any;
    partial: any;
    affected?: number;
  }> = [];
  /** Make a ledger write fail before it is applied (durability failure). */
  failUpdateStatus?: string;
  private updateGate?: {
    targetStatus: string;
    used: boolean;
    entered: () => void;
    promise: Promise<void>;
  };

  /**
   * Pause the first ledger update that targets [status] immediately before it
   * is applied. This deterministically opens the exact window between the
   * ambiguous booking save and its late ledger write.
   */
  setUpdateGate(targetStatus: string): {
    entered: Promise<void>;
    release: () => void;
  } {
    const gate = deferred<void>();
    const entered = deferred<void>();
    this.updateGate = {
      targetStatus,
      used: false,
      entered: () => entered.resolve(),
      promise: gate.promise,
    };
    return { entered: entered.promise, release: gate.resolve };
  }

  create(obj: any): any {
    return {
      ...obj,
      id: obj.id ?? `op${++this.seq}`,
      createdAt: new Date(),
      updatedAt: new Date(),
    };
  }

  async save(operation: any): Promise<any> {
    const clash = this.rows.find(
      (r) =>
        r.id !== operation.id &&
        r.providerId === operation.providerId &&
        r.idempotencyKey === operation.idempotencyKey,
    );
    if (clash) {
      throw new QueryFailedError('INSERT', [], { code: '23505' } as any);
    }
    const idx = this.rows.findIndex((r) => r.id === operation.id);
    if (idx >= 0) this.rows[idx] = operation;
    else this.rows.push(operation);
    operation.updatedAt = new Date();
    return operation;
  }

  async findOne({ where }: any): Promise<any | null> {
    this.findOneCalls += 1;
    return (
      this.rows.find((r) => {
        if (where.id !== undefined && r.id !== where.id) return false;
        if (where.providerId !== undefined && r.providerId !== where.providerId) {
          return false;
        }
        if (
          where.idempotencyKey !== undefined &&
          r.idempotencyKey !== where.idempotencyKey
        ) {
          return false;
        }
        return true;
      }) ?? null
    );
  }

  async update(criteria: any, partial: any): Promise<{ affected: number }> {
    const attempt = { criteria, partial } as {
      criteria: any;
      partial: any;
      affected?: number;
    };
    this.updateAttempts.push(attempt);

    if (this.failUpdateStatus && partial.status === this.failUpdateStatus) {
      throw new Error('provider operation ledger unavailable');
    }

    const gate = this.updateGate;
    if (gate && !gate.used && partial.status === gate.targetStatus) {
      gate.used = true;
      gate.entered();
      await gate.promise;
    }

    const statusCriteria = criteria.status;
    let allowed: any[] | null = null;
    if (statusCriteria && typeof statusCriteria === 'object') {
      const value = (statusCriteria as any).value;
      allowed = Array.isArray(value) ? value : [value];
    } else if (Array.isArray(statusCriteria)) {
      allowed = statusCriteria;
    } else if (statusCriteria !== undefined) {
      allowed = [statusCriteria];
    }
    const matches = this.rows.filter((r) => {
      if (criteria.id !== undefined && r.id !== criteria.id) return false;
      if (allowed && !allowed.includes(r.status)) return false;
      return true;
    });
    for (const row of matches) Object.assign(row, partial);
    attempt.affected = matches.length;
    return { affected: matches.length };
  }
}

type CreateMode =
  | 'success'
  | 'success_no_reference'
  | 'definitive'
  | 'ambiguous'
  | 'unclassified'
  | 'throw';

class StubProvider implements BookingProvider {
  readonly providerId = 'stub-hotel';
  readonly providerName = 'Stub Hotel';
  readonly bookingCapability = { book: true, cancel: false, revalidate: true };

  price = 100;
  currency = 'USD';
  handoff: Record<string, any> = { prebookId: 'pb-1', roomCount: 1 };

  revalidateCalls = 0;
  createCalls = 0;
  createMode: CreateMode = 'success';
  createError = 'provider outcome unknown';
  createGate?: Promise<void>;
  lastCreateInput?: CreateBookingInput;
  /** Provider truth for the success-shaped result. */
  createdStatus: string | undefined = 'CONFIRMED';
  createdConfirmationState?: ProviderConfirmationState;
  createdAmount?: number;
  createdCurrency?: string;

  async revalidateBooking(): Promise<ProviderResult<BookingRevalidation>> {
    this.revalidateCalls += 1;
    return {
      success: true,
      providerId: this.providerId,
      providerName: this.providerName,
      data: {
        price: this.price,
        currency: this.currency,
        available: true,
        expiresAt: new Date(Date.now() + 60_000).toISOString(),
        handoff: this.handoff,
      },
      timestamp: new Date(),
    };
  }

  async createBooking(
    input: CreateBookingInput,
  ): Promise<ProviderResult<CreatedBooking>> {
    this.createCalls += 1;
    this.lastCreateInput = input;
    if (this.createGate) await this.createGate;

    if (this.createMode === 'throw') {
      throw new Error(this.createError);
    }
    if (this.createMode === 'definitive') {
      return {
        success: false,
        providerId: this.providerId,
        providerName: this.providerName,
        error: this.createError,
        failureKind: 'definitive',
        timestamp: new Date(),
      };
    }
    if (this.createMode === 'ambiguous') {
      return {
        success: false,
        providerId: this.providerId,
        providerName: this.providerName,
        error: this.createError,
        failureKind: 'ambiguous',
        timestamp: new Date(),
      };
    }
    if (this.createMode === 'unclassified') {
      // Missing classification MUST be treated as ambiguous by the service.
      return {
        success: false,
        providerId: this.providerId,
        providerName: this.providerName,
        error: this.createError,
        timestamp: new Date(),
      };
    }
    if (this.createMode === 'success_no_reference') {
      return {
        success: true,
        providerId: this.providerId,
        providerName: this.providerName,
        data: { reference: '', providerBookingId: 'ord-no-ref' },
        timestamp: new Date(),
      };
    }
    return {
      success: true,
      providerId: this.providerId,
      providerName: this.providerName,
      data: {
        reference: 'PNR-1',
        providerBookingId: 'ord-1',
        status: this.createdStatus,
        ...(this.createdConfirmationState
          ? { confirmationState: this.createdConfirmationState }
          : {}),
        amount: this.createdAmount ?? this.price,
        currency: this.createdCurrency ?? this.currency,
      },
      timestamp: new Date(),
    };
  }
}

function setup(provider: StubProvider = new StubProvider()) {
  const repo = new FakeBookingRepo();
  const operations = new FakeOperationRepo();
  const registry = new BookingProviderRegistry();
  registry.register(provider);
  const service = new BookingsService(
    repo as any,
    registry,
    undefined,
    operations as any,
  );
  return { repo, operations, registry, service, provider };
}

const prepareDto: PrepareBookingDto = {
  offerId: 'offer-1',
  providerId: 'stub-hotel',
  searchId: 's1',
  offerType: 'hotel',
};

const createDto = (bookingId: string, key: string) => ({
  bookingId,
  idempotencyKey: key,
  travelers: [{ firstName: 'A', lastName: 'B', email: 'a@example.com' }],
});

async function drainMicrotasks(ticks = 300): Promise<void> {
  for (let i = 0; i < ticks; i += 1) {
    await Promise.resolve();
  }
}

/** Capture a rejection and require it to be a BookingException. */
async function rejection(fn: () => Promise<unknown>): Promise<BookingException> {
  let caught: unknown;
  try {
    await fn();
  } catch (error) {
    caught = error;
  }
  expect(caught).toBeInstanceOf(BookingException);
  return caught as BookingException;
}

function responseDetails(error: BookingException): Record<string, any> {
  const body = error.getResponse() as { details?: Record<string, any> };
  return body.details ?? {};
}

async function prepare(service: BookingsService) {
  return service.prepare('u1', prepareDto);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('BookingsService — ambiguous provider outcome', () => {
  it('persists reconciliation_pending and keeps the key when the response is lost after submission', async () => {
    const provider = new StubProvider();
    provider.createMode = 'ambiguous';
    provider.createError = 'socket hang up after the request was sent';
    const { repo, operations, service } = setup(provider);
    const prepared = await prepare(service);

    const error = await rejection(() =>
      service.create('u1', createDto(prepared.id, 'k1')),
    );

    expect(error.code).toBe('booking_outcome_unknown');
    expect(BookingException.statusFor('booking_outcome_unknown')).toBe(409);
    expect(error.message).not.toMatch(/failed/i);

    const details = responseDetails(error);
    expect(details).toMatchObject({
      bookingId: prepared.id,
      status: 'reconciliation_pending',
      providerId: 'stub-hotel',
      offerId: 'offer-1',
      idempotencyKey: 'k1',
      requiresReconciliation: true,
      retryable: false,
      reconciliation: {
        method: 'POST',
        path: `/bookings/${prepared.id}/reconcile`,
        adminOnly: true,
      },
    });

    const row = repo.rows.find((r) => r.id === prepared.id);
    expect(row.status).toBe('reconciliation_pending');
    expect(row.idempotencyKey).toBe('k1');
    expect(row.providerMetadata.providerBookingAttempt).toMatchObject({
      outcome: 'unknown',
      failureKind: 'ambiguous',
      requiresReconciliation: true,
      retryable: false,
      operationId: details.operationId,
      operationKey: `${prepared.id}:k1`,
    });
    expect(row.providerMetadata.providerBookingAttempt.error).toContain(
      'socket hang up',
    );

    const operation = operations.rows.find(
      (r) => r.idempotencyKey === `${prepared.id}:k1`,
    );
    expect(operation).toMatchObject({
      bookingId: prepared.id,
      providerId: 'stub-hotel',
      operation: 'create_booking',
      status: 'unknown',
      providerRef: null,
    });
    expect(operation.responseMetadata.error).toContain('socket hang up');
    expect(provider.createCalls).toBe(1);
  });

  it('treats a timeout/abort after submission as ambiguous, never as a rejection', async () => {
    const provider = new StubProvider();
    provider.createMode = 'throw';
    provider.createError = 'The operation was aborted due to timeout';
    const { repo, operations, service } = setup(provider);
    const prepared = await prepare(service);

    const error = await rejection(() =>
      service.create('u1', createDto(prepared.id, 'k1')),
    );

    expect(error.code).toBe('booking_outcome_unknown');
    const row = repo.rows.find((r) => r.id === prepared.id);
    expect(row.status).toBe('reconciliation_pending');
    expect(row.idempotencyKey).toBe('k1');
    expect(operations.rows[0].status).toBe('unknown');
    expect(operations.rows[0].responseMetadata.error).toContain('timeout');
    expect(provider.createCalls).toBe(1);
  });

  it('treats a missing failure classification as ambiguous (fail-safe default)', async () => {
    const provider = new StubProvider();
    provider.createMode = 'unclassified';
    provider.createError = 'vendor returned an unexplained error';
    const { repo, operations, service } = setup(provider);
    const prepared = await prepare(service);

    const error = await rejection(() =>
      service.create('u1', createDto(prepared.id, 'k1')),
    );

    expect(error.code).toBe('booking_outcome_unknown');
    expect(repo.rows[0].status).toBe('reconciliation_pending');
    expect(repo.rows[0].idempotencyKey).toBe('k1');
    expect(operations.rows[0].status).toBe('unknown');
    expect(provider.createCalls).toBe(1);
  });

  it('a success response without a usable reference is ambiguous, not confirmed', async () => {
    const provider = new StubProvider();
    provider.createMode = 'success_no_reference';
    const { repo, operations, service } = setup(provider);
    const prepared = await prepare(service);

    const error = await rejection(() =>
      service.create('u1', createDto(prepared.id, 'k1')),
    );

    expect(error.code).toBe('booking_outcome_unknown');
    expect(repo.rows[0].status).toBe('reconciliation_pending');
    expect(repo.rows[0].idempotencyKey).toBe('k1');
    expect(repo.rows[0].bookingReference ?? null).toBeNull();
    expect(operations.rows[0].status).toBe('unknown');
    expect(provider.createCalls).toBe(1);
  });

  it('retrying the same idempotency key returns the stored unknown result without a provider call', async () => {
    const provider = new StubProvider();
    provider.createMode = 'ambiguous';
    provider.createError = 'lost response';
    const { repo, operations, service } = setup(provider);
    const prepared = await prepare(service);

    await rejection(() => service.create('u1', createDto(prepared.id, 'k1')));

    const retry = await rejection(() =>
      service.create('u1', createDto(prepared.id, 'k1')),
    );

    expect(retry.code).toBe('booking_outcome_unknown');
    expect(responseDetails(retry)).toMatchObject({
      status: 'reconciliation_pending',
      retryable: false,
      requiresReconciliation: true,
      operationStatus: 'unknown',
    });
    expect(provider.createCalls).toBe(1);

    // A DIFFERENT key cannot escape the unknown state either.
    const differentKey = await rejection(() =>
      service.create('u1', createDto(prepared.id, 'k2')),
    );
    expect(differentKey.code).toBe('booking_outcome_unknown');
    expect(provider.createCalls).toBe(1);

    const row = repo.rows.find((r) => r.id === prepared.id);
    expect(row.status).toBe('reconciliation_pending');
    expect(row.idempotencyKey).toBe('k1');
    expect(operations.rows).toHaveLength(1);
    expect(operations.rows[0].status).toBe('unknown');
  });

  it('two concurrent requests for one booking submit exactly one provider booking', async () => {
    const provider = new StubProvider();
    provider.createMode = 'ambiguous';
    provider.createError = 'response lost while the provider was processing';
    const { repo, operations, service } = setup(provider);
    const prepared = await prepare(service);

    repo.setFindOneBarrier(2);
    const gate = deferred<void>();
    provider.createGate = gate.promise;

    const first = service.create('u1', createDto(prepared.id, 'k1'));
    const second = service.create('u1', createDto(prepared.id, 'k1'));

    await drainMicrotasks();
    expect(provider.createCalls).toBe(1);

    const secondError = await rejection(() => second);
    expect(secondError.code).toBe('duplicate_request');

    gate.resolve();
    const firstError = await rejection(() => first);
    expect(firstError.code).toBe('booking_outcome_unknown');

    expect(provider.createCalls).toBe(1);
    expect(repo.rows[0].status).toBe('reconciliation_pending');
    expect(repo.rows[0].idempotencyKey).toBe('k1');
    expect(operations.rows).toHaveLength(1);
    expect(operations.rows[0].status).toBe('unknown');
  });

  it('a definitive rejection keeps the existing failure behaviour and allows an explicit retry', async () => {
    const provider = new StubProvider();
    provider.createMode = 'definitive';
    provider.createError = 'offer is no longer available';
    const { repo, operations, service } = setup(provider);
    const prepared = await prepare(service);

    const error = await rejection(() =>
      service.create('u1', createDto(prepared.id, 'k1')),
    );
    expect(error.code).toBe('provider_error');

    const failed = repo.rows.find((r) => r.id === prepared.id);
    expect(failed.status).toBe('failed');
    expect(failed.idempotencyKey).toBeNull();
    expect(operations.rows[0].status).toBe('failed');
    expect(operations.rows[0].responseMetadata.error).toContain(
      'no longer available',
    );
    expect(provider.createCalls).toBe(1);

    provider.createMode = 'success';
    const confirmed = await service.create('u1', createDto(prepared.id, 'k2'));
    expect(confirmed.status).toBe('confirmed');
    expect(confirmed.bookingReference).toBe('PNR-1');
    expect(provider.createCalls).toBe(2);
    expect(operations.rows).toHaveLength(2);
    expect(operations.rows[1]).toMatchObject({
      idempotencyKey: `${prepared.id}:k2`,
      status: 'confirmed',
      providerRef: 'ord-1',
    });
  });

  it('a definitive success confirms, stores the reference and replays without a second call', async () => {
    const provider = new StubProvider();
    const { repo, operations, service } = setup(provider);
    const prepared = await prepare(service);

    const confirmed = await service.create('u1', createDto(prepared.id, 'k1'));

    expect(confirmed.status).toBe('confirmed');
    expect(confirmed.bookingReference).toBe('PNR-1');
    const row = repo.rows.find((r) => r.id === prepared.id);
    expect(row.status).toBe('confirmed');
    expect(row.idempotencyKey).toBe('k1');
    expect(row.providerMetadata.providerBookingAttempt).toMatchObject({
      outcome: 'confirmed',
      requiresReconciliation: false,
      retryable: false,
    });
    expect(operations.rows[0]).toMatchObject({
      status: 'confirmed',
      providerRef: 'ord-1',
    });

    const replay = await service.create('u1', createDto(prepared.id, 'k1'));
    expect(replay.status).toBe('confirmed');
    expect(replay.bookingReference).toBe('PNR-1');
    expect(provider.createCalls).toBe(1);
  });

  it('reconciliation can confirm a booking that exists at the provider without re-booking it', async () => {
    const provider = new StubProvider();
    provider.createMode = 'ambiguous';
    provider.createError = 'gateway timed out';
    const { repo, operations, service } = setup(provider);
    const prepared = await prepare(service);

    await rejection(() => service.create('u1', createDto(prepared.id, 'k1')));
    expect(provider.createCalls).toBe(1);

    const reconciled = await service.reconcile('admin-1', prepared.id, {
      outcome: 'confirmed',
      providerReference: 'PNR-RECONCILED',
      providerBookingId: 'ord-rec',
      note: 'verified in the provider dashboard',
    });

    expect(reconciled.status).toBe('confirmed');
    expect(reconciled.bookingReference).toBe('PNR-RECONCILED');
    const row = repo.rows.find((r) => r.id === prepared.id);
    // The logical identity is preserved: the reconciled booking keeps its key.
    expect(row.idempotencyKey).toBe('k1');
    expect(row.providerMetadata.providerBookingAttempt).toMatchObject({
      outcome: 'confirmed',
      requiresReconciliation: false,
      reconciliation: {
        outcome: 'confirmed',
        reference: 'PNR-RECONCILED',
        providerBookingId: 'ord-rec',
        source: 'admin_endpoint',
      },
    });
    expect(operations.rows[0]).toMatchObject({
      status: 'confirmed',
      providerRef: 'ord-rec',
    });
    // Reconciliation never calls the provider create endpoint again.
    expect(provider.createCalls).toBe(1);

    const replay = await service.create('u1', createDto(prepared.id, 'k1'));
    expect(replay.status).toBe('confirmed');
    expect(provider.createCalls).toBe(1);
  });

  it('reconciliation can prove no booking exists and only then allow a safe retry', async () => {
    const provider = new StubProvider();
    provider.createMode = 'ambiguous';
    provider.createError = 'timeout before any response';
    const { repo, operations, service } = setup(provider);
    const prepared = await prepare(service);

    await rejection(() => service.create('u1', createDto(prepared.id, 'k1')));
    const operationId = operations.rows[0].id;
    expect(provider.createCalls).toBe(1);

    const reconciled = await service.reconcile('admin-1', prepared.id, {
      outcome: 'not_found',
      note: 'provider confirms no booking for this attempt',
    });

    expect(reconciled.status).toBe('failed');
    const row = repo.rows.find((r) => r.id === prepared.id);
    expect(row.status).toBe('failed');
    expect(row.idempotencyKey).toBeNull();
    expect(row.providerMetadata.providerBookingAttempt).toMatchObject({
      outcome: 'not_found',
      reconciliationOutcome: 'not_found',
      requiresReconciliation: false,
      retryable: true,
    });
    expect(operations.rows[0]).toMatchObject({
      id: operationId,
      status: 'not_found',
      providerRef: null,
    });
    // No automatic retry happened during reconciliation.
    expect(provider.createCalls).toBe(1);

    // A new EXPLICIT attempt is now permitted. It reuses the same operation
    // identity and records the second attempt.
    provider.createMode = 'success';
    const confirmed = await service.create('u1', createDto(prepared.id, 'k1'));
    expect(confirmed.status).toBe('confirmed');
    expect(provider.createCalls).toBe(2);
    expect(operations.rows).toHaveLength(1);
    expect(operations.rows[0]).toMatchObject({
      id: operationId,
      status: 'confirmed',
      providerRef: 'ord-1',
    });
    expect(operations.rows[0].requestMetadata.attempt).toBe(2);
  });

  it('a reconciled-confirmed booking can never be overwritten as not_found', async () => {
    const provider = new StubProvider();
    const { repo, operations, service } = setup(provider);
    const prepared = await prepare(service);

    await service.create('u1', createDto(prepared.id, 'k1'));

    const error = await rejection(() =>
      service.reconcile('admin-1', prepared.id, { outcome: 'not_found' }),
    );
    expect(error.code).toBe('validation_failed');
    expect(repo.rows[0].status).toBe('confirmed');
    expect(operations.rows[0].status).toBe('confirmed');
    expect(provider.createCalls).toBe(1);
  });

  it('a late ambiguous ledger write cannot downgrade a reconciled operation', async () => {
    const provider = new StubProvider();
    provider.createMode = 'ambiguous';
    provider.createError = 'response lost';
    const { operations, service } = setup(provider);
    const prepared = await prepare(service);

    await rejection(() => service.create('u1', createDto(prepared.id, 'k1')));
    const operationId = operations.rows[0].id;

    await service.reconcile('admin-1', prepared.id, {
      outcome: 'confirmed',
      providerReference: 'PNR-RECONCILED',
    });
    expect(operations.rows[0].status).toBe('confirmed');

    // Simulate the create path's best-effort ledger write arriving after the
    // operator resolution. It is conditional on `pending`, so it must lose
    // the compare-and-set rather than replace the recorded confirmation.
    const updatesBefore = operations.updateAttempts.length;
    const readsBefore = operations.findOneCalls;
    const outcome = await (service as any).completeProviderOperation(
      operationId,
      'unknown',
      { outcome: 'ambiguous' },
      undefined,
      ['pending'],
    );

    // A zero-row conditional update reads the durable row back and reports the
    // preserved state; it never retries the write without its condition.
    expect(outcome).toEqual({ applied: false, currentStatus: 'confirmed' });
    expect(operations.updateAttempts).toHaveLength(updatesBefore + 1);
    expect(operations.updateAttempts[updatesBefore].criteria.status).toBeDefined();
    expect(operations.updateAttempts[updatesBefore].affected).toBe(0);
    expect(operations.findOneCalls).toBe(readsBefore + 1);

    expect(operations.rows[0].status).toBe('confirmed');
    expect(operations.rows[0].providerRef).toBe('PNR-RECONCILED');
    expect(provider.createCalls).toBe(1);
  });

  it('an admin confirmation that lands before the late unknown write is preserved', async () => {
    const provider = new StubProvider();
    provider.createMode = 'ambiguous';
    provider.createError = 'response lost';
    const { repo, operations, service } = setup(provider);
    const prepared = await prepare(service);

    // Pause create() exactly between its reconciliation_pending save and its
    // `unknown` ledger write.
    const gate = operations.setUpdateGate('unknown');
    const createPromise = service
      .create('u1', createDto(prepared.id, 'k1'))
      .then(
        () => null as BookingException | null,
        (error) => error as BookingException,
      );
    await gate.entered;

    const paused = repo.rows.find((r) => r.id === prepared.id);
    expect(paused.status).toBe('reconciliation_pending');
    expect(paused.idempotencyKey).toBe('k1');
    expect(operations.rows[0].status).toBe('pending');
    expect(provider.createCalls).toBe(1);

    // The operator resolves the ambiguous booking while the create path is
    // still suspended before its late write.
    const reconciled = await service.reconcile('admin-1', prepared.id, {
      outcome: 'confirmed',
      providerReference: 'PNR-RACE-WINNER',
      providerBookingId: 'ord-race',
    });
    expect(reconciled.status).toBe('confirmed');
    expect(operations.rows[0]).toMatchObject({
      status: 'confirmed',
      providerRef: 'ord-race',
    });

    const readsAtResume = operations.findOneCalls;
    gate.release();
    const createError = await createPromise;
    expect(createError).toBeInstanceOf(BookingException);
    expect((createError as BookingException).code).toBe('booking_outcome_unknown');

    // Exactly one late `unknown` write was attempted, it carried the
    // pending-only condition, and it matched zero rows. No fallback write.
    const unknownAttempts = operations.updateAttempts.filter(
      (attempt) => attempt.partial.status === 'unknown',
    );
    expect(unknownAttempts).toHaveLength(1);
    expect(unknownAttempts[0].criteria.status).toBeDefined();
    expect(unknownAttempts[0].affected).toBe(0);
    // One read-back for the lost compare-and-set and one operation lookup for
    // the stored unknown-outcome response.
    expect(operations.findOneCalls).toBe(readsAtResume + 2);

    // The reconciled evidence survives: ledger confirmed, booking confirmed,
    // retained key, and still exactly one provider submission.
    expect(operations.rows[0].status).toBe('confirmed');
    expect(operations.rows[0].providerRef).toBe('ord-race');
    const row = repo.rows.find((r) => r.id === prepared.id);
    expect(row.status).toBe('confirmed');
    expect(row.idempotencyKey).toBe('k1');
    expect(provider.createCalls).toBe(1);
  });

  it('not_found is refused while the attempt is still pending and a later unknown write cannot undo it', async () => {
    const provider = new StubProvider();
    provider.createMode = 'ambiguous';
    provider.createError = 'timeout before any response';
    const { repo, operations, service } = setup(provider);
    const prepared = await prepare(service);

    const gate = operations.setUpdateGate('unknown');
    const createPromise = service
      .create('u1', createDto(prepared.id, 'k1'))
      .then(
        () => null as BookingException | null,
        (error) => error as BookingException,
      );
    await gate.entered;

    // The ledger row is still `pending`: the provider call may be in flight,
    // so the state machine must not declare it not found or release the key.
    const refused = await rejection(() =>
      service.reconcile('admin-1', prepared.id, { outcome: 'not_found' }),
    );
    expect(refused.code).toBe('validation_failed');
    expect(
      operations.updateAttempts.filter((a) => a.partial.status === 'not_found'),
    ).toHaveLength(0);
    expect(repo.rows[0].status).toBe('reconciliation_pending');
    expect(repo.rows[0].idempotencyKey).toBe('k1');
    expect(operations.rows[0].status).toBe('pending');

    gate.release();
    await createPromise;
    expect(operations.rows[0].status).toBe('unknown');
    expect(repo.rows[0].status).toBe('reconciliation_pending');
    expect(repo.rows[0].idempotencyKey).toBe('k1');

    // Once the attempt has settled as unknown, the operator may record the
    // not-found evidence and only then release the key.
    const reconciled = await service.reconcile('admin-1', prepared.id, {
      outcome: 'not_found',
      note: 'provider confirms no booking for this attempt',
    });
    expect(reconciled.status).toBe('failed');
    expect(operations.rows[0].status).toBe('not_found');
    expect(repo.rows[0].status).toBe('failed');
    expect(repo.rows[0].idempotencyKey).toBeNull();

    // A stale create-path write arriving after not_found is still guarded by
    // the pending-only compare-and-set. It must not revive the operation.
    const updatesBefore = operations.updateAttempts.length;
    const readsBefore = operations.findOneCalls;
    const late = await (service as any).completeProviderOperation(
      operations.rows[0].id,
      'unknown',
      { outcome: 'ambiguous', stale: true },
      undefined,
      ['pending'],
    );
    expect(late).toEqual({ applied: false, currentStatus: 'not_found' });
    expect(operations.updateAttempts).toHaveLength(updatesBefore + 1);
    expect(operations.updateAttempts[updatesBefore].affected).toBe(0);
    expect(operations.findOneCalls).toBe(readsBefore + 1);
    expect(operations.rows[0].status).toBe('not_found');
    expect(provider.createCalls).toBe(1);
  });

  it('not_found cannot release the key when a confirmation wins the compare-and-set', async () => {
    const provider = new StubProvider();
    provider.createMode = 'ambiguous';
    provider.createError = 'response lost';
    const { repo, operations, service } = setup(provider);
    const prepared = await prepare(service);

    await rejection(() => service.create('u1', createDto(prepared.id, 'k1')));
    expect(operations.rows[0].status).toBe('unknown');

    // Pause the not_found evidence write, then let a confirmation complete.
    const gate = operations.setUpdateGate('not_found');
    const notFoundPromise = service
      .reconcile('admin-1', prepared.id, { outcome: 'not_found' })
      .then(
        () => null as BookingException | null,
        (error) => error as BookingException,
      );
    await gate.entered;

    await service.reconcile('admin-1', prepared.id, {
      outcome: 'confirmed',
      providerReference: 'PNR-WINS',
    });
    gate.release();

    const notFoundError = await notFoundPromise;
    expect(notFoundError).toBeInstanceOf(BookingException);
    expect((notFoundError as BookingException).code).toBe('validation_failed');
    expect(responseDetails(notFoundError as BookingException).operationStatus).toBe(
      'confirmed',
    );

    const lateAttempt = operations.updateAttempts.find(
      (a) => a.partial.status === 'not_found',
    );
    expect(lateAttempt).toBeDefined();
    expect(lateAttempt!.criteria.status).toBeDefined();
    expect(lateAttempt!.affected).toBe(0);
    // No unconditional fallback: exactly the one guarded not_found attempt.
    expect(
      operations.updateAttempts.filter((a) => a.partial.status === 'not_found'),
    ).toHaveLength(1);

    expect(operations.rows[0]).toMatchObject({
      status: 'confirmed',
      providerRef: 'PNR-WINS',
    });
    expect(repo.rows[0].status).toBe('confirmed');
    expect(repo.rows[0].idempotencyKey).toBe('k1');
    expect(provider.createCalls).toBe(1);
  });

  it('a ledger write failure cannot reopen the booking or release its key', async () => {
    const provider = new StubProvider();
    provider.createMode = 'ambiguous';
    provider.createError = 'response lost';
    const { repo, operations, service } = setup(provider);
    const prepared = await prepare(service);
    operations.failUpdateStatus = 'unknown';

    const error = await rejection(() =>
      service.create('u1', createDto(prepared.id, 'k1')),
    );
    expect(error.code).toBe('booking_outcome_unknown');
    expect(operations.rows[0].status).toBe('pending');
    expect(
      operations.updateAttempts.filter((a) => a.partial.status === 'unknown'),
    ).toHaveLength(1);
    expect(repo.rows[0].status).toBe('reconciliation_pending');
    expect(repo.rows[0].idempotencyKey).toBe('k1');
    expect(provider.createCalls).toBe(1);

    // The retry stays blocked; the failed ledger write never reopens the key.
    const retry = await rejection(() =>
      service.create('u1', createDto(prepared.id, 'k1')),
    );
    expect(retry.code).toBe('booking_outcome_unknown');
    expect(provider.createCalls).toBe(1);
  });

  it('not_found keeps the key when its evidence write fails', async () => {
    const provider = new StubProvider();
    provider.createMode = 'ambiguous';
    provider.createError = 'response lost';
    const { repo, operations, service } = setup(provider);
    const prepared = await prepare(service);

    await rejection(() => service.create('u1', createDto(prepared.id, 'k1')));
    expect(operations.rows[0].status).toBe('unknown');

    operations.failUpdateStatus = 'not_found';
    const error = await rejection(() =>
      service.reconcile('admin-1', prepared.id, { outcome: 'not_found' }),
    );
    expect(error.code).toBe('unknown_error');
    expect(repo.rows[0].status).toBe('reconciliation_pending');
    expect(repo.rows[0].idempotencyKey).toBe('k1');
    expect(operations.rows[0].status).toBe('unknown');

    const retry = await rejection(() =>
      service.create('u1', createDto(prepared.id, 'k1')),
    );
    expect(retry.code).toBe('booking_outcome_unknown');
    expect(provider.createCalls).toBe(1);

    // Once the evidence can be recorded, the same explicit reconciliation
    // completes and only then releases the key.
    operations.failUpdateStatus = undefined;
    const reconciled = await service.reconcile('admin-1', prepared.id, {
      outcome: 'not_found',
    });
    expect(reconciled.status).toBe('failed');
    expect(repo.rows[0].idempotencyKey).toBeNull();
    expect(provider.createCalls).toBe(1);
  });

  it('reconciliation is limited to reconciliation_pending bookings', async () => {
    const provider = new StubProvider();
    const { service } = setup(provider);
    const prepared = await prepare(service);

    const error = await rejection(() =>
      service.reconcile('admin-1', prepared.id, {
        outcome: 'confirmed',
        providerReference: 'PNR-1',
      }),
    );
    expect(error.code).toBe('validation_failed');
    expect(provider.createCalls).toBe(0);
  });
});

// ---------------------------------------------------------------------------
// Provider confirmation gate
// ---------------------------------------------------------------------------

describe('BookingsService — provider confirmation truth decides the booking', () => {
  it('keeps a created-but-unpaid provider record reconciliation-pending', async () => {
    const provider = new StubProvider();
    // Duffel-style hold: the order exists, but it is awaiting payment.
    provider.createdStatus = 'pending_payment';
    provider.createdConfirmationState = 'pending';
    const { repo, service } = setup(provider);
    const prepared = await prepare(service);

    const error = await rejection(() =>
      service.create('u1', createDto(prepared.id, 'k1')),
    );
    expect(error.code).toBe('booking_outcome_unknown');
    expect(responseDetails(error)).toMatchObject({
      status: 'reconciliation_pending',
      requiresReconciliation: true,
      retryable: false,
      operationStatus: 'unknown',
    });
    expect(repo.rows[0].status).toBe('reconciliation_pending');
    expect(repo.rows[0].idempotencyKey).toBe('k1');
    expect(
      repo.rows[0].providerMetadata.providerBookingAttempt,
    ).toMatchObject({
      outcome: 'unknown',
      providerReference: 'PNR-1',
      providerBookingId: 'ord-1',
      providerStatus: 'pending_payment',
      requiresReconciliation: true,
      retryable: false,
    });
  });

  it('treats an unconfirmed CREATED provider booking as pending, not confirmed', async () => {
    const provider = new StubProvider();
    provider.createdStatus = 'CREATED';
    const { repo, service } = setup(provider);
    const prepared = await prepare(service);

    const error = await rejection(() =>
      service.create('u1', createDto(prepared.id, 'k1')),
    );
    expect(error.code).toBe('booking_outcome_unknown');
    expect(repo.rows[0].status).toBe('reconciliation_pending');
    expect(repo.rows[0].bookingReference).toBeUndefined();
  });

  it('reconciles instead of confirming when the provider amount differs', async () => {
    const provider = new StubProvider();
    provider.createdStatus = 'CONFIRMED';
    provider.createdAmount = provider.price + 25;
    const { repo, service } = setup(provider);
    const prepared = await prepare(service);

    const error = await rejection(() =>
      service.create('u1', createDto(prepared.id, 'k1')),
    );
    expect(error.code).toBe('booking_outcome_unknown');
    expect(repo.rows[0].status).toBe('reconciliation_pending');
    expect(repo.rows[0].bookingReference).toBeUndefined();
    expect(
      repo.rows[0].providerMetadata.providerBookingAttempt.error,
    ).toMatch(/amount/i);
  });

  it('reconciles instead of confirming when the provider currency differs', async () => {
    const provider = new StubProvider();
    provider.createdStatus = 'CONFIRMED';
    provider.createdCurrency = 'EUR';
    const { repo, service } = setup(provider);
    const prepared = await prepare(service);

    const error = await rejection(() =>
      service.create('u1', createDto(prepared.id, 'k1')),
    );
    expect(error.code).toBe('booking_outcome_unknown');
    expect(repo.rows[0].status).toBe('reconciliation_pending');
    expect(
      repo.rows[0].providerMetadata.providerBookingAttempt.error,
    ).toMatch(/currency/i);
  });

  it('marks a provider-cancelled booking failed and releases the key', async () => {
    const provider = new StubProvider();
    provider.createdStatus = 'CANCELLED';
    provider.createdConfirmationState = 'failed';
    const { repo, service } = setup(provider);
    const prepared = await prepare(service);

    const error = await rejection(() =>
      service.create('u1', createDto(prepared.id, 'k1')),
    );
    expect(error.code).toBe('provider_error');
    expect(repo.rows[0].status).toBe('failed');
    expect(repo.rows[0].idempotencyKey).toBeNull();
  });

  it('passes the accepted amount, currency and price version to the provider', async () => {
    const provider = new StubProvider();
    const { repo, service } = setup(provider);
    const prepared = await prepare(service);

    await service.create('u1', createDto(prepared.id, 'k1'));

    expect(provider.lastCreateInput).toMatchObject({
      bookingId: prepared.id,
      amount: prepared.authoritativePrice,
      currency: prepared.currency,
      priceVersion: repo.rows[0].priceVersion,
    });
    expect(provider.lastCreateInput?.amountText).toBeUndefined();
  });
});

// ---------------------------------------------------------------------------
// Classification boundary (used by the real adapters)
// ---------------------------------------------------------------------------

describe('provider booking failure classification', () => {
  it('only well-formed 4xx rejections are definitive', () => {
    expect(failureKindFromHttpStatus(400)).toBe('definitive');
    expect(failureKindFromHttpStatus(401)).toBe('definitive');
    expect(failureKindFromHttpStatus(404)).toBe('definitive');
    expect(failureKindFromHttpStatus(422)).toBe('definitive');
    for (const status of [408, 409, 425, 429]) {
      expect(failureKindFromHttpStatus(status)).toBe('ambiguous');
    }
    expect(failureKindFromHttpStatus(500)).toBe('ambiguous');
    expect(failureKindFromHttpStatus(502)).toBe('ambiguous');
    expect(failureKindFromHttpStatus(undefined)).toBe('ambiguous');
    expect(failureKindFromHttpStatus(0)).toBe('ambiguous');
  });

  it('treats Nuitee duplicate codes as ambiguous even on a 4xx status', () => {
    // 4005 = duplicate clientReference (hotel booking already exists).
    expect(
      failureKindFromProviderMessage(
        'Nuitee /rates/book failed (400) [4005]: Duplicate clientReference',
      ),
    ).toBe('ambiguous');
    // 45035 = concurrent duplicate of the same prebookId (flights).
    expect(
      failureKindFromProviderMessage(
        'Nuitee /flights/bookings failed (409) [45035]: booking in progress',
      ),
    ).toBe('ambiguous');
    // The same status without a duplicate code remains a rejection.
    expect(
      failureKindFromProviderMessage(
        'Nuitee /rates/book failed (400): invalid guest',
      ),
    ).toBe('definitive');
    // A 5xx stays ambiguous regardless of code.
    expect(
      failureKindFromProviderMessage(
        'Nuitee /rates/book failed (502) [4005]: upstream',
      ),
    ).toBe('ambiguous');
  });

  it('parses Nuitee statuses but defaults to ambiguous on timeouts', () => {
    expect(
      classifyBookingTransportFailure({
        error: 'Nuitee book failed: Nuitee /rates/book failed (422): invalid guest',
      }),
    ).toBe('definitive');
    expect(
      classifyBookingTransportFailure({
        error: 'Nuitee book failed: Nuitee /rates/book failed (502): upstream',
      }),
    ).toBe('ambiguous');
    expect(
      classifyBookingTransportFailure({
        error: 'Nuitee book failed: The operation was aborted due to timeout',
      }),
    ).toBe('ambiguous');
    expect(
      classifyBookingTransportFailure({ error: 'NUITEE_API_KEY missing' }),
    ).toBe('definitive');
    expect(classifyBookingTransportFailure({ error: 'unknown' })).toBe(
      'ambiguous',
    );
  });
});
