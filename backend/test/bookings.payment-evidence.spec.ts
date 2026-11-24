import { BookingsService } from '../src/modules/bookings/bookings.service';
import { BookingProviderRegistry } from '../src/modules/bookings/booking-provider.registry';
import {
  BookingProvider,
  BookingRevalidation,
  CreatedBooking,
  CreateBookingInput,
} from '../src/common/providers/booking-provider.interface';
import { ProviderResult } from '../src/common/providers/provider.result';
import { PrepareBookingDto } from '../src/common/dto/booking.dto';

/**
 * Phase 3C.1 — booking confirmation requires server-verified payment evidence.
 *
 * A client can declare anything. These tests prove the server only confirms a
 * booking when a durable payment attempt:
 *  - belongs to this booking and this user;
 *  - reached `succeeded` through a server-observed transition (`verifiedAt`);
 *  - matches the exact amount, currency and accepted price version; and
 *  - is not a mock gateway attempt in production.
 *
 * The last check runs again immediately before the booking is persisted as
 * confirmed, so a refund or verification loss during the provider call cannot
 * slip through.
 */

class FakeBookingRepo {
  rows: any[] = [];
  private seq = 0;

  create(obj: any): any {
    return {
      ...obj,
      id: obj.id ?? `b${++this.seq}`,
      createdAt: new Date(),
      updatedAt: new Date(),
    };
  }

  async save(booking: any): Promise<any> {
    const idx = this.rows.findIndex((r) => r.id === booking.id);
    if (idx >= 0) this.rows[idx] = booking;
    else this.rows.push(booking);
    booking.updatedAt = new Date();
    return booking;
  }

  async findOne({ where }: any): Promise<any | null> {
    return (
      this.rows.find(
        (r) =>
          (where.id === undefined || r.id === where.id) &&
          (where.userId === undefined || r.userId === where.userId),
      ) ?? null
    );
  }

  async update(criteria: any, partial: any): Promise<{ affected: number }> {
    const allowed =
      criteria.status && typeof criteria.status === 'object'
        ? (criteria.status as any).value
        : criteria.status;
    const statuses = Array.isArray(allowed)
      ? allowed
      : allowed !== undefined
        ? [allowed]
        : null;

    const matches = this.rows.filter((r) => {
      if (criteria.id !== undefined && r.id !== criteria.id) return false;
      if (criteria.userId !== undefined && r.userId !== criteria.userId) {
        return false;
      }
      if (statuses && !statuses.includes(r.status)) return false;
      return true;
    });
    for (const row of matches) Object.assign(row, partial);
    return { affected: matches.length };
  }
}

class FakeAttemptRepo {
  rows: any[] = [];

  async findOne({ where }: any): Promise<any | null> {
    return (
      this.rows.find((row) =>
        Object.entries(where).every(([key, value]) => row[key] === value),
      ) ?? null
    );
  }

  async find({ where }: any): Promise<any[]> {
    return this.rows.filter((row) =>
      Object.entries(where).every(([key, value]) => row[key] === value),
    );
  }
}

class StubProvider implements BookingProvider {
  readonly providerId = 'stub-flight';
  readonly providerName = 'Stub Provider';
  readonly bookingCapability = { book: true, cancel: false, revalidate: true };

  price = 100;
  currency = 'USD';
  createCalls = 0;
  createFails = false;
  onCreate?: () => void;

  async revalidateBooking(): Promise<ProviderResult<BookingRevalidation>> {
    return {
      success: true,
      providerId: this.providerId,
      providerName: this.providerName,
      data: {
        price: this.price,
        currency: this.currency,
        available: true,
        expiresAt: new Date(Date.now() + 60000).toISOString(),
        handoff: { rateId: 'r1' },
      },
      timestamp: new Date(),
    };
  }

  async createBooking(
    _input: CreateBookingInput,
  ): Promise<ProviderResult<CreatedBooking>> {
    this.createCalls++;
    this.onCreate?.();
    if (this.createFails) {
      return {
        success: false,
        providerId: this.providerId,
        providerName: this.providerName,
        error: 'definitive rejection',
        failureKind: 'definitive',
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

const prepareDto: PrepareBookingDto = {
  offerId: 'offer-1',
  providerId: 'stub-flight',
  searchId: 's1',
  offerType: 'flight',
};

function setup(options: { withAttempts?: boolean } = {}) {
  const repo = new FakeBookingRepo();
  const attempts = new FakeAttemptRepo();
  const provider = new StubProvider();
  const registry = new BookingProviderRegistry();
  registry.register(provider);

  const service =
    options.withAttempts === false
      ? new BookingsService(repo as any, registry)
      : new BookingsService(
          repo as any,
          registry,
          undefined,
          undefined,
          attempts as any,
        );

  return { repo, attempts, provider, registry, service };
}

async function prepareBooking(ctx: ReturnType<typeof setup>) {
  const prepared = await ctx.service.prepare('u1', prepareDto);
  const row = ctx.repo.rows[0];
  return { prepared, row };
}

function verifiedAttempt(row: any, overrides: Record<string, any> = {}) {
  return {
    id: 'att-1',
    bookingId: row.id,
    userId: row.userId,
    status: 'succeeded',
    verifiedAt: new Date(),
    priceVersion: row.priceVersion,
    amount: row.authoritativePrice,
    currency: row.currency,
    gatewayId: 'mock-egypt-gateway',
    ...overrides,
  };
}

async function inProduction<T>(fn: () => Promise<T> | T): Promise<T> {
  const previousNodeEnv = process.env.NODE_ENV;
  const previousWorker = process.env.JEST_WORKER_ID;
  process.env.NODE_ENV = 'production';
  delete process.env.JEST_WORKER_ID;
  try {
    return await fn();
  } finally {
    if (previousNodeEnv === undefined) delete process.env.NODE_ENV;
    else process.env.NODE_ENV = previousNodeEnv;
    if (previousWorker === undefined) delete process.env.JEST_WORKER_ID;
    else process.env.JEST_WORKER_ID = previousWorker;
  }
}

describe('BookingsService — payment evidence containment', () => {
  it('refuses to confirm a booking with no verified payment', async () => {
    const ctx = setup();
    const { prepared } = await prepareBooking(ctx);

    await expect(
      ctx.service.create('u1', {
        bookingId: prepared.id,
        idempotencyKey: 'k1',
      }),
    ).rejects.toMatchObject({ code: 'payment_required' });

    expect(ctx.provider.createCalls).toBe(0);
    expect(ctx.repo.rows[0].status).toBe('prepared');
  });

  it('refuses a client-declared success that the server never verified', async () => {
    const ctx = setup();
    const { prepared, row } = await prepareBooking(ctx);
    ctx.attempts.rows.push(verifiedAttempt(row, { verifiedAt: null }));

    await expect(
      ctx.service.create('u1', {
        bookingId: prepared.id,
        idempotencyKey: 'k1',
        paymentAttemptId: 'att-1',
      }),
    ).rejects.toMatchObject({
      code: 'payment_not_verified',
      message: expect.stringMatching(/server-verified/i),
    });

    expect(ctx.provider.createCalls).toBe(0);
  });

  it('refuses a payment made for an older accepted price version', async () => {
    const ctx = setup();
    const { prepared, row } = await prepareBooking(ctx);
    ctx.attempts.rows.push(
      verifiedAttempt(row, {
        priceVersion: 'price-v1-old',
        amount: 90,
      }),
    );

    await expect(
      ctx.service.create('u1', {
        bookingId: prepared.id,
        idempotencyKey: 'k1',
        paymentAttemptId: 'att-1',
      }),
    ).rejects.toMatchObject({
      code: 'payment_not_verified',
      message: expect.stringMatching(/different price version/i),
    });

    expect(ctx.provider.createCalls).toBe(0);
  });

  it('refuses a payment whose amount does not match the booking', async () => {
    const ctx = setup();
    const { prepared, row } = await prepareBooking(ctx);
    ctx.attempts.rows.push(verifiedAttempt(row, { amount: 90 }));

    await expect(
      ctx.service.create('u1', {
        bookingId: prepared.id,
        idempotencyKey: 'k1',
        paymentAttemptId: 'att-1',
      }),
    ).rejects.toMatchObject({
      code: 'payment_not_verified',
      message: expect.stringMatching(/amount or currency/i),
    });

    expect(ctx.provider.createCalls).toBe(0);
  });

  it('refuses a payment that belongs to another user', async () => {
    const ctx = setup();
    const { prepared, row } = await prepareBooking(ctx);
    ctx.attempts.rows.push(verifiedAttempt(row, { userId: 'u2' }));

    await expect(
      ctx.service.create('u1', {
        bookingId: prepared.id,
        idempotencyKey: 'k1',
        paymentAttemptId: 'att-1',
      }),
    ).rejects.toMatchObject({
      code: 'payment_not_verified',
      message: expect.stringMatching(/does not belong/i),
    });

    expect(ctx.provider.createCalls).toBe(0);
  });

  it('auto-selects exactly one matching verified payment and reserves it atomically', async () => {
    const ctx = setup();
    const { prepared, row } = await prepareBooking(ctx);
    ctx.attempts.rows.push(verifiedAttempt(row));

    const confirmed = await ctx.service.create('u1', {
      bookingId: prepared.id,
      idempotencyKey: 'k1',
    });

    expect(confirmed.status).toBe('confirmed');
    expect(ctx.provider.createCalls).toBe(1);
    expect(ctx.repo.rows[0]).toMatchObject({
      paymentAttemptId: 'att-1',
      paymentStatus: 'verified',
    });
    expect(ctx.repo.rows[0].consumedAt).toBeInstanceOf(Date);
  });

  it('refuses an ambiguous auto-selection instead of guessing', async () => {
    const ctx = setup();
    const { prepared, row } = await prepareBooking(ctx);
    ctx.attempts.rows.push(
      verifiedAttempt(row, { id: 'att-1' }),
      verifiedAttempt(row, { id: 'att-2' }),
    );

    await expect(
      ctx.service.create('u1', {
        bookingId: prepared.id,
        idempotencyKey: 'k1',
      }),
    ).rejects.toMatchObject({
      code: 'payment_not_verified',
      message: expect.stringMatching(/More than one verified payment/i),
    });

    expect(ctx.provider.createCalls).toBe(0);
  });

  it('refuses to replace a payment already attached to the booking', async () => {
    const ctx = setup();
    const { prepared, row } = await prepareBooking(ctx);
    row.paymentAttemptId = 'att-old';
    ctx.attempts.rows.push(verifiedAttempt(row, { id: 'att-new' }));

    await expect(
      ctx.service.create('u1', {
        bookingId: prepared.id,
        idempotencyKey: 'k1',
        paymentAttemptId: 'att-new',
      }),
    ).rejects.toMatchObject({
      code: 'payment_not_verified',
      message: expect.stringMatching(/different payment is already attached/i),
    });

    expect(ctx.provider.createCalls).toBe(0);
  });

  it('re-verifies the payment after the provider call and refuses to confirm if it is gone', async () => {
    const ctx = setup();
    const { prepared, row } = await prepareBooking(ctx);
    const attempt = verifiedAttempt(row);
    ctx.attempts.rows.push(attempt);

    // Simulate a refund/verification loss that happens while the provider
    // call is in flight.
    ctx.provider.onCreate = () => {
      attempt.verifiedAt = null;
    };

    await expect(
      ctx.service.create('u1', {
        bookingId: prepared.id,
        idempotencyKey: 'k1',
        paymentAttemptId: 'att-1',
      }),
    ).rejects.toMatchObject({ code: 'payment_not_verified' });

    expect(ctx.provider.createCalls).toBe(1);
    expect(ctx.repo.rows[0].status).toBe('confirming');
  });

  it('releases the payment link on a definitive provider rejection so a retry is possible', async () => {
    const ctx = setup();
    const { prepared, row } = await prepareBooking(ctx);
    ctx.attempts.rows.push(verifiedAttempt(row));

    ctx.provider.createFails = true;
    await expect(
      ctx.service.create('u1', {
        bookingId: prepared.id,
        idempotencyKey: 'k1',
        paymentAttemptId: 'att-1',
      }),
    ).rejects.toMatchObject({ code: 'provider_error' });

    expect(ctx.repo.rows[0].status).toBe('failed');
    expect(ctx.repo.rows[0].paymentAttemptId).toBeNull();
    expect(ctx.repo.rows[0].paymentStatus).toBe('unverified');

    // The verified attempt is still valid evidence; a retry can consume it.
    ctx.provider.createFails = false;
    const retried = await ctx.service.create('u1', {
      bookingId: prepared.id,
      idempotencyKey: 'k2',
      paymentAttemptId: 'att-1',
    });
    expect(retried.status).toBe('confirmed');
    expect(ctx.repo.rows[0].paymentAttemptId).toBe('att-1');
  });

  it('releases the payment link when the price moves before the provider call', async () => {
    const ctx = setup();
    const { prepared, row } = await prepareBooking(ctx);
    ctx.attempts.rows.push(verifiedAttempt(row));

    ctx.provider.price = 130;
    await expect(
      ctx.service.create('u1', {
        bookingId: prepared.id,
        idempotencyKey: 'k1',
        paymentAttemptId: 'att-1',
      }),
    ).rejects.toMatchObject({ code: 'price_changed' });

    expect(ctx.provider.createCalls).toBe(0);
    expect(ctx.repo.rows[0]).toMatchObject({
      status: 'revalidated',
      priceVersion: null,
      paymentAttemptId: null,
      paymentStatus: 'unverified',
    });
  });

  it('fails closed in production when no payment-attempt repository is wired', async () => {
    const ctx = setup({ withAttempts: false });
    const { prepared } = await prepareBooking(ctx);

    await inProduction(async () => {
      await expect(
        ctx.service.create('u1', {
          bookingId: prepared.id,
          idempotencyKey: 'k1',
        }),
      ).rejects.toMatchObject({ code: 'payment_required' });
    });

    expect(ctx.provider.createCalls).toBe(0);
  });

  it('refuses a mock-gateway attempt in production', async () => {
    const ctx = setup();
    const { prepared, row } = await prepareBooking(ctx);
    ctx.attempts.rows.push(verifiedAttempt(row));

    await inProduction(async () => {
      await expect(
        ctx.service.create('u1', {
          bookingId: prepared.id,
          idempotencyKey: 'k1',
          paymentAttemptId: 'att-1',
        }),
      ).rejects.toMatchObject({
        code: 'payment_not_verified',
        message: expect.stringMatching(/mock payment gateway/i),
      });
    });

    expect(ctx.provider.createCalls).toBe(0);
  });
});
