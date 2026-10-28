import { QueryFailedError } from 'typeorm';
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

/**
 * Phase 4A — Booking foundation contracts.
 *
 * Proves the non-negotiables: provider-authoritative pricing (never the
 * client), capability gating, revalidate-before-commit, idempotent create
 * (no double booking), normalised error codes and JWT-scoped ownership.
 */

class FakeRepo {
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
    if (booking.idempotencyKey != null) {
      const clash = this.rows.find(
        (r) =>
          r.id !== booking.id &&
          r.userId === booking.userId &&
          r.idempotencyKey === booking.idempotencyKey,
      );
      if (clash) {
        throw new QueryFailedError('INSERT', [], {
          code: '23505',
        } as any);
      }
    }
    const idx = this.rows.findIndex((r) => r.id === booking.id);
    if (idx >= 0) this.rows[idx] = booking;
    else this.rows.push(booking);
    booking.updatedAt = new Date();
    return booking;
  }

  async findOne({ where }: any): Promise<any | null> {
    return (
      this.rows.find(
        (r) => r.id === where.id && r.userId === where.userId,
      ) ?? null
    );
  }
}

class StubProvider implements BookingProvider {
  readonly providerId = 'stub-flight';
  readonly providerName = 'Stub Provider';
  readonly bookingCapability = { book: true, cancel: false, revalidate: true };

  price = 100;
  currency = 'USD';
  available = true;
  handoff: Record<string, any> = { rateId: 'r1', prebookId: 'pb', transactionId: 'tx' };
  revalidateCalls = 0;
  createCalls = 0;
  lastCreateInput?: CreateBookingInput;
  createFails = false;

  async revalidateBooking(): Promise<ProviderResult<BookingRevalidation>> {
    this.revalidateCalls++;
    return {
      success: true,
      providerId: this.providerId,
      providerName: this.providerName,
      data: {
        price: this.price,
        currency: this.currency,
        available: this.available,
        expiresAt: new Date(Date.now() + 60000).toISOString(),
        handoff: this.handoff,
      },
      timestamp: new Date(),
    };
  }

  async createBooking(
    input: CreateBookingInput,
  ): Promise<ProviderResult<CreatedBooking>> {
    this.createCalls++;
    this.lastCreateInput = input;
    if (this.createFails) {
      return {
        success: false,
        providerId: this.providerId,
        providerName: this.providerName,
        error: 'provider blew up',
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
  providerId: 'stub-flight',
  searchId: 's1',
  offerType: 'flight',
};

describe('BookingsService — 4A foundation', () => {
  it('prepare persists a provider-authoritative price and the handoff snapshot', async () => {
    const { service, repo } = setup();
    const res = await service.prepare('u1', prepareDto);
    expect(res.status).toBe('prepared');
    expect(res.authoritativePrice).toBe(100);
    expect(res.currency).toBe('USD');
    expect(repo.rows[0].offerSnapshot).toMatchObject({
      offerId: 'offer-1',
      prebookId: 'pb',
      transactionId: 'tx',
    });
    // The snapshot / provider metadata are never leaked to the wire shape.
    expect((res as any).offerSnapshot).toBeUndefined();
  });

  it('prepare rejects an unknown provider with a capability error', async () => {
    const { service } = setup();
    await expect(
      service.prepare('u1', { ...prepareDto, providerId: 'ghost' }),
    ).rejects.toMatchObject({ code: 'capability_unsupported' });
  });

  it('prepare surfaces an unavailable offer as no_availability', async () => {
    const stub = new StubProvider();
    stub.available = false;
    const { service } = setup(stub);
    await expect(service.prepare('u1', prepareDto)).rejects.toMatchObject({
      code: 'no_availability',
    });
  });

  it('prepare surfaces a provider failure as provider_unavailable', async () => {
    const failing: any = {
      providerId: 'stub-flight',
      providerName: 'Stub',
      bookingCapability: { book: true, cancel: false, revalidate: true },
      revalidateBooking: async () => ({
        success: false,
        providerId: 'stub-flight',
        providerName: 'Stub',
        error: 'boom',
        timestamp: new Date(),
      }),
    };
    const { service } = setup(failing);
    await expect(service.prepare('u1', prepareDto)).rejects.toMatchObject({
      code: 'provider_unavailable',
    });
  });

  it('revalidate persists the moved price with previousPrice and status', async () => {
    const provider = new StubProvider();
    const { service } = setup(provider);
    const prepared = await service.prepare('u1', prepareDto);

    provider.price = 130;
    const res = await service.revalidate('u1', prepared.id);

    expect(res.status).toBe('revalidated');
    expect(res.authoritativePrice).toBe(130);
    expect(res.previousPrice).toBe(100);
    expect(res.priceChanged).toBe(true);
  });

  it('create revalidates before commit and confirms with the provider reference', async () => {
    const provider = new StubProvider();
    const { service, repo } = setup(provider);
    const prepared = await service.prepare('u1', prepareDto);

    const confirmed = await service.create('u1', {
      bookingId: prepared.id,
      idempotencyKey: 'k1',
      travelers: [{ firstName: 'A', lastName: 'B' }],
    });

    expect(confirmed.status).toBe('confirmed');
    expect(confirmed.bookingReference).toBe('REF-1');
    expect(provider.createCalls).toBe(1);
    expect(repo.rows[0].providerMetadata).toMatchObject({
      providerBookingId: 'pb-1',
      providerStatus: 'CONFIRMED',
    });
  });

  it('create blocks a price move (price_changed) and frees the key', async () => {
    const provider = new StubProvider();
    const { service, repo } = setup(provider);
    const prepared = await service.prepare('u1', prepareDto);

    provider.price = 175;
    await expect(
      service.create('u1', { bookingId: prepared.id, idempotencyKey: 'k1' }),
    ).rejects.toMatchObject({ code: 'price_changed' });

    expect(provider.createCalls).toBe(0);
    expect(repo.rows[0].status).toBe('revalidated');
    expect(repo.rows[0].authoritativePrice).toBe(175);
    expect(repo.rows[0].idempotencyKey).toBeNull();
  });

  it('create is idempotent: a replay returns the confirmed booking without re-booking', async () => {
    const provider = new StubProvider();
    const { service } = setup(provider);
    const prepared = await service.prepare('u1', prepareDto);

    const first = await service.create('u1', {
      bookingId: prepared.id,
      idempotencyKey: 'k1',
    });
    const second = await service.create('u1', {
      bookingId: prepared.id,
      idempotencyKey: 'k1',
    });

    expect(first.status).toBe('confirmed');
    expect(second.status).toBe('confirmed');
    expect(provider.createCalls).toBe(1);
  });

  it('create rejects a reused idempotency key on a different booking (no double booking)', async () => {
    const provider = new StubProvider();
    const { service } = setup(provider);
    const a = await service.prepare('u1', prepareDto);
    const b = await service.prepare('u1', { ...prepareDto, offerId: 'offer-2' });

    await service.create('u1', { bookingId: a.id, idempotencyKey: 'k1' });
    await expect(
      service.create('u1', { bookingId: b.id, idempotencyKey: 'k1' }),
    ).rejects.toMatchObject({ code: 'duplicate_request' });
  });

  it('create marks the booking failed when the provider errors', async () => {
    const provider = new StubProvider();
    const { service, repo } = setup(provider);
    const prepared = await service.prepare('u1', prepareDto);

    provider.createFails = true;
    await expect(
      service.create('u1', { bookingId: prepared.id, idempotencyKey: 'k1' }),
    ).rejects.toMatchObject({ code: 'provider_error' });
    expect(repo.rows[0].status).toBe('failed');
  });

  it('ignores sub-cent price drift (tolerance)', async () => {
    const provider = new StubProvider();
    const { service } = setup(provider);
    const prepared = await service.prepare('u1', prepareDto);

    provider.price = 100.005;
    const confirmed = await service.create('u1', {
      bookingId: prepared.id,
      idempotencyKey: 'k1',
    });
    expect(confirmed.status).toBe('confirmed');
  });

  it('enforces JWT-scoped ownership on reads', async () => {
    const { service } = setup();
    const prepared = await service.prepare('u1', prepareDto);
    await expect(service.get('u2', prepared.id)).rejects.toMatchObject({
      code: 'booking_not_found',
    });
  });

  it('cancel is capability-gated', async () => {
    const { service } = setup();
    const prepared = await service.prepare('u1', prepareDto);
    await expect(service.cancel('u1', prepared.id)).rejects.toMatchObject({
      code: 'capability_unsupported',
    });
  });

  it('maps each error code to a stable HTTP status', () => {
    expect(new BookingException('price_changed', 'x').getStatus()).toBe(409);
    expect(new BookingException('offer_not_found', 'x').getStatus()).toBe(404);
    expect(new BookingException('provider_unavailable', 'x').getStatus()).toBe(503);
    expect(new BookingException('capability_unsupported', 'x').getStatus()).toBe(422);
    expect(new BookingException('unauthorized', 'x').getStatus()).toBe(401);
  });
});
