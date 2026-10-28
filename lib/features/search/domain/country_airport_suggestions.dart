const Map<String, String> countryAirportSuggestions = <String, String>{
  'EG': 'CAI',
  'AE': 'DXB',
  'SA': 'RUH',
  'GB': 'LHR',
  'FR': 'CDG',
  'TR': 'IST',
  'IT': 'FCO',
  'US': 'JFK',
  'QA': 'DOH',
  'JO': 'AMM',
  'GR': 'ATH',
  'TH': 'BKK',
  'SG': 'SIN',
  'JP': 'HND',
};

/// Curated primary-airport suggestions for country-level origin defaults.
/// These are editable starting points, not nearest-airport claims.
String? suggestedAirportCodeForCountry(String? countryCode) {
  return countryAirportSuggestions[countryCode?.trim().toUpperCase()];
}
