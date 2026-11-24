/**
 * Phase 2E — shared price/terms-change confirmation (backend contract).
 *
 * These tests prove the customer can never be booked on a changed amount or
 * changed fare conditions without an explicit, bound acceptance:
 *  - price increases, decreases and unchanged prices;
 *  - terms-only changes;
 *  - expired/unavailable offers and provider failures;
 *  - declined updates and repeated revalidations;
 *  - acceptance bound to provider + offer + price + currency + terms version;
 *  - audit rows for detection, acceptance and decline.
 */
import { QueryFailedError } from 'typeorm';
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
      this.rows.find((r) => r.id === where.id && r.userId === where.userId) ??
      null
    );
  }

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
      if (criteria.userId !== undefined && r.userId !== criteria.userId) {
        return false;
      }
      if (allowed && !allowed.includes(r.status)) return false;
      return true;
    });
    if (partial.idempotencyKey != null) {
      const clash = this.rows.find(
        (r) =>
          !matches.includes(r) &&
          r.userId === matches[0]?.userId &&
          r.idempotencyKey === partial.idempotencyKey,
      );
      if (clash) {
        throw new QueryFailedError('UPDATE', [], { code: '23505' } as any);
      }
    }
    for (const row of matches) Object.assign(row, partial);
    return { affected: matches.length };
  }
}

class FakeAuditRepo {
  rows: any[] = [];
  create(obj: any): any {
    return { ...obj, id: `a${this.rows.length + 1}`, createdAt: new Date() };
  }
  async save(row: any): Promise<any> {
    this.rows.push(row);
    return row;
  }
}

class TermsProvider implements BookingProvider {
  readonly providerId = 'stub-flight';
  readonly providerName = 'Stub Provider';
  readonly bookingCapability = { book: true, cancel: false, revalidate: true };

  price = 100;
  currency = 'USD';
  available = true;
  terms: Record<string, any> | undefined = {
    cabinClass: 'economy',
    conditions: { refundableBeforeDeparture: { allowed: false } },
  };
  changedTerms: string[] | undefined;
  failRevalidate = false;
  createCalls = 0;

  async revalidateBooking(): Promise<ProviderResult<BookingRevalidation>> {
    if (this.failRevalidate) {
      return {
        success: false,
        providerId: this.providerId,
        providerName: this.providerName,
        error: 'provider offline',
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
        expiresAt: new Date(Date.now() + 60000).toISOString(),
        ...(this.terms
          ? { terms: JSON.parse(JSON.stringify(this.terms)) }
          : {}),
        ...(this.changedTerms ? { changedTerms: this.changedTerms } : {}),
      },
      timestamp: new Date(),
    };
  }

  async createBooking(
    input: CreateBookingInput,
  ): Promise<ProviderResult<CreatedBooking>> {
    this.createCalls++;
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

function setup() {
  const repo = new FakeRepo();
  const audit = new FakeAuditRepo();
  const provider = new TermsProvider();
  const registry = new BookingProviderRegistry();
  registry.register(provider);
  const service = new BookingsService(repo as any, registry, audit as any);
  return { repo, audit, provider, service };
}

const prepareDto: PrepareBookingDto = {
  offerId: 'offer-1',
  providerId: 'stub-flight',
  searchId: 's1',
  offerType: 'flight',
};

/** Resolves with the rejection reason; fails if the promise resolves. */
async function rejection(promise: Promise<any>): Promise<any> {
  try {
    await promise;
  } catch (error) {
    return error;
  }
  throw new Error('Expected the operation to reject');
}

describe('BookingsService — price/terms change confirmation', () => {
  it('prepare records the selected state as accepted with no pending change', async () => {
    const { service } = setup();
    const prepared = await service.prepare('u1', prepareDto);

    expect(prepared.priceChange).toMatchObject({
      providerId: 'stub-flight',
      offerId: 'offer-1',
      offerType: 'flight',
      previousPrice: null,
      currentPrice: 100,
      currency: 'USD',
      priceChanged: false,
      termsChanged: false,
      accepted: true,
      requiresAcceptance: false,
      decision: null,
    });
    expect(prepared.priceChange?.termsVersion).toMatch(/^terms-v1-/);
  });

  it('reports a price increase with difference, percentage and an acceptance requirement', async () => {
    const { service, provider, audit } = setup();
    const prepared = await service.prepare('u1', prepareDto);

    provider.price = 130;
    const res = await service.revalidate('u1', prepared.id);

    expect(res.priceChange).toMatchObject({
      previousPrice: 100,
      currentPrice: 130,
      currency: 'USD',
      priceChanged: true,
      termsChanged: false,
      changedTerms: [],
      accepted: false,
      requiresAcceptance: true,
    });
    expect(res.priceChange?.priceDifference).toBe(30);
    expect(res.priceChange?.priceChangePercent).toBeCloseTo(30, 2);
    expect(res.previousPrice).toBe(100);
    expect(res.authoritativePrice).toBe(130);
    expect(audit.rows.map((row) => row.action)).toContain(
      'booking.price_change.detected',
    );
    const detected = audit.rows.find(
      (row) => row.action === 'booking.price_change.detected',
    );
    expect(detected?.metadata).toMatchObject({
      bookingId: prepared.id,
      providerId: 'stub-flight',
      offerId: 'offer-1',
      previousPrice: 100,
      currentPrice: 130,
      currency: 'USD',
    });
  });

  it('reports a price decrease with a negative difference', async () => {
    const { service, provider } = setup();
    const prepared = await service.prepare('u1', prepareDto);

    provider.price = 80;
    const res = await service.revalidate('u1', prepared.id);

    expect(res.priceChange).toMatchObject({
      previousPrice: 100,
      currentPrice: 80,
      priceChanged: true,
      requiresAcceptance: true,
    });
    expect(res.priceChange?.priceDifference).toBe(-20);
    expect(res.priceChange?.priceChangePercent).toBeCloseTo(-20, 2);
  });

  it('does not require acceptance when price and terms are unchanged', async () => {
    const { service, audit } = setup();
    const prepared = await service.prepare('u1', prepareDto);

    const res = await service.revalidate('u1', prepared.id);

    expect(res.priceChange).toMatchObject({
      previousPrice: null,
      currentPrice: 100,
      priceChanged: false,
      termsChanged: false,
      accepted: true,
      requiresAcceptance: false,
    });
    expect(
      audit.rows.filter((row) => row.action === 'booking.price_change.detected'),
    ).toHaveLength(0);
  });

  it('blocks on a terms-only change and exposes previous and current terms', async () => {
    const { service, provider } = setup();
    const prepared = await service.prepare('u1', prepareDto);

    provider.terms = {
      cabinClass: 'economy',
      conditions: { refundableBeforeDeparture: { allowed: true } },
      baggageAllowances: [{ type: 'checked', quantity: 2 }],
    };
    const res = await service.revalidate('u1', prepared.id);

    expect(res.priceChange).toMatchObject({
      currentPrice: 100,
      priceChanged: false,
      termsChanged: true,
      accepted: false,
      requiresAcceptance: true,
    });
    expect(res.priceChange?.priceDifference).toBe(0);
    expect(res.priceChange?.changedTerms).toEqual(
      expect.arrayContaining(['conditions', 'baggageAllowances']),
    );
    expect(res.priceChange?.previousTerms).toMatchObject({
      conditions: { refundableBeforeDeparture: { allowed: false } },
    });
    expect(res.priceChange?.currentTerms).toMatchObject({
      conditions: { refundableBeforeDeparture: { allowed: true } },
    });
  });

  it('blocks confirm after a price change until the customer accepts', async () => {
    const { service, provider, repo } = setup();
    const prepared = await service.prepare('u1', prepareDto);

    provider.price = 175;
    await service.revalidate('u1', prepared.id);

    const error = await rejection(
      service.create('u1', { bookingId: prepared.id, idempotencyKey: 'k1' }),
    );
    expect(error.code).toBe('price_changed');
    expect(error.getResponse().details).toMatchObject({
      previousPrice: 100,
      currentPrice: 175,
      currency: 'USD',
      requiresAcceptance: true,
    });
    expect(provider.createCalls).toBe(0);
    expect(repo.rows[0].status).toBe('revalidated');
    expect(repo.rows[0].idempotencyKey).toBeNull();
    expect(repo.rows[0].providerMetadata.priceRevalidation.pending).toBe(true);
    expect(repo.rows[0].providerMetadata.priceAcceptance).toBeNull();
  });

  it('confirms only after an explicit acceptance bound to the new state', async () => {
    const { service, provider, audit } = setup();
    const prepared = await service.prepare('u1', prepareDto);

    provider.price = 130;
    const changed = await service.revalidate('u1', prepared.id);
    const pending = changed.priceChange!;

    const accepted = await service.decidePriceChange('u1', prepared.id, {
      decision: 'accept',
      expectedPrice: pending.currentPrice,
      expectedCurrency: pending.currency,
      expectedTermsVersion: pending.termsVersion,
    });
    expect(accepted.priceChange).toMatchObject({
      accepted: true,
      requiresAcceptance: false,
      decision: 'accepted',
      currentPrice: 130,
    });
    expect(accepted.priceChange?.decidedAt).toEqual(expect.any(String));

    const confirmed = await service.create('u1', {
      bookingId: prepared.id,
      idempotencyKey: 'k1',
    });
    expect(confirmed.status).toBe('confirmed');
    expect(provider.createCalls).toBe(1);
    expect(audit.rows.map((row) => row.action)).toEqual(
      expect.arrayContaining([
        'booking.price_change.detected',
        'booking.price_change.accepted',
      ]),
    );
  });

  it('rejects a stale acceptance when the shown amount no longer matches', async () => {
    const { service, provider } = setup();
    const prepared = await service.prepare('u1', prepareDto);

    provider.price = 130;
    await service.revalidate('u1', prepared.id);

    const error = await rejection(
      service.decidePriceChange('u1', prepared.id, {
        decision: 'accept',
        expectedPrice: 120,
        expectedCurrency: 'USD',
      }),
    );
    expect(error.code).toBe('price_changed');
    expect(error.getResponse().details).toMatchObject({ currentPrice: 130 });
    expect(provider.createCalls).toBe(0);
  });

  it('rejects a stale acceptance when the terms version no longer matches', async () => {
    const { service, provider } = setup();
    const prepared = await service.prepare('u1', prepareDto);

    provider.terms = {
      cabinClass: 'business',
      conditions: { refundableBeforeDeparture: { allowed: true } },
    };
    const changed = await service.revalidate('u1', prepared.id);

    await expect(
      service.decidePriceChange('u1', prepared.id, {
        decision: 'accept',
        expectedPrice: changed.priceChange!.currentPrice,
        expectedCurrency: changed.priceChange!.currency,
        expectedTermsVersion: 'terms-v1-stale',
      }),
    ).rejects.toMatchObject({ code: 'price_changed' });
  });

  it('declining keeps the booking unconfirmed and the decision auditable', async () => {
    const { service, provider, repo, audit } = setup();
    const prepared = await service.prepare('u1', prepareDto);

    provider.price = 150;
    await service.revalidate('u1', prepared.id);
    const declined = await service.decidePriceChange('u1', prepared.id, {
      decision: 'decline',
      expectedPrice: 150,
      expectedCurrency: 'USD',
    });

    expect(declined.priceChange).toMatchObject({
      decision: 'declined',
      accepted: false,
      requiresAcceptance: true,
      currentPrice: 150,
    });
    const declineAudit = audit.rows.find(
      (row) => row.action === 'booking.price_change.declined',
    );
    expect(declineAudit?.metadata).toMatchObject({
      decision: 'declined',
      previousPrice: 100,
      currentPrice: 150,
      providerId: 'stub-flight',
      offerId: 'offer-1',
    });

    await expect(
      service.create('u1', { bookingId: prepared.id, idempotencyKey: 'k1' }),
    ).rejects.toMatchObject({ code: 'price_changed' });
    expect(provider.createCalls).toBe(0);
    expect(repo.rows[0].status).not.toBe('confirmed');
  });

  it('keeps the original accepted price across repeated revalidations', async () => {
    const { service, provider, audit } = setup();
    const prepared = await service.prepare('u1', prepareDto);

    provider.price = 130;
    await service.revalidate('u1', prepared.id);
    provider.price = 140;
    const res = await service.revalidate('u1', prepared.id);

    expect(res.priceChange).toMatchObject({
      previousPrice: 100,
      currentPrice: 140,
      priceChanged: true,
      requiresAcceptance: true,
    });
    expect(res.priceChange?.priceDifference).toBe(40);
    expect(
      audit.rows.filter((row) => row.action === 'booking.price_change.detected'),
    ).toHaveLength(2);
  });

  it('keeps a declined decision when the same state is revalidated again', async () => {
    const { service, provider } = setup();
    const prepared = await service.prepare('u1', prepareDto);

    provider.price = 130;
    await service.revalidate('u1', prepared.id);
    await service.decidePriceChange('u1', prepared.id, {
      decision: 'decline',
      expectedPrice: 130,
      expectedCurrency: 'USD',
    });
    const again = await service.revalidate('u1', prepared.id);

    expect(again.priceChange).toMatchObject({
      decision: 'declined',
      requiresAcceptance: true,
      currentPrice: 130,
    });
  });

  it('invalidates an acceptance when terms change again before confirm', async () => {
    const { service, provider } = setup();
    const prepared = await service.prepare('u1', prepareDto);

    // Baseline accepted at terms A.
    provider.terms = {
      cabinClass: 'economy',
      conditions: { refundableBeforeDeparture: { allowed: true } },
    };
    await expect(
      service.create('u1', { bookingId: prepared.id, idempotencyKey: 'k1' }),
    ).rejects.toMatchObject({ code: 'price_changed' });
    // The blocked confirm left the row revalidated, not confirmed.
    expect(provider.createCalls).toBe(0);

    // Accept terms B, then move to terms C before confirming again.
    await service.decidePriceChange('u1', prepared.id, {
      decision: 'accept',
      expectedPrice: 100,
      expectedCurrency: 'USD',
    });
    provider.terms = {
      cabinClass: 'economy',
      conditions: { refundableBeforeDeparture: { allowed: false } },
      baggageAllowances: [{ type: 'checked', quantity: 1 }],
    };

    const error = await rejection(
      service.create('u1', { bookingId: prepared.id, idempotencyKey: 'k2' }),
    );
    expect(error.code).toBe('price_changed');
    expect(error.getResponse().details).toMatchObject({
      termsChanged: true,
      requiresAcceptance: true,
    });
    expect(provider.createCalls).toBe(0);
  });

  it('fails closed when the customer acceptance was never recorded', async () => {
    const { service, provider, repo } = setup();
    const prepared = await service.prepare('u1', prepareDto);
    // Simulate a legacy/pre-acceptance row.
    delete repo.rows[0].providerMetadata.priceAcceptance;

    await expect(
      service.create('u1', { bookingId: prepared.id, idempotencyKey: 'k1' }),
    ).rejects.toMatchObject({ code: 'price_changed' });
    expect(provider.createCalls).toBe(0);

    const accepted = await service.decidePriceChange('u1', prepared.id, {
      decision: 'accept',
      expectedPrice: 100,
      expectedCurrency: 'USD',
    });
    expect(accepted.priceChange?.accepted).toBe(true);
    const confirmed = await service.create('u1', {
      bookingId: prepared.id,
      idempotencyKey: 'k1',
    });
    expect(confirmed.status).toBe('confirmed');
  });

  it('surfaces an unavailable offer instead of booking it', async () => {
    const { service, provider, repo } = setup();
    const prepared = await service.prepare('u1', prepareDto);

    provider.available = false;
    await expect(
      service.revalidate('u1', prepared.id),
    ).rejects.toMatchObject({ code: 'no_availability' });

    await expect(
      service.create('u1', { bookingId: prepared.id, idempotencyKey: 'k1' }),
    ).rejects.toMatchObject({ code: 'no_availability' });
    expect(provider.createCalls).toBe(0);
    expect(repo.rows[0].status).toBe('failed');
  });

  it('surfaces a provider failure without changing the acceptance state', async () => {
    const { service, provider } = setup();
    const prepared = await service.prepare('u1', prepareDto);

    provider.failRevalidate = true;
    await expect(
      service.revalidate('u1', prepared.id),
    ).rejects.toMatchObject({ code: 'provider_unavailable' });

    await expect(
      service.create('u1', { bookingId: prepared.id, idempotencyKey: 'k1' }),
    ).rejects.toMatchObject({ code: 'provider_unavailable' });
    expect(provider.createCalls).toBe(0);
  });

  it('never accepts a decision for another user', async () => {
    const { service, provider } = setup();
    const prepared = await service.prepare('u1', prepareDto);

    provider.price = 130;
    await service.revalidate('u1', prepared.id);

    await expect(
      service.decidePriceChange('u2', prepared.id, { decision: 'accept' }),
    ).rejects.toMatchObject({ code: 'booking_not_found' });
  });
});
