/// Display-currency helpers shared by Settings and the price surfaces.
///
/// The backend converts every price into the traveller's display currency and,
/// for countries outside the configured markets (EG/SA/AE), defaults to USD.
/// These constants mirror that rule for choosing which currency is "current" —
/// the conversion itself is ALWAYS the backend's (the app never converts).
///
/// [displayCurrencies] lists the currencies the picker offers; the backend's
/// `SUPPORTED_DISPLAY_CURRENCIES` set is the source of truth and must stay in
/// sync with it.
const List<String> displayCurrencies = <String>[
  'USD',
  'EUR',
  'GBP',
  'EGP',
  'SAR',
  'AED',
];

/// Country → currency for the markets the backend configures explicitly.
const Map<String, String> _marketCurrency = <String, String>{
  'EG': 'EGP',
  'SA': 'SAR',
  'AE': 'AED',
};

/// The currency shown when the traveller has made no explicit choice: the
/// market's own currency, else USD (the backend default for other countries).
String autoCurrencyFor(String? countryCode) =>
    _marketCurrency[countryCode?.trim().toUpperCase()] ?? 'USD';

/// The effective display currency: the explicit [chosen] code, else the auto
/// default for [countryCode].
String effectiveCurrency({String? chosen, String? countryCode}) {
  final normalized = chosen?.trim().toUpperCase();
  if (normalized != null &&
      normalized.isNotEmpty &&
      displayCurrencies.contains(normalized)) {
    return normalized;
  }
  return autoCurrencyFor(countryCode);
}
