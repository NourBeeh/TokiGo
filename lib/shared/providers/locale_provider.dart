import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tokigo/core/theme/app_typography.dart';

/// Reactive app-wide locale (English / Arabic).
///
/// Defaults to the platform locale when it is supported, otherwise English.
/// Persistence of the choice lands with the settings storage phase.
final localeProvider = StateProvider<Locale>((ref) {
  final platform = PlatformDispatcher.instance.locale;
  final supported = <String>['en', 'ar'];
  final code = platform.languageCode;
  final resolved = supported.contains(code) ? code : 'en';
  // Keep the type system in sync: Arabic sessions render with Cairo.
  AppTypography.isArabicLocale = resolved == 'ar';
  return Locale(resolved);
});

/// Reactive display-currency preference (ISO code).
final currencyProvider = StateProvider<String>((ref) => 'USD');
