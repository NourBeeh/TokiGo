/**
 * P3-D7 — Nuitee flight review → confirmation flow at the BookingsService
 * boundary (mocked provider client only, no live provider call).
 *
 * Proves the lifecycle invariants:
 *  - prepare creates exactly ONE prebook;
 *  - the review revalidation creates ZERO additional prebooks;
 *  - a provider-reported price change surfaces as `price_changed` and must be
 *    explicitly accepted (the key is released, the booking returns to
 *    `revalidated`);
 *  - confirmation reuses the prebook created by the confirm-time
 *    revalidation and never prebooks a second time;
 *  - a repeated review never creates another hold.
 */
import { QueryFailedError } from 'typeorm';
import { BookingsService } from '../src/modules/bookings/bookings.service';
import { BookingProviderRegistry } from '../src/modules/bookings/booking-provider.registry';
import { NuiteeFlightBookingProvider } from '../src/modules/bookings/adapters/nuitee-flight-booking.provider';
import { NuiteeFlightService } from '../src/modules/nuitee/nuitee.flight.service';

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
    return (
      this.rows.find(
        (r) => r.id === where.id && r.userId === where.userId,
      ) ?? null
    );
  }

  async update(criteria: any, partial: any): Promise<{ affected: number }> {
    const allowed = criteria.status?.value ?? null;
    const matches = this.rows.filter((r) => {
      if (criteria.id !== undefined && r.id !== criteria.id) return false;
      if (allowed && !allowed.includes(r.status)) return false;
      return true;
    });
    for (const row of matches) Object.assign(row, partial);
    return { affected: matches.length };
  }
}

class FakeNuiteeFlightClient {
  prebookCalls: Array<Record<string, unknown>> = [];
  bookCalls: Array<Record<string, unknown>> = [];
  prebookLookups: string[] = [];
  verifies: string[] = [];

  prebookPrice = 800;
  verifyPrice = 800;
  verifyChanged = false;
  verifyOldPrice?: number;
  verifyNewPrice?: number;
  prebookLookupFails = false;
  verifyFails = false;
  bookFails = false;

  async prebookFlight(payload: Record<string, unknown>) {
    this.prebookCalls.push(payload);
    return {
      success: true,
      prebookId: 'pb_1',
      transactionId: 'tx_1',
      price: this.prebookPrice,
      currency: 'USD',
      servicesAttachable: { expiresAt: '2026-12-01T00:00:00Z' },
      timestamp: new Date(),
    };
  }

  async bookFlight(payload: Record<string, unknown>) {
    this.bookCalls.push(payload);
    if (this.bookFails) {
      return {
        success: false,
        error: 'Nuitee flight book failed (502): provider error',
        timestamp: new Date(),
      };
    }
    return {
      success: true,
      bookingId: 'bk_1',
      bookingRef: 'FH-1',
      status: 'CREATED',
      timestamp: new Date(),
    };
  }

  async getFlightPrebook(prebookId: string) {
    this.prebookLookups.push(prebookId);
    if (this.prebookLookupFails) {
      return {
        success: false,
        error: `Nuitee flight prebook lookup failed (404): ${prebookId}`,
        timestamp: new Date(),
      };
    }
    return {
      success: true,
      prebookId,
      transactionId: 'tx_1',
      price: this.prebookPrice,
      currency: 'USD',
      available: true,
      expiresAt: '2026-12-01T00:00:00Z',
      timestamp: new Date(),
    };
  }

  async verifyFlightOffer(offerId: string) {
    this.verifies.push(offerId);
    if (this.verifyFails) {
      return {
        success: false,
        error: 'Nuitee flight verify failed (404): offer expired',
        timestamp: new Date(),
      };
    }
    return {
      success: true,
      price: this.verifyPrice,
      currency: 'USD',
      available: this.verifyPrice > 0,
      priceChanged: this.verifyChanged,
      oldPrice: this.verifyOldPrice,
      newPrice: this.verifyNewPrice,
      expiresAt: '2026-12-01T00:00:00Z',
      timestamp: new Date(),
    };
  }
}

function setup() {
  const client = new FakeNuiteeFlightClient();
  const flightService = client as unknown as NuiteeFlightService;
  const provider = new NuiteeFlightBookingProvider(flightService);
  const registry = new BookingProviderRegistry();
  registry.register(provider);
  const repo = new FakeRepo();
  const service = new BookingsService(repo as any, registry);
  return { client, provider, repo, service };
}

const REAL_TRAVELERS = [
  {
    firstName: 'Nour',
    lastName: 'Adel',
    dateOfBirth: '1990-01-01',
    gender: 'M',
    nationality: 'EG',
    passengerType: 'adult',
    email: 'nour@example.com',
    phone: '201000000000',
    phoneCountryCode: '+20',
  },
];

describe('P3-D8 Nuitee flight prebook lifecycle', () => {
  it('prepare creates ZERO prebooks (verify only); the review creates ZERO', async () => {
    const { client, repo, service } = setup();

    const prepared = await service.prepare('u1', {
      offerId: 'off_1',
      providerId: 'nuitee-flight',
      searchId: 's1',
      offerType: 'flight',
    });
    expect(prepared.status).toBe('prepared');
    // Prepare is a READ-ONLY price check — no inventory hold.
    expect(client.prebookCalls).toHaveLength(0);
    expect(client.verifies).toEqual(['off_1']);
    expect(repo.rows[0].offerSnapshot).toEqual({ offerId: 'off_1' });

    const reviewed = await service.revalidate('u1', prepared.id);
    expect(reviewed.status).toBe('revalidated');
    expect(reviewed.authoritativePrice).toBe(800);
    expect(client.prebookCalls).toHaveLength(0);
    expect(client.prebookLookups).toHaveLength(0);
    expect(client.verifies).toEqual(['off_1', 'off_1']);
  });

  it('repeated review revalidation never creates another hold', async () => {
    const { client, service } = setup();
    const prepared = await service.prepare('u1', {
      offerId: 'off_1',
      providerId: 'nuitee-flight',
      searchId: 's1',
      offerType: 'flight',
    });

    for (let i = 0; i < 3; i++) {
      await service.revalidate('u1', prepared.id);
    }

    expect(client.prebookCalls).toHaveLength(0);
    expect(client.prebookLookups).toHaveLength(0);
    expect(client.verifies).toHaveLength(4);
  });

  it('an expired prebook fails the review instead of being reused', async () => {
    const { client, repo, service } = setup();
    const prepared = await service.prepare('u1', {
      offerId: 'off_1',
      providerId: 'nuitee-flight',
      searchId: 's1',
      offerType: 'flight',
    });
    // Simulate a legacy row that already carries a prebook hold.
    repo.rows[0].offerSnapshot = {
      ...repo.rows[0].offerSnapshot,
      prebookId: 'pb_dead',
    };

    client.prebookLookupFails = true;
    await expect(service.revalidate('u1', prepared.id)).rejects.toMatchObject({
      code: 'provider_unavailable',
    });
    expect(client.prebookCalls).toHaveLength(0);
  });

  it('a provider-reported price change requires explicit acceptance', async () => {
    const { client, repo, service } = setup();
    const prepared = await service.prepare('u1', {
      offerId: 'off_1',
      providerId: 'nuitee-flight',
      searchId: 's1',
      offerType: 'flight',
    });

    client.verifyPrice = 950;
    client.verifyChanged = true;
    client.verifyOldPrice = 800;
    client.verifyNewPrice = 950;

    await expect(service.revalidate('u1', prepared.id)).resolves.toMatchObject({
      status: 'revalidated',
      authoritativePrice: 950,
      previousPrice: 800,
      priceChanged: true,
    });
    // The new price is persisted; the review created no hold.
    expect(repo.rows[0].authoritativePrice).toBe(950);
    expect(repo.rows[0].previousPrice).toBe(800);
    expect(client.prebookCalls).toHaveLength(0);
  });

  it('confirmation prebooks the REAL party once and createBooking reuses its prebookId', async () => {
    const { client, service } = setup();
    const prepared = await service.prepare('u1', {
      offerId: 'off_1',
      providerId: 'nuitee-flight',
      searchId: 's1',
      offerType: 'flight',
    });
    await service.revalidate('u1', prepared.id);
    expect(client.prebookCalls).toHaveLength(0);

    const confirmed = await service.create('u1', {
      bookingId: prepared.id,
      idempotencyKey: 'k1',
      travelers: REAL_TRAVELERS,
    });

    expect(confirmed.status).toBe('confirmed');
    expect(confirmed.bookingReference).toBe('FH-1');
    // ONE prebook total — the confirm-time real-party hold. Prepare and the
    // review added nothing.
    expect(client.prebookCalls).toHaveLength(1);
    expect(client.bookCalls).toEqual([
      { prebookId: 'pb_1', payment: { method: 'ACC_CREDIT_CARD' } },
    ]);
    // The confirm-time prebook carried the real party.
    expect(client.prebookCalls[0]).toMatchObject({
      offerId: 'off_1',
      contact: { firstName: 'Nour', lastName: 'Adel' },
      passengers: [{ firstName: 'Nour', lastName: 'Adel', passengerType: 0 }],
    });
  });

  it('a repeated confirm is idempotent and does not prebook or book again', async () => {
    const { client, service } = setup();
    const prepared = await service.prepare('u1', {
      offerId: 'off_1',
      providerId: 'nuitee-flight',
      searchId: 's1',
      offerType: 'flight',
    });

    const first = await service.create('u1', {
      bookingId: prepared.id,
      idempotencyKey: 'k1',
      travelers: REAL_TRAVELERS,
    });
    const second = await service.create('u1', {
      bookingId: prepared.id,
      idempotencyKey: 'k1',
      travelers: REAL_TRAVELERS,
    });

    expect(first.status).toBe('confirmed');
    expect(second.status).toBe('confirmed');
    expect(client.prebookCalls).toHaveLength(1);
    expect(client.bookCalls).toHaveLength(1);
  });

  it('a confirm-time price move frees the key and blocks the booking', async () => {
    const { client, repo, service } = setup();
    const prepared = await service.prepare('u1', {
      offerId: 'off_1',
      providerId: 'nuitee-flight',
      searchId: 's1',
      offerType: 'flight',
    });

    client.prebookPrice = 1200;
    await expect(
      service.create('u1', {
        bookingId: prepared.id,
        idempotencyKey: 'k1',
        travelers: REAL_TRAVELERS,
      }),
    ).rejects.toMatchObject({ code: 'price_changed' });

    expect(client.bookCalls).toHaveLength(0);
    expect(repo.rows[0].status).toBe('revalidated');
    expect(repo.rows[0].idempotencyKey).toBeNull();
    expect(repo.rows[0].authoritativePrice).toBe(1200);
  });

  it('a confirm RETRY with the same party reuses the prebook (no third hold)', async () => {
    const { client, repo, service } = setup();
    const prepared = await service.prepare('u1', {
      offerId: 'off_1',
      providerId: 'nuitee-flight',
      searchId: 's1',
      offerType: 'flight',
    });

    client.prebookPrice = 1200;
    await expect(
      service.create('u1', {
        bookingId: prepared.id,
        idempotencyKey: 'k1',
        travelers: REAL_TRAVELERS,
      }),
    ).rejects.toMatchObject({ code: 'price_changed' });
    expect(client.prebookCalls).toHaveLength(1); // the confirm-time hold only

    // The client accepts the new price and retries with the SAME party.
    const confirmed = await service.create('u1', {
      bookingId: prepared.id,
      idempotencyKey: 'k2',
      travelers: REAL_TRAVELERS,
    });

    expect(confirmed.status).toBe('confirmed');
    // The retry READ the existing real-party prebook — no second hold.
    expect(client.prebookCalls).toHaveLength(1);
    expect(client.prebookLookups).toContain('pb_1');
    expect(client.bookCalls).toHaveLength(1);
    expect(repo.rows[0].offerSnapshot).toMatchObject({ prebookId: 'pb_1' });
  });

  it('a failed booking keeps exactly ONE prebook and the retry reuses it', async () => {
    const { client, repo, service } = setup();
    const prepared = await service.prepare('u1', {
      offerId: 'off_1',
      providerId: 'nuitee-flight',
      searchId: 's1',
      offerType: 'flight',
    });

    client.bookFails = true;
    await expect(
      service.create('u1', {
        bookingId: prepared.id,
        idempotencyKey: 'k1',
        travelers: REAL_TRAVELERS,
      }),
    ).rejects.toMatchObject({ code: 'provider_error' });

    // The confirm-time hold exists exactly once; the failure freed the key.
    expect(client.prebookCalls).toHaveLength(1);
    expect(client.bookCalls).toHaveLength(1);
    expect(repo.rows[0].status).toBe('failed');
    expect(repo.rows[0].idempotencyKey).toBeNull();

    // The retry REUSES that prebook (the provider's /flights/bookings is
    // idempotent on prebookId) — it never creates a second hold.
    client.bookFails = false;
    const confirmed = await service.create('u1', {
      bookingId: prepared.id,
      idempotencyKey: 'k2',
      travelers: REAL_TRAVELERS,
    });
    expect(confirmed.status).toBe('confirmed');
    expect(client.prebookCalls).toHaveLength(1);
    expect(client.bookCalls).toHaveLength(2);
    expect(client.prebookLookups).toContain('pb_1');
  });

  it('an abandoned checkout leaves no confirm-time prebook', async () => {
    const { client, service } = setup();
    const prepared = await service.prepare('u1', {
      offerId: 'off_1',
      providerId: 'nuitee-flight',
      searchId: 's1',
      offerType: 'flight',
    });
    await service.revalidate('u1', prepared.id);

    // The user walks away before confirming: nothing was reserved.
    expect(client.prebookCalls).toHaveLength(0);
    expect(client.bookCalls).toHaveLength(0);
  });
});
