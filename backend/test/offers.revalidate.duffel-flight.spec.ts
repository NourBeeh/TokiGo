/**
 * Phase 2D/2E prep — Duffel offer revalidation must fail closed.
 *
 * Revalidation is the last provider check before checkout. A response without
 * a positive price and the provider's own currency is never an OK: defaulting
 * to USD/0 would let the customer continue on a fabricated amount.
 */
import { OffersController } from '../src/modules/offers/offers.controller';
import { DuffelService } from '../src/modules/duffel/duffel.service';

function serviceWithOffer(offer: any): DuffelService {
  const config = {
    get: (name: string) =>
      name === 'DUFFEL_ACCESS_TOKEN' ? 'test_token' : undefined,
  };
  const service = new DuffelService(config as any);
  (service as any).duffelClient = {
    offers: {
      get: async () => ({ data: offer }),
    },
  };
  return service;
}

const liveOffer = {
  id: 'off_duffel_1',
  total_amount: '542.30',
  total_currency: 'USD',
  expires_at: '2026-10-01T12:00:00Z',
  passengers: [
    { id: 'pas_1', type: 'adult', age: 30 },
    { id: '', type: 'adult', age: 30 },
    { type: 'child', age: 8 },
  ],
};

describe('DuffelService.revalidateOffer', () => {
  it('returns provider price/currency/expiry and keeps only usable passenger ids', async () => {
    const service = serviceWithOffer(liveOffer);

    const result = await service.revalidateOffer('off_duffel_1');

    expect(result.success).toBe(true);
    expect(result.data).toMatchObject({
      price: 542.3,
      currency: 'USD',
      expiresAt: '2026-10-01T12:00:00Z',
      available: true,
      rawId: 'off_duffel_1',
    });
    expect(result.data.passengers).toEqual([
      { id: 'pas_1', type: 'adult', age: 30 },
    ]);
  });

  it('does not invent an expiry when Duffel did not send one', async () => {
    const service = serviceWithOffer({ ...liveOffer, expires_at: undefined });

    const result = await service.revalidateOffer('off_duffel_1');

    expect(result.success).toBe(true);
    expect(result.data.expiresAt).toBeUndefined();
  });

  it('fails closed when the price is missing', async () => {
    const service = serviceWithOffer({ ...liveOffer, total_amount: undefined });

    const result = await service.revalidateOffer('off_duffel_1');

    expect(result.success).toBe(false);
    expect(result.error).toContain('missing a usable price or currency');
  });

  it('fails closed when the price is zero or negative', async () => {
    for (const total_amount of ['0', '-10.00']) {
      const service = serviceWithOffer({ ...liveOffer, total_amount });
      const result = await service.revalidateOffer('off_duffel_1');
      expect(result.success).toBe(false);
      expect(result.error).toContain('missing a usable price or currency');
    }
  });

  it('fails closed when the currency is missing or empty', async () => {
    for (const total_currency of [undefined, '', '   ']) {
      const service = serviceWithOffer({ ...liveOffer, total_currency });
      const result = await service.revalidateOffer('off_duffel_1');
      expect(result.success).toBe(false);
      expect(result.error).toContain('missing a usable price or currency');
    }
  });

  it('reports not-configured instead of pretending an offer was checked', async () => {
    const service = new DuffelService({ get: () => undefined } as any);
    const result = await service.revalidateOffer('off_duffel_1');
    expect(result.success).toBe(false);
    expect(result.error).toContain('not configured');
  });
});

class FakeDuffelService {
  calls: string[] = [];
  result: any = {
    success: true,
    data: {
      price: 500,
      currency: 'USD',
      expiresAt: '2026-10-01T12:00:00Z',
    },
  };

  async revalidateOffer(offerId: string) {
    this.calls.push(offerId);
    return this.result;
  }
}

function setup() {
  const duffel = new FakeDuffelService();
  const controller = new OffersController(
    duffel as unknown as DuffelService,
    {} as any,
    {} as any,
  );
  return { controller, duffel };
}

const dto = {
  offerId: 'off_duffel_1',
  providerId: 'duffel-flight',
  offerType: 'flight',
};

describe('POST /offers/revalidate — duffel-flight', () => {
  it('returns OK with the exact offer id and verified price', async () => {
    const { controller, duffel } = setup();

    const res = await controller.revalidate({} as any, {
      ...dto,
      knownPrice: '500',
    });

    expect(res).toMatchObject({
      status: 'OK',
      offerId: 'off_duffel_1',
      price: 500,
      currency: 'USD',
      expiresAt: '2026-10-01T12:00:00Z',
      priceChanged: false,
      termsChanged: false,
    });
    expect(res.checkedAt).toEqual(expect.any(String));
    expect(duffel.calls).toEqual(['off_duffel_1']);
  });

  it('returns PRICE_CHANGED when the verified amount moved', async () => {
    const { controller } = setup();

    const res = await controller.revalidate({} as any, {
      ...dto,
      knownPrice: '420',
    });

    expect(res).toMatchObject({
      status: 'PRICE_CHANGED',
      offerId: 'off_duffel_1',
      oldPrice: 420,
      newPrice: 500,
      currency: 'USD',
    });
  });

  it('returns UNAVAILABLE when the adapter could not verify the offer', async () => {
    const { controller, duffel } = setup();
    duffel.result = { success: false, error: 'Duffel offer expired' };

    const res = await controller.revalidate({} as any, dto);

    expect(res).toEqual({
      status: 'UNAVAILABLE',
      offerId: 'off_duffel_1',
      reason: 'Duffel offer expired',
    });
  });

  it('fails closed on a non-positive price even if an adapter claimed success', async () => {
    const { controller, duffel } = setup();
    duffel.result = {
      success: true,
      data: { price: 0, currency: 'USD' },
    };

    const res = await controller.revalidate({} as any, dto);

    expect(res).toEqual({
      status: 'UNAVAILABLE',
      offerId: 'off_duffel_1',
      reason: 'Provider returned no usable price',
    });
  });

  it('fails closed when the verified currency is missing', async () => {
    const { controller, duffel } = setup();
    duffel.result = {
      success: true,
      data: { price: 500, currency: '' },
    };

    const res = await controller.revalidate({} as any, dto);

    expect(res).toEqual({
      status: 'UNAVAILABLE',
      offerId: 'off_duffel_1',
      reason: 'Provider returned no currency',
    });
  });
});
