import { priceVersionOf } from '../src/common/pricing/price-version';

/**
 * The accepted-price version is the binding between a payment attempt and the
 * exact commercial state the customer accepted. It must be deterministic for
 * the same facts and different for any change that moves money or conditions.
 */
describe('priceVersionOf', () => {
  const base = {
    providerId: 'duffel-flight',
    offerId: 'offer-1',
    offerType: 'flight',
    amount: 4850.75,
    currency: 'EGP',
    termsVersion: 'terms-v1-abc',
  };

  it('is stable for the same facts and key order', () => {
    const reordered = {
      termsVersion: base.termsVersion,
      currency: base.currency,
      amount: base.amount,
      offerType: base.offerType,
      offerId: base.offerId,
      providerId: base.providerId,
    };
    expect(priceVersionOf(reordered)).toBe(priceVersionOf(base));
    expect(priceVersionOf(base)).toMatch(/^price-v1-[a-f0-9]{64}$/);
  });

  it('ignores sub-cent float noise from the real column type', () => {
    expect(priceVersionOf({ ...base, amount: 100 })).toBe(
      priceVersionOf({ ...base, amount: 100.001 }),
    );
  });

  it.each([
    ['amount', { amount: 4850.76 }],
    ['currency', { currency: 'USD' }],
    ['terms version', { termsVersion: 'terms-v1-def' }],
    ['provider', { providerId: 'nuitee-flight' }],
    ['offer', { offerId: 'offer-2' }],
    ['offer type', { offerType: 'hotel' }],
  ])('changes when the %s changes', (_label, patch) => {
    expect(priceVersionOf({ ...base, ...patch })).not.toBe(priceVersionOf(base));
  });
});
