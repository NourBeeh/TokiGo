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

export function marketFor(countryCode?: string | null): MarketContextValue {
  if (!countryCode) return DEFAULT_MARKET;
  return MARKET_CONFIGS[countryCode.toUpperCase()] ?? DEFAULT_MARKET;
}
