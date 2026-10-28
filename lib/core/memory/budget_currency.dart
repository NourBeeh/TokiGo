/// Phase 4B — the currencies an explicit budget may be expressed in.
///
/// Mirrors the backend allow-list exactly
/// (`backend/src/modules/memory/budget_currency.ts`) so a budget the app can
/// remember is a budget the app can act on.
///
/// A budget WITHOUT a currency stays valid: the app never converts prices, so
/// such a budget is remembered and shown, but it never filters an offer.
const List<String> supportedBudgetCurrencies = <String>[
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
];

/// Normalizes a currency code to its canonical uppercase form, or null when
/// it is not one of [supportedBudgetCurrencies]. Never throws.
String? normalizeBudgetCurrency(String? raw) {
  if (raw == null) return null;
  final code = raw.trim().toUpperCase();
  if (code.isEmpty) return null;
  return supportedBudgetCurrencies.contains(code) ? code : null;
}
