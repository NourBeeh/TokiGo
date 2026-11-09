import { In, QueryFailedError } from 'typeorm';

import { BookingsService } from '../src/modules/bookings/bookings.service';
import { BookingProviderRegistry } from '../src/modules/bookings/booking-provider.registry';
import { BookingException } from '../src/modules/bookings/booking.exception';
import {
  BookingProvider,
  BookingRevalidation,
  CreatedBooking,
  CreateBookingInput,
} from '../src/common/providers/booking-provider.interface';
import { ProviderResult } from '../src/common/providers/provider.result';
import { PrepareBookingDto } from '../src/common/dto/booking.dto';
import { NuiteeBookingProvider } from '../src/modules/bookings/adapters/nuitee-booking.provider';

/**
 * Phase 2P-Fix — booking submission safety.
 *
 * Proves the non-negotiables around the COMMIT boundary:
 *  - concurrent confirmations of one booking produce exactly one provider
 *    submission (no double booking);
 *  - a completed confirmation is replayed, never re-submitted;
 *  - provider rejection / timeout never yields a confirmed booking and never
 *    triggers an automatic second submission;
 *  - a failed or invalid prebook, an unavailable rate and a moved price all
 *    block the provider booking call.
 *
 * Every test uses deterministic fakes (promise gates), never arbitrary sleeps.
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

class FakeRepo {
  rows: any[] = [];
  private seq = 0;

  /** Barrier that releases once [n] findOne calls have entered. */
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
      this.rows.find(
        (r) => r.id === where.id && r.userId === where.userId,
      ) ?? null
    );
  }

  /**
   * Models Postgres UPDATE semantics: the statement is evaluated against the
   * CURRENT row state, so a concurrent writer that already moved the status on
   * is no longer matched (`affected: 0`). This is what makes the reservation
   * fail closed under a race.
   */
  async update(
    criteria: any,
    partial: any,
  ): Promise<{ affected: number }> {
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
      if (criteria.userId !== undefined && r.userId !== criteria.userId) {
        return false;
      }
      if (allowed && !allowed.includes(r.status)) return false;
      return true;
    });
    for (const row of matches) Object.assign(row, partial);
    return { affected: matches.length };
  }
}

class StubProvider implements BookingProvider {
  readonly providerId = 'stub-hotel';
  readonly providerName = 'Stub Hotel';
  readonly bookingCapability = { book: true, cancel: false, revalidate: true };

  price = 100;
  currency = 'USD';
  available = true;
  handoff: Record<string, any> = {
    rateId: 'r1',
    prebookId: 'pb-1',
    transactionId: 'tx-1',
  };

  revalidateCalls = 0;
  createCalls = 0;
  lastCreateInput?: CreateBookingInput;

  revalidateFails = false;
  createFails = false;
  createNeverResolves = false;
  revalidateGate?: Promise<void>;
  createGate?: Promise<void>;

  async revalidateBooking(): Promise<ProviderResult<BookingRevalidation>> {
    this.revalidateCalls += 1;
    if (this.revalidateGate) await this.revalidateGate;
    if (this.revalidateFails) {
      return {
        success: false,
        providerId: this.providerId,
        providerName: this.providerName,
        error: 'prebook request failed',
        timestamp: new Date(),
      };
    }
    return {
      success: true,
      providerId: this.providerId,
      providerName: this.providerName,
      data: {
        price: this.price,
        currency: this.currency,
        available: this.available,
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
    if (this.createNeverResolves) {
      return new Promise<ProviderResult<CreatedBooking>>(() => {});
    }
    if (this.createFails) {
      return {
        success: false,
        providerId: this.providerId,
        providerName: this.providerName,
        error: 'provider rejected the booking',
        timestamp: new Date(),
      };
    }
    return {
      success: true,
      providerId: this.providerId,
      providerName: this.providerName,
      data: {
        reference: 'REF-1',
        providerBookingId: 'pb-1',
        status: 'CONFIRMED',
        amount: this.price,
        currency: this.currency,
      },
      timestamp: new Date(),
    };
  }
}

function setup(provider: BookingProvider = new StubProvider()) {
  const repo = new FakeRepo();
  const registry = new BookingProviderRegistry();
  registry.register(provider);
  const service = new BookingsService(repo as any, registry);
  return { repo, registry, service, provider };
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
  travelers: [{ firstName: 'A', lastName: 'B' }],
});

/**
 * Deterministically drains the microtask queue. The concurrency in these tests
 * is synchronised with promise gates, so no time-based delay is involved —
 * this only lets the already-scheduled continuations run.
 */
async function drainMicrotasks(ticks = 300): Promise<void> {
  for (let i = 0; i < ticks; i += 1) {
    await Promise.resolve();
  }
}

function trackSettlement(
  promise: Promise<unknown>,
  into: { outcome: string | null; code?: string },
): void {
  promise.then(
    () => {
      into.outcome = 'fulfilled';
    },
    (error) => {
      into.outcome = 'rejected';
      into.code = (error as BookingException)?.code;
    },
  );
}

// ---------------------------------------------------------------------------
// A. Duplicate submission
// ---------------------------------------------------------------------------

describe('BookingsService — Phase 2P submission safety', () => {
  it('A1 two concurrent create calls while the first provider booking is pending submit exactly one provider booking', async () => {
    const provider = new StubProvider();
    const { repo, service } = setup(provider);
    const prepared = await service.prepare('u1', prepareDto);

    // Hold BOTH create calls at the same point — after they read the row but
    // before either has reserved it — so the race is deterministic.
    repo.setFindOneBarrier(2);
    const createGate = deferred<void>();
    provider.createGate = createGate.promise;

    const first = service.create('u1', createDto(prepared.id, 'k1'));
    const secondState: { outcome: string | null; code?: string } = {
      outcome: null,
    };
    trackSettlement(service.create('u1', createDto(prepared.id, 'k1')), secondState);

    // Both passed the read barrier; let the reservation race play out.
    // revalidateCalls baseline is 1 (the prepare call); only the winner may
    // reach the provider revalidation.
    await drainMicrotasks();

    // Exactly one of the two may reach the provider at all.
    expect(provider.revalidateCalls).toBe(2);
    expect(provider.createCalls).toBe(1);

    createGate.resolve();
    const firstResult = await first;
    await expect(secondState.outcome).toBe('rejected');
    expect(secondState.code).toBe('duplicate_request');

    expect(firstResult.status).toBe('confirmed');
    expect(provider.createCalls).toBe(1);
  });

  it('A2 a third concurrent call is rejected as duplicate_request and never reaches the provider', async () => {
    const provider = new StubProvider();
    const { repo, service } = setup(provider);
    const prepared = await service.prepare('u1', prepareDto);

    repo.setFindOneBarrier(3);
    const createGate = deferred<void>();
    provider.createGate = createGate.promise;

    const calls: Promise<unknown>[] = [];
    const states: { outcome: string | null; code?: string }[] = [];
    for (let i = 0; i < 3; i += 1) {
      const state: { outcome: string | null; code?: string } = { outcome: null };
      const call = service.create('u1', createDto(prepared.id, 'k1'));
      trackSettlement(call, state);
      calls.push(call);
      states.push(state);
    }

    await drainMicrotasks();

    // Baseline is 1 (prepare); only the single winner may reach the provider.
    expect(provider.revalidateCalls).toBe(2);
    expect(provider.createCalls).toBe(1);
    expect(states.filter((s) => s.outcome === 'rejected')).toHaveLength(2);
    expect(
      states
        .filter((s) => s.outcome === 'rejected')
        .every((s) => s.code === 'duplicate_request'),
    ).toBe(true);

    createGate.resolve();
    const settled = await Promise.allSettled(calls);
    expect(settled.filter((s) => s.status === 'fulfilled')).toHaveLength(1);
    expect(provider.createCalls).toBe(1);
  });

  it('A3 a replay of a confirmed booking returns the stored record without a second provider submission', async () => {
    const provider = new StubProvider();
    const { service } = setup(provider);
    const prepared = await service.prepare('u1', prepareDto);

    const first = await service.create('u1', createDto(prepared.id, 'k1'));
    const replay = await service.create('u1', createDto(prepared.id, 'k1'));

    expect(first.status).toBe('confirmed');
    expect(replay.status).toBe('confirmed');
    expect(replay.bookingReference).toBe('REF-1');
    expect(provider.createCalls).toBe(1);
  });

  it('A4 a new attempt with a fresh key after a failed attempt can submit again', async () => {
    const provider = new StubProvider();
    const { service } = setup(provider);
    const prepared = await service.prepare('u1', prepareDto);

    provider.createFails = true;
    await expect(
      service.create('u1', createDto(prepared.id, 'k1')),
    ).rejects.toMatchObject({ code: 'provider_error' });

    provider.createFails = false;
    const retried = await service.create('u1', createDto(prepared.id, 'k2'));

    expect(retried.status).toBe('confirmed');
    expect(provider.createCalls).toBe(2);
  });
});

// ---------------------------------------------------------------------------
// B. Failure and timeout
// ---------------------------------------------------------------------------

describe('BookingsService — Phase 2P failure and timeout', () => {
  it('B5 a clear provider rejection marks the booking failed and never returns a confirmed state', async () => {
    const provider = new StubProvider();
    const { repo, service } = setup(provider);
    const prepared = await service.prepare('u1', prepareDto);

    provider.createFails = true;
    await expect(
      service.create('u1', createDto(prepared.id, 'k1')),
    ).rejects.toMatchObject({ code: 'provider_error' });

    const row = repo.rows.find((r) => r.id === prepared.id);
    expect(row.status).toBe('failed');
    expect(row.idempotencyKey).toBeNull();
    expect(provider.createCalls).toBe(1);
  });

  it('B6 a provider that never answers never produces a confirmed booking', async () => {
    const provider = new StubProvider();
    const { repo, service } = setup(provider);
    const prepared = await service.prepare('u1', prepareDto);

    provider.createNeverResolves = true;
    const outcome = await Promise.race([
      service.create('u1', createDto(prepared.id, 'k1')).then(
        () => 'resolved',
        () => 'rejected',
      ),
      new Promise((resolve) => setTimeout(() => resolve('pending'), 20)),
    ]);

    expect(outcome).toBe('pending');
    const row = repo.rows.find((r) => r.id === prepared.id);
    // Ambiguous: the reservation is held open (never 'confirmed', never
    // 'failed'). This is the documented limitation — the client must not be
    // told the booking succeeded, and no automatic retry may fire.
    expect(row.status).toBe('confirming');
    expect(provider.createCalls).toBe(1);
  });

  it('B7 an ambiguous timeout does not trigger an automatic second booking submission', async () => {
    const provider = new StubProvider();
    const { service } = setup(provider);
    const prepared = await service.prepare('u1', prepareDto);

    provider.createNeverResolves = true;
    const pending = service.create('u1', createDto(prepared.id, 'k1'));

    await new Promise((resolve) => setTimeout(resolve, 20));
    expect(provider.createCalls).toBe(1);

    await new Promise((resolve) => setTimeout(resolve, 20));
    expect(provider.createCalls).toBe(1);

    // The dangling call is intentionally never awaited; it must not have
    // caused a second submission.
    void pending;
  });
});

// ---------------------------------------------------------------------------
// C. Prebook and price validation
// ---------------------------------------------------------------------------

describe('BookingsService — Phase 2P prebook and price validation', () => {
  it('C8 a failed prebook persists no booking and creates nothing', async () => {
    const provider = new StubProvider();
    provider.revalidateFails = true;
    const { repo, service } = setup(provider);

    await expect(service.prepare('u1', prepareDto)).rejects.toMatchObject({
      code: 'provider_unavailable',
    });

    expect(repo.rows).toHaveLength(0);
    expect(provider.createCalls).toBe(0);
  });

  it('C9 an unavailable rate is rejected with no_availability and persists no booking', async () => {
    const provider = new StubProvider();
    provider.available = false;
    const { repo, service } = setup(provider);

    await expect(service.prepare('u1', prepareDto)).rejects.toMatchObject({
      code: 'no_availability',
    });
    expect(repo.rows).toHaveLength(0);

    // Once prepared, a rate that became unavailable blocks revalidation too.
    const available = new StubProvider();
    const second = setup(available);
    const prepared = await second.service.prepare('u1', prepareDto);
    available.available = false;
    await expect(
      second.service.revalidate('u1', prepared.id),
    ).rejects.toMatchObject({ code: 'no_availability' });

    // And a live-unavailable rate blocks the commit itself.
    const commitProvider = new StubProvider();
    const third = setup(commitProvider);
    const preparedAgain = await third.service.prepare('u1', prepareDto);
    commitProvider.available = false;
    await expect(
      third.service.create('u1', createDto(preparedAgain.id, 'k1')),
    ).rejects.toMatchObject({ code: 'no_availability' });
    expect(
      third.repo.rows.find((r) => r.id === preparedAgain.id).status,
    ).toBe('failed');
    expect(commitProvider.createCalls).toBe(0);
  });

  it('C10 a changed price is not silently accepted as the original price', async () => {
    const provider = new StubProvider();
    const { repo, service } = setup(provider);
    const prepared = await service.prepare('u1', prepareDto);

    provider.price = 175;
    await expect(
      service.create('u1', createDto(prepared.id, 'k1')),
    ).rejects.toMatchObject({ code: 'price_changed' });

    const row = repo.rows.find((r) => r.id === prepared.id);
    expect(provider.createCalls).toBe(0);
    expect(row.status).toBe('revalidated');
    expect(row.authoritativePrice).toBe(175);
    expect(row.previousPrice).toBe(100);
    // The key is released so the client can explicitly re-accept and retry.
    expect(row.idempotencyKey).toBeNull();
  });

  it('C11 the provider receives the prepared offerId and the persisted prebook handoff ids', async () => {
    const provider = new StubProvider();
    const { service } = setup(provider);
    const prepared = await service.prepare('u1', prepareDto);

    await service.create('u1', createDto(prepared.id, 'k1'));

    expect(provider.lastCreateInput).toMatchObject({
      offerId: 'offer-1',
      offerSnapshot: {
        offerId: 'offer-1',
        rateId: 'r1',
        prebookId: 'pb-1',
        transactionId: 'tx-1',
      },
      travelers: [{ firstName: 'A', lastName: 'B' }],
    });
  });
});

// ---------------------------------------------------------------------------
// Adapter — invalid prebook handoff
// ---------------------------------------------------------------------------

describe('NuiteeBookingProvider — prebook handoff safety', () => {
  it('C8b never calls bookHotel when the prebook handoff is missing', async () => {
    const bookHotel = jest.fn();
    const nuitee = { bookHotel, providerName: 'Nuitee Connect' };
    const provider = new NuiteeBookingProvider(nuitee as any);

    const result = await provider.createBooking({
      offerId: 'rate-1',
      offerSnapshot: { rateId: 'rate-1' },
    });

    expect(result.success).toBe(false);
    expect(bookHotel).not.toHaveBeenCalled();
  });

  it('C11b books with the persisted prebookId and transactionId', async () => {
    const bookHotel = jest.fn().mockResolvedValue({
      success: true,
      providerId: 'nuitee',
      providerName: 'Nuitee Connect',
      data: {
        bookingId: 'bk-9',
        reference: 'HTL-9',
        status: 'CONFIRMED',
        total: 120,
        currency: 'USD',
      },
      timestamp: new Date(),
    });
    const nuitee = { bookHotel, providerName: 'Nuitee Connect' };
    const provider = new NuiteeBookingProvider(nuitee as any);

    const result = await provider.createBooking({
      offerId: 'rate-1',
      offerSnapshot: {
        rateId: 'rate-1',
        prebookId: 'pb-9',
        transactionId: 'tx-9',
      },
      travelers: [{ firstName: 'A', lastName: 'B', adult: true }],
    });

    expect(result.success).toBe(true);
    expect(result.data.reference).toBe('HTL-9');
    expect(bookHotel).toHaveBeenCalledWith(
      expect.objectContaining({
        prebookId: 'pb-9',
        transactionId: 'tx-9',
        guestNames: ['A B'],
        adults: [true],
      }),
    );
  });
});
