import { Injectable } from '@nestjs/common';
import { FxService, FxRate } from './fx.service';
import { DEFAULT_MARKET, MarketContextValue, marketFor } from './market-context';

/**
 * PricingEngine (spec point 35) — deterministic customer price from provider
 * truth + FX snapshot + pricing version. Returns a complete breakdown; the
 * provider amount is preserved untouched alongside the customer total.
 *
 * Pricing rules are versioned so the same input + same FX snapshot + same
 * version always produce the same amount (acceptance rule point 35).
 */

export interface PriceBreakdownLine {
  type: 'BASE' | 'TAX' | 'PROVIDER_FEE' | 'PAYMENT_FEE' | 'MARKUP' | 'DISCOUNT';
  label: string;
  amount: number;
  currency: string;
}

export interface PriceQuote {
  providerAmount: number;
  providerCurrency: string;
  customerAmount: number;
  customerCurrency: string;
  lines: PriceBreakdownLine[];
  fx: FxRate;
  pricingVersion: string;
  expiresAt: string;
  market: string;
}

export const PRICING_VERSION = '2026.09.1';

// Display-only rounding: customer totals round to whole units for EGP-style
// currencies to avoid awkward piasters; recorded explicitly as a line.
const WHOLE_UNIT_CURRENCIES = new Set(['EGP']);

@Injectable()
export class PricingService {
  constructor(private readonly fxService: FxService) {}

  /**
   * Builds the authoritative customer quote for one provider-priced offer.
   * markupPct/paymentFeePct are configuration knobs (0 = disabled).
   */
  async quote(
    providerAmount: number,
    providerCurrency: string,
    opts: {
      market?: string;
      markupPct?: number;
      paymentFeePct?: number;
      ttlMinutes?: number;
    } = {},
  ): Promise<PriceQuote> {
    const market: MarketContextValue = marketFor(opts.market ?? DEFAULT_MARKET.marketCountry);
    const displayCurrency = market.displayCurrency;

    const converted = await this.fxService.convertForDisplay(
      providerAmount,
      providerCurrency,
      displayCurrency,
    );

    const markupPct = opts.markupPct ?? 0;
    const paymentFeePct = opts.paymentFeePct ?? 0;

    const base = converted.customerAmount;
    const markup = Math.round(base * (markupPct / 100) * 100) / 100;
    const paymentFee = Math.round(base * (paymentFeePct / 100) * 100) / 100;
    const subtotal = base + markup + paymentFee;

    const rounding =
      WHOLE_UNIT_CURRENCIES.has(displayCurrency) && !Number.isInteger(subtotal)
        ? Math.ceil(subtotal) - subtotal
        : 0;
    const customerTotal = Math.round((subtotal + rounding) * 100) / 100;

    const lines: PriceBreakdownLine[] = [
      { type: 'BASE', label: 'Base fare', amount: base, currency: displayCurrency },
    ];
    if (markup > 0) {
      lines.push({ type: 'MARKUP', label: 'Service fee', amount: markup, currency: displayCurrency });
    }
    if (paymentFee > 0) {
      lines.push({
        type: 'PAYMENT_FEE',
        label: 'Payment fee',
        amount: paymentFee,
        currency: displayCurrency,
      });
    }
    if (rounding > 0) {
      lines.push({
        type: 'TAX',
        label: 'Rounding',
        amount: rounding,
        currency: displayCurrency,
      });
    }

    return {
      providerAmount: converted.providerAmount,
      providerCurrency: converted.providerCurrency,
      customerAmount: customerTotal,
      customerCurrency: displayCurrency,
      lines,
      fx: converted.fx,
      pricingVersion: PRICING_VERSION,
      expiresAt: new Date(Date.now() + (opts.ttlMinutes ?? 30) * 60 * 1000).toISOString(),
      market: market.marketCountry,
    };
  }

  /**
   * Enriches a provider-mapped offer with the customer display price while
   * preserving every provider field untouched (spec point 5/O.6).
   */
  async enrichOffer<T extends { price: number; currency: string }>(
    offer: T,
    opts: { market?: string; markupPct?: number; paymentFeePct?: number } = {},
  ): Promise<T & { customerPrice: PriceQuote }> {
    const quote = await this.quote(offer.price, offer.currency, opts);
    return { ...offer, customerPrice: quote };
  }

  async enrichOffers<T extends { price: number; currency: string }>(
    offers: T[],
    opts: { market?: string; markupPct?: number; paymentFeePct?: number } = {},
  ): Promise<(T & { customerPrice: PriceQuote })[]> {
    const enriched: (T & { customerPrice: PriceQuote })[] = [];
    for (const offer of offers) {
      enriched.push(await this.enrichOffer(offer, opts));
    }
    return enriched;
  }
}
