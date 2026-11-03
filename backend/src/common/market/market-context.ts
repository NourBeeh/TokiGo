/**
 * MarketContext (spec point 3) — the business context object that controls
 * POS/market, display currency, locale, payment region and tax region.
 *
 * Egypt is the first production market: EG / EGP / ar-EG.
 * The market selector changes this context; it must never select a travel
 * provider directly — provider routing consumes it as a separate policy.
 */

export interface MarketContextValue {
  marketCountry: string; // ISO-3166-1 alpha-2
  displayCurrency: string; // ISO-4217
  locale: string; // BCP-47
  paymentRegion: string; // ISO-3166-1 alpha-2
  posCountry: string | null;
  taxRegion: string | null;
  timezone: string;
}

export const MARKET_CONFIGS: Record<string, MarketContextValue> = {
  EG: {
    marketCountry: 'EG',
    displayCurrency: 'EGP',
    locale: 'ar-EG',
    paymentRegion: 'EG',
    posCountry: 'EG',
    taxRegion: 'EG',
    timezone: 'Africa/Cairo',
  },
  // Prepared but NOT enabled (spec point O.13 Phase 10): enable only after
  // written gateway/provider commercial confirmation.
  SA: {
    marketCountry: 'SA',
    displayCurrency: 'SAR',
    locale: 'ar-SA',
    paymentRegion: 'SA',
    posCountry: 'SA',
    taxRegion: 'SA',
    timezone: 'Asia/Riyadh',
  },
  AE: {
    marketCountry: 'AE',
    displayCurrency: 'AED',
    locale: 'ar-AE',
    paymentRegion: 'AE',
    posCountry: 'AE',
    taxRegion: 'AE',
    timezone: 'Asia/Dubai',
  },
};

export const DEFAULT_MARKET: MarketContextValue = MARKET_CONFIGS.EG;

/**
 * The display currency for a country we have no full market config for.
 * Owner decision (2026-11-03): countries outside the configured markets
 * (EG/SA/AE) display in USD instead of silently inheriting EGP.
 */
export const DEFAULT_DISPLAY_CURRENCY = 'USD';

/**
 * Currencies the app can display. A requested currency outside this set is
 * ignored (the market's own currency stands) rather than trusting arbitrary
 * input into the pricing engine.
 */
export const SUPPORTED_DISPLAY_CURRENCIES = new Set([
  'EGP',
  'SAR',
  'AED',
  'USD',
  'EUR',
  'GBP',
]);

/** Normalises + validates a requested display currency (ISO-4217). */
export function normalizeDisplayCurrency(
  currency?: string | null,
): string | null {
  if (!currency) return null;
  const code = currency.trim().toUpperCase();
  return SUPPORTED_DISPLAY_CURRENCIES.has(code) ? code : null;
}

/**
 * Resolves the market context. A country with a full config (EG/SA/AE) keeps
 * its display currency + region; any other country displays in USD while the
 * region defaults stay untouched (display-only — no new payment region is
 * enabled). An explicit, supported `currencyOverride` (the traveller's chosen
 * display currency) wins over both.
 */
export function marketFor(
  countryCode?: string | null,
  currencyOverride?: string | null,
): MarketContextValue {
  const override = normalizeDisplayCurrency(currencyOverride);
  // No country at all keeps the launch-market default (unchanged behaviour);
  // an explicit but unconfigured country displays in USD (owner decision).
  if (!countryCode) {
    return override
      ? { ...DEFAULT_MARKET, displayCurrency: override }
      : DEFAULT_MARKET;
  }
  const configured = MARKET_CONFIGS[countryCode.toUpperCase()];
  const base: MarketContextValue = configured ?? {
    ...DEFAULT_MARKET,
    displayCurrency: DEFAULT_DISPLAY_CURRENCY,
  };
  return override ? { ...base, displayCurrency: override } : base;
}
