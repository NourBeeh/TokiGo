/**
 * The currencies an explicit budget may be expressed in (Phase 4B).
 *
 * A budget WITHOUT a currency stays valid (legacy memories): the app never
 * converts prices silently, so a currency-less budget simply cannot filter
 * anything — it is remembered and shown, never applied.
 *
 * The list is deliberately short: the currencies the app can price an offer
 * in today (provider currency + the traveller's own market currency).
 */
export const SUPPORTED_BUDGET_CURRENCIES = [
  'USD',
  'EGP',
  'SAR',
  'AED',
  'QAR',
  'KWD',
  'BHD',
  'OMR',
  'JOD',
  'MAD',
  'TND',
  'DZD',
  'EUR',
  'GBP',
  'TRY',
  'CHF',
  'JPY',
] as const;

export type BudgetCurrency = (typeof SUPPORTED_BUDGET_CURRENCIES)[number];

/**
 * Normalizes a currency code to its canonical uppercase form, or null when
 * it is not a supported currency. Never throws.
 */
export function normalizeBudgetCurrency(raw: unknown): string | null {
  if (typeof raw !== 'string') return null;
  const code = raw.trim().toUpperCase();
  if (code.length === 0) return null;
  return (SUPPORTED_BUDGET_CURRENCIES as readonly string[]).includes(code)
    ? code
    : null;
}
