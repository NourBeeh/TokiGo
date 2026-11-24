/**
 * MarketContext (spec point 3) — the business context object that controls
 * POS/market, display currency, locale, payment region and tax region.
 *
 * Egypt is the first production market: EG / EGP / ar-EG.
 * The market selector changes this context; it must never select a travel
 * provider directly — provider routing consumes it as a separate policy.
 *
 * Display currency is resolved in this order:
 *   1. the traveller's explicit, supported override;
 *   2. the country's ISO-4217 currency (the City Selection's country);
 *   3. USD when the country is unknown.
 * Payment/tax regions still come only from a fully configured market, so a
 * display currency can never silently enable a payment region.
 */

import { currencyForCountry, SUPPORTED_CURRENCIES } from './currency-by-country';

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
 * The display currency when neither a country currency nor an explicit choice
 * is available. Unknown countries fall back to USD; they never inherit EGP.
 */
export const DEFAULT_DISPLAY_CURRENCY = 'USD';

/**
 * Currencies the app can display. A requested currency outside this set is
 * ignored (the market's own currency stands) rather than trusting arbitrary
 * input into the pricing engine.
 *
 * The set is the union of every country currency in the mapping plus the
 * three cross-market majors, so a city in any catalog country can honour its
 * own default currency.
 */
export const SUPPORTED_DISPLAY_CURRENCIES = new Set<string>(SUPPORTED_CURRENCIES);

/**
 * The default display currency for a country, independent of whether the
 * country is a fully configured payment market.
 */
export function displayCurrencyForCountry(
  countryCode?: string | null,
): string {
  return currencyForCountry(countryCode) ?? DEFAULT_DISPLAY_CURRENCY;
}

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
 * its payment region + tax region; every country's display currency comes
 * from the ISO mapping (GB→GBP, FR→EUR, US→USD, …). An unknown country falls
 * back to USD. An explicit, supported `currencyOverride` (the traveller's
 * chosen display currency) wins over both.
 */
export function marketFor(
  countryCode?: string | null,
  currencyOverride?: string | null,
): MarketContextValue {
  const override = normalizeDisplayCurrency(currencyOverride);
  // No country at all keeps the launch-market default (unchanged behaviour).
  if (!countryCode) {
    return override
      ? { ...DEFAULT_MARKET, displayCurrency: override }
      : DEFAULT_MARKET;
  }
  const code = countryCode.toUpperCase();
  const configured = MARKET_CONFIGS[code];
  const base: MarketContextValue = configured ?? {
    ...DEFAULT_MARKET,
    displayCurrency: displayCurrencyForCountry(code),
  };
  return override ? { ...base, displayCurrency: override } : base;
}
