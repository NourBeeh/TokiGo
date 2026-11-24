/**
 * Authoritative ISO-3166-1 alpha-2 → ISO-4217 currency mapping.
 *
 * One table, one owner. The city catalog, the market context and the geo
 * endpoint all read this map so a city can never disagree with its country
 * about which currency is the default.
 *
 * Only currencies with a real ISO-4217 code are listed. A country we do not
 * know returns `null` — the caller must then fall back to the explicit
 * traveller choice or the provider's own currency, never invent one.
 */

const COUNTRY_CURRENCY: Readonly<Record<string, string>> = Object.freeze({
  // Launch + prepared markets
  EG: 'EGP',
  SA: 'SAR',
  AE: 'AED',
  QA: 'QAR',
  KW: 'KWD',
  JO: 'JOD',
  BH: 'BHD',
  OM: 'OMR',
  LB: 'LBP',
  IQ: 'IQD',
  MA: 'MAD',
  TN: 'TND',

  // Europe
  GB: 'GBP',
  FR: 'EUR',
  IT: 'EUR',
  ES: 'EUR',
  DE: 'EUR',
  GR: 'EUR',
  NL: 'EUR',
  PT: 'EUR',
  AT: 'EUR',
  BE: 'EUR',
  IE: 'EUR',
  FI: 'EUR',
  CH: 'CHF',
  SE: 'SEK',
  NO: 'NOK',
  DK: 'DKK',
  PL: 'PLN',
  CZ: 'CZK',
  TR: 'TRY',
  RU: 'RUB',

  // Asia / Pacific
  TH: 'THB',
  SG: 'SGD',
  MY: 'MYR',
  JP: 'JPY',
  CN: 'CNY',
  KR: 'KRW',
  IN: 'INR',
  PK: 'PKR',
  ID: 'IDR',
  PH: 'PHP',
  VN: 'VND',
  HK: 'HKD',
  TW: 'TWD',
  IL: 'ILS',

  // Americas / Africa / Oceania
  US: 'USD',
  CA: 'CAD',
  MX: 'MXN',
  BR: 'BRL',
  AU: 'AUD',
  NZ: 'NZD',
  ZA: 'ZAR',
  KE: 'KES',
  NG: 'NGN',
});

/** Currencies this backend can quote and display. */
export const SUPPORTED_CURRENCIES: ReadonlySet<string> = new Set([
  ...Object.values(COUNTRY_CURRENCY),
  'USD',
  'EUR',
  'GBP',
]);

/**
 * The default currency for a country. Returns `null` for an unknown country or
 * a malformed code — never a guessed currency.
 */
export function currencyForCountry(countryCode?: string | null): string | null {
  const code = countryCode?.trim().toUpperCase();
  if (!code || !/^[A-Z]{2}$/.test(code)) return null;
  return COUNTRY_CURRENCY[code] ?? null;
}

/** Read-only view used by tests and the city catalog. */
export function countryCurrencyMap(): Readonly<Record<string, string>> {
  return COUNTRY_CURRENCY;
}

/** Every currency the mapping can produce, sorted for stable UI lists. */
export function knownCurrencies(): string[] {
  return [...new Set(Object.values(COUNTRY_CURRENCY))].sort();
}
