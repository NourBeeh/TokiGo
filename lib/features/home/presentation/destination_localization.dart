import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/l10n/app_localizations.dart';

enum DestinationTextField { title, subtitle, description, region }

String localizedDestinationText(
  HomeItem item,
  DestinationTextField field, {
  AppLocalizations? l10n,
  String languageCode = 'en',
}) {
  final String source = switch (field) {
    DestinationTextField.title => item.title,
    DestinationTextField.subtitle => item.subtitle ?? '',
    DestinationTextField.description => item.description ?? '',
    DestinationTextField.region =>
      (item.metadata['region'] ?? item.metadata['country'] ?? '').toString(),
  };
  final bool isArabic = l10n?.localeName == 'ar' || languageCode == 'ar';
  if (source.trim().isEmpty || !isArabic) {
    return source;
  }

  final String? authoredTranslation = _authoredArabicValue(item, field);
  if (authoredTranslation != null) return authoredTranslation;

  final String normalized = _normalize(source).replaceAll(' ', '_');
  final String? translated = switch (field) {
    DestinationTextField.title => l10n?.destinationCityName(normalized),
    DestinationTextField.region => l10n?.destinationRegionName(normalized),
    DestinationTextField.subtitle || DestinationTextField.description => null,
  };
  return translated == null || translated == normalized ? source : translated;
}

String? _authoredArabicValue(HomeItem item, DestinationTextField field) {
  final String fieldName = switch (field) {
    DestinationTextField.title => 'title',
    DestinationTextField.subtitle => 'subtitle',
    DestinationTextField.description => 'description',
    DestinationTextField.region => 'region',
  };
  final List<String> keys = <String>[
    '${fieldName}Ar',
    '${fieldName}_ar',
    'arabic${fieldName[0].toUpperCase()}${fieldName.substring(1)}',
    if (field == DestinationTextField.title) ...<String>[
      'nameAr',
      'name_ar',
      'arabicName',
    ],
  ];

  final Object? translations =
      item.metadata['translations'] ?? item.metadata['localized'];
  if (translations is Map<Object?, Object?>) {
    final Object? arabic = translations['ar'];
    if (arabic is Map<Object?, Object?>) {
      final String? value = _firstText(arabic, <String>[fieldName, ...keys]);
      if (value != null) return value;
    }
  }

  return _firstText(item.metadata, keys);
}

String? _firstText(Map<Object?, Object?> values, List<String> keys) {
  for (final String key in keys) {
    final Object? value = values[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}

String _normalize(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[_-]+'), ' ')
    .replaceAll('á', 'a')
    .replaceAll('à', 'a')
    .replaceAll('ä', 'a')
    .replaceAll('â', 'a')
    .replaceAll('ã', 'a')
    .replaceAll('é', 'e')
    .replaceAll('è', 'e')
    .replaceAll('ë', 'e')
    .replaceAll('ê', 'e')
    .replaceAll('í', 'i')
    .replaceAll('ì', 'i')
    .replaceAll('ï', 'i')
    .replaceAll('î', 'i')
    .replaceAll('ó', 'o')
    .replaceAll('ò', 'o')
    .replaceAll('ö', 'o')
    .replaceAll('ô', 'o')
    .replaceAll('õ', 'o')
    .replaceAll('ú', 'u')
    .replaceAll('ù', 'u')
    .replaceAll('ü', 'u')
    .replaceAll('û', 'u')
    .replaceAll('ñ', 'n')
    .replaceAll('ç', 'c');
