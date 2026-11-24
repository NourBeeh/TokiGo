/// Display-currency helpers shared by Settings and the price surfaces.
///
/// The backend converts every price into the traveller's display currency and
/// resolves the default from the selected city's country (GB→GBP, FR→EUR,
/// EG→EGP, US→USD, …). These constants mirror that rule for choosing which
/// currency is "current" — the conversion itself is ALWAYS the backend's (the
/// app never converts).
///
/// [displayCurrencies] lists the currencies the picker offers; the backend's
/// `SUPPORTED_DISPLAY_CURRENCIES` set is the source of truth and must stay in
/// sync with it.
const List<String> displayCurrencies = <String>[
  'AED',
  'AUD',
  'BRL',
  'CAD',
  'CHF',
  'CNY',
  'CZK',
  'DKK',
  'EGP',
  'EUR',
  'GBP',
  'HKD',
  'IDR',
  'ILS',
  'INR',
  'JOD',
  'JPY',
  'KES',
  'KRW',
  'KWD',
  'LBP',
  'MAD',
  'MXN',
  'MYR',
  'NGN',
  'NOK',
  'NZD',
  'OMR',
  'PHP',
  'PKR',
  'PLN',
  'QAR',
  'RUB',
  'SAR',
  'SEK',
  'SGD',
  'THB',
  'TRY',
  'TWD',
  'USD',
  'VND',
  'ZAR',
];

/// ISO-3166-1 alpha-2 → ISO-4217. Mirrors
/// `backend/src/common/market/currency-by-country.ts`.
const Map<String, String> _countryCurrency = <String, String>{
  'EG': 'EGP',
  'SA': 'SAR',
  'AE': 'AED',
  'QA': 'QAR',
  'KW': 'KWD',
  'JO': 'JOD',
  'BH': 'BHD',
  'OM': 'OMR',
  'LB': 'LBP',
  'IQ': 'IQD',
  'MA': 'MAD',
  'TN': 'TND',
  'GB': 'GBP',
  'FR': 'EUR',
  'IT': 'EUR',
  'ES': 'EUR',
  'DE': 'EUR',
  'GR': 'EUR',
  'NL': 'EUR',
  'PT': 'EUR',
  'AT': 'EUR',
  'BE': 'EUR',
  'IE': 'EUR',
  'FI': 'EUR',
  'CH': 'CHF',
  'SE': 'SEK',
  'NO': 'NOK',
  'DK': 'DKK',
  'PL': 'PLN',
  'CZ': 'CZK',
  'TR': 'TRY',
  'RU': 'RUB',
  'TH': 'THB',
  'SG': 'SGD',
  'MY': 'MYR',
  'JP': 'JPY',
  'CN': 'CNY',
  'KR': 'KRW',
  'IN': 'INR',
  'PK': 'PKR',
  'ID': 'IDR',
  'PH': 'PHP',
  'VN': 'VND',
  'HK': 'HKD',
  'TW': 'TWD',
  'IL': 'ILS',
  'US': 'USD',
  'CA': 'CAD',
  'MX': 'MXN',
  'BR': 'BRL',
  'AU': 'AUD',
  'NZ': 'NZD',
  'ZA': 'ZAR',
  'KE': 'KES',
  'NG': 'NGN',
};

/// The ISO-4217 currency for a country, or null when the country is unknown.
String? currencyForCountry(String? countryCode) {
  final code = countryCode?.trim().toUpperCase();
  if (code == null || code.length != 2) return null;
  return _countryCurrency[code];
}

/// The currency shown when the traveller has made no explicit choice: the
/// country's own currency, else USD.
String autoCurrencyFor(String? countryCode) =>
    currencyForCountry(countryCode) ?? 'USD';

/// The effective display currency.
///
/// Order: explicit [chosen] → the selected city's [cityCurrency] → the
/// [countryCode]'s ISO currency → USD. Only currencies the backend supports
/// are ever returned, so a malformed stored value cannot leak into a request.
String effectiveCurrency({
  String? chosen,
  String? countryCode,
  String? cityCurrency,
}) {
  final normalizedChosen = chosen?.trim().toUpperCase();
  if (normalizedChosen != null &&
      normalizedChosen.isNotEmpty &&
      displayCurrencies.contains(normalizedChosen)) {
    return normalizedChosen;
  }
  final normalizedCity = cityCurrency?.trim().toUpperCase();
  if (normalizedCity != null &&
      normalizedCity.isNotEmpty &&
      displayCurrencies.contains(normalizedCity)) {
    return normalizedCity;
  }
  return autoCurrencyFor(countryCode);
}
