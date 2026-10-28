import { Injectable, Logger } from '@nestjs/common';
import { CacheService } from '../../modules/cache/cache.service';

/**
 * FX service (spec point 6) — auditable conversion with source, timestamp
 * and rate ID. Customer display prices are derived from a captured snapshot;
 * provider amounts are never mutated.
 *
 * Rates are cached and stamped; the snapshot used to quote the customer is
 * stored with the offer so a historical booking can reconstruct its price.
 */

export interface FxRate {
  base: string;
  quote: string;
  rate: number;
  source: string;
  rateId: string;
  capturedAt: string; // ISO instant
}

const RATE_TTL_SECONDS = 15 * 60;

// Deterministic fallback rates — used only when the FX source is
// unreachable so search never blocks. Marked clearly by source.
const FALLBACK_RATES: Record<string, number> = {
  'USD:EGP': 48.5,
  'EUR:EGP': 52.4,
  'GBP:EGP': 61.7,
  'USD:USD': 1,
  'EUR:USD': 1.08,
  'GBP:USD': 1.27,
};

@Injectable()
export class FxService {
  private readonly logger = new Logger(FxService.name);

  constructor(private readonly cache: CacheService) {}

  /** Returns a rate snapshot for base->quote (e.g. USD->EGP). */
  async getRate(base: string, quote: string): Promise<FxRate> {
    const key = `fx:${base}:${quote}`;
    const cached = await this.cache.get<FxRate>(key);
    if (cached) return cached;

    let rate: number | undefined;
    let source = 'fallback-static';

    try {
      const response = await fetch(
        `https://open.er-api.com/v6/latest/${base}`,
        { signal: AbortSignal.timeout(4000) },
      );
      if (response.ok) {
        const body = (await response.json()) as { rates?: Record<string, number> };
        const fetched = body?.rates?.[quote];
        if (typeof fetched === 'number' && fetched > 0) {
          rate = fetched;
          source = 'open.er-api.com';
        }
      }
    } catch (e) {
      this.logger.warn(`FX fetch failed for ${base}->${quote}: ${(e as Error).message}`);
    }

    if (rate === undefined) {
      const direct = FALLBACK_RATES[`${base}:${quote}`];
      if (direct !== undefined) {
        rate = direct;
      } else {
        // Cross via USD as a last resort.
        const baseUsd = FALLBACK_RATES[`${base}:USD`];
        const usdQuote = FALLBACK_RATES[`USD:${quote}`];
        if (baseUsd && usdQuote) {
          rate = baseUsd * usdQuote;
        } else {
          rate = 1;
        }
      }
    }

    const snapshot: FxRate = {
      base,
      quote,
      rate,
      source,
      rateId: `${base}-${quote}-${Date.now()}`,
      capturedAt: new Date().toISOString(),
    };
    await this.cache.set(key, snapshot, RATE_TTL_SECONDS);
    return snapshot;
  }

  /**
   * Converts a provider amount into the customer display currency and
   * returns BOTH sides (spec point 5: never silently rewrite provider money).
   */
  async convertForDisplay(
    amount: number,
    providerCurrency: string,
    displayCurrency: string,
  ): Promise<{
    providerAmount: number;
    providerCurrency: string;
    customerAmount: number;
    customerCurrency: string;
    fx: FxRate;
  }> {
    if (providerCurrency === displayCurrency) {
      const identity: FxRate = {
        base: providerCurrency,
        quote: displayCurrency,
        rate: 1,
        source: 'identity',
        rateId: `${providerCurrency}-${displayCurrency}-identity`,
        capturedAt: new Date().toISOString(),
      };
      return {
        providerAmount: amount,
        providerCurrency,
        customerAmount: amount,
        customerCurrency: displayCurrency,
        fx: identity,
      };
    }

    const fx = await this.getRate(providerCurrency, displayCurrency);
    const customerAmount = Math.round(amount * fx.rate * 100) / 100;
    return {
      providerAmount: amount,
      providerCurrency,
      customerAmount,
      customerCurrency: displayCurrency,
      fx,
    };
  }
}
