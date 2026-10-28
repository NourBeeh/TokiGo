import 'package:flutter/widgets.dart';

import 'package:tokigo/features/search/domain/country_airport_suggestions.dart';

class CountryOption {
  const CountryOption({
    required this.code,
    required this.airportCode,
    required this.englishName,
    required this.arabicName,
  });

  final String code;
  final String airportCode;
  final String englishName;
  final String arabicName;

  String localizedName(Locale locale) =>
      locale.languageCode == 'ar' ? arabicName : englishName;
}

const List<CountryOption> manualCountryOptions = <CountryOption>[
  CountryOption(
    code: 'EG',
    airportCode: 'CAI',
    englishName: 'Egypt',
    arabicName: 'مصر',
  ),
  CountryOption(
    code: 'AE',
    airportCode: 'DXB',
    englishName: 'United Arab Emirates',
    arabicName: 'الإمارات العربية المتحدة',
  ),
  CountryOption(
    code: 'SA',
    airportCode: 'RUH',
    englishName: 'Saudi Arabia',
    arabicName: 'السعودية',
  ),
  CountryOption(
    code: 'GB',
    airportCode: 'LHR',
    englishName: 'United Kingdom',
    arabicName: 'المملكة المتحدة',
  ),
  CountryOption(
    code: 'FR',
    airportCode: 'CDG',
    englishName: 'France',
    arabicName: 'فرنسا',
  ),
  CountryOption(
    code: 'TR',
    airportCode: 'IST',
    englishName: 'Türkiye',
    arabicName: 'تركيا',
  ),
  CountryOption(
    code: 'IT',
    airportCode: 'FCO',
    englishName: 'Italy',
    arabicName: 'إيطاليا',
  ),
  CountryOption(
    code: 'US',
    airportCode: 'JFK',
    englishName: 'United States',
    arabicName: 'الولايات المتحدة',
  ),
  CountryOption(
    code: 'QA',
    airportCode: 'DOH',
    englishName: 'Qatar',
    arabicName: 'قطر',
  ),
  CountryOption(
    code: 'JO',
    airportCode: 'AMM',
    englishName: 'Jordan',
    arabicName: 'الأردن',
  ),
  CountryOption(
    code: 'GR',
    airportCode: 'ATH',
    englishName: 'Greece',
    arabicName: 'اليونان',
  ),
  CountryOption(
    code: 'TH',
    airportCode: 'BKK',
    englishName: 'Thailand',
    arabicName: 'تايلاند',
  ),
  CountryOption(
    code: 'SG',
    airportCode: 'SIN',
    englishName: 'Singapore',
    arabicName: 'سنغافورة',
  ),
  CountryOption(
    code: 'JP',
    airportCode: 'HND',
    englishName: 'Japan',
    arabicName: 'اليابان',
  ),
];

String? countryNameForCode(String? code, Locale locale) {
  if (code == null) return null;
  for (final option in manualCountryOptions) {
    if (option.code == code.toUpperCase()) {
      return option.localizedName(locale);
    }
  }
  return null;
}

bool isManualCountryCode(String code) =>
    countryAirportSuggestions.containsKey(code.trim().toUpperCase());
