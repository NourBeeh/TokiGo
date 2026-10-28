import { FxService } from '../src/common/market/fx.service';
import { PricingService } from '../src/common/market/pricing.service';
import { CacheService } from '../src/modules/cache/cache.service';
import { MARKET_CONFIGS, marketFor, DEFAULT_MARKET } from '../src/common/market/market-context';

/**
 * Market + FX + Pricing contract tests (spec points 3-6, 35).
 * Deterministic offline coverage — no network, no provider keys.
 */

describe('MarketContext (spec point 3)', () => {
  it('EG is the default production market with EGP/ar-EG', () => {
    expect(DEFAULT_MARKET.displayCurrency).toBe('EGP');
    expect(DEFAULT_MARKET.locale).toBe('ar-EG');
    expect(DEFAULT_MARKET.marketCountry).toBe('EG');
    expect(DEFAULT_MARKET.paymentRegion).toBe('EG');
  });

  it('marketFor resolves known codes and falls back to EG', () => {
    expect(marketFor('SA').displayCurrency).toBe('SAR');
    expect(marketFor('ae').displayCurrency).toBe('AED');
    expect(marketFor('XX')).toBe(DEFAULT_MARKET);
    expect(marketFor(null)).toBe(DEFAULT_MARKET);
  });

  it('SA/AE are prepared but separate contexts (no merged country field)', () => {
    expect(MARKET_CONFIGS.SA.paymentRegion).toBe('SA');
    expect(MARKET_CONFIGS.AE.paymentRegion).toBe('AE');
    expect(MARKET_CONFIGS.EG.posCountry).not.toBe(MARKET_CONFIGS.SA.posCountry);
  });
});

describe('PricingService (spec point 35 + O.6)', () => {
  let pricing: PricingService;
  let fx: FxService;
  let fetchSpy: jest.SpyInstance;

  beforeAll(() => {
    const cache = new CacheService({
      get: async () => null,
      set: async () => undefined,
      delete: async () => undefined,
      invalidate: async () => undefined,
    } as any);
    fx = new FxService(cache);
    pricing = new PricingService(fx);
  });

  beforeEach(() => {
    // Deterministic FX: USD->EGP fixed at 48.5
    fetchSpy = jest.spyOn(globalThis, 'fetch').mockResolvedValue({
      ok: true,
      json: async () => ({ rates: { EGP: 48.5 } }),
    } as any);
  });

  afterEach(() => {
    fetchSpy.mockRestore();
  });

  it('produces a full EGP breakdown while preserving the USD provider amount', async () => {
    const quote = await pricing.quote(100, 'USD');
    expect(quote.providerAmount).toBe(100);
    expect(quote.providerCurrency).toBe('USD');
    expect(quote.customerCurrency).toBe('EGP');
    expect(quote.customerAmount).toBe(4850);
    expect(quote.lines[0].type).toBe('BASE');
    expect(quote.lines[0].amount).toBe(4850);
    expect(quote.fx.source).toBe('open.er-api.com');
    expect(quote.pricingVersion).toBeTruthy();
    expect(new Date(quote.expiresAt).getTime()).toBeGreaterThan(Date.now());
  });

  it('same input + same FX snapshot + same version => same amount (determinism)', async () => {
    const a = await pricing.quote(120.5, 'USD');
    const b = await pricing.quote(120.5, 'USD');
    expect(a.customerAmount).toBe(b.customerAmount);
    expect(a.pricingVersion).toBe(b.pricingVersion);
  });

  it('applies markup and payment fee as explicit lines, never hidden in base', async () => {
    const quote = await pricing.quote(100, 'USD', { markupPct: 5, paymentFeePct: 2 });
    const markup = quote.lines.find(l => l.type === 'MARKUP');
    const fee = quote.lines.find(l => l.type === 'PAYMENT_FEE');
    expect(markup?.amount).toBeCloseTo(242.5, 0); // 5% of 4850
    expect(fee?.amount).toBeCloseTo(97, 0); // 2% of 4850
    expect(quote.customerAmount).toBeGreaterThanOrEqual(4850 + 242 + 97 - 1);
  });

  it('identity conversion when provider currency equals display currency', async () => {
    const quote = await pricing.quote(100, 'EGP');
    expect(quote.customerAmount).toBe(100);
    expect(quote.fx.source).toBe('identity');
    expect(quote.providerAmount).toBe(100);
  });

  it('enrichOffer never mutates provider price/currency fields', async () => {
    const offer = { id: 'x', price: 80, currency: 'EUR' };
    fetchSpy.mockResolvedValue({
      ok: true,
      json: async () => ({ rates: { EGP: 52.4 } }),
    } as any);
    const enriched = await pricing.enrichOffer(offer);
    expect(enriched.price).toBe(80);
    expect(enriched.currency).toBe('EUR');
    expect(enriched.customerPrice.customerCurrency).toBe('EGP');
    expect(enriched.customerPrice.providerAmount).toBe(80);
  });

  it('falls back to static rates when the FX source is unreachable', async () => {
    fetchSpy.mockRejectedValue(new Error('network down'));
    const quote = await pricing.quote(10, 'USD');
    expect(quote.fx.source).toBe('fallback-static');
    expect(quote.customerAmount).toBe(485); // 10 * 48.5
  });
});

describe('FxService (spec point 6)', () => {
  it('exposes source, rateId and capturedAt for auditability', async () => {
    const cache = new CacheService({
      get: async () => null,
      set: async () => undefined,
      delete: async () => undefined,
      invalidate: async () => undefined,
    } as any);
    const service = new FxService(cache);
    const spy = jest.spyOn(globalThis, 'fetch').mockResolvedValue({
      ok: true,
      json: async () => ({ rates: { EGP: 47.9 } }),
    } as any);
    const rate = await service.getRate('USD', 'EGP');
    expect(rate.rate).toBe(47.9);
    expect(rate.rateId).toContain('USD-EGP');
    expect(rate.capturedAt).toBeTruthy();
    expect(rate.source).toBe('open.er-api.com');
    spy.mockRestore();
  });
});
