import { createHash } from 'crypto';

import { canonicalJson } from './offer-terms';

/**
 * The exact commercial facts a payment is allowed to settle.
 *
 * A version is deliberately bound to the provider offer, amount, currency and
 * accepted terms. It excludes timestamps and other display metadata so the
 * SAME price and conditions always produce the SAME version — otherwise an
 * unchanged revalidation would spuriously invalidate a legitimate payment.
 */
export interface PriceVersionInput {
  providerId: string;
  offerId: string;
  offerType: string;
  amount: number;
  currency: string;
  termsVersion: string;
}

/**
 * Stable version of the accepted price.
 *
 * `bookings.authoritativePrice` is a Postgres `real`, so the amount is rounded
 * to cents before hashing: a float32/JSON round trip of the same money must not
 * produce a different version.
 */
export function priceVersionOf(input: PriceVersionInput): string {
  const amount = Math.round(input.amount * 100) / 100;
  const hash = createHash('sha256')
    .update(
      canonicalJson({
        providerId: input.providerId,
        offerId: input.offerId,
        offerType: input.offerType,
        amount,
        currency: input.currency,
        termsVersion: input.termsVersion,
      }),
    )
    .digest('hex');
  return `price-v1-${hash}`;
}
