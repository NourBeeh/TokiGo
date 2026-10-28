import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tokigo/core/storage/deferred_offline_cache.dart';
import 'package:tokigo/core/storage/offline_cache_providers.dart';
import 'package:tokigo/core/theme/app_typography.dart';

/// Reactive app-wide locale (English / Arabic).
///
/// Defaults to the platform locale when it is supported, otherwise English.
/// Persistence of the choice lands with the settings storage phase.
///
/// **The type system follows the CHOSEN locale** (bug found 2026-10-19): the
/// Arabic family used to be applied only from the platform locale captured when
/// this provider was first read, so a user on an English device who switched
/// the app to Arabic in Settings kept Manrope as the primary family and kept
/// Latin letter tracking on Arabic text. Every change now goes through
/// [LocaleController.setLocale], the ONE place that writes the locale and
/// `AppTypography.isArabicLocale` together.
class LocaleController extends Notifier<Locale> {
  static const List<String> _supported = <String>['en', 'ar'];

  /// Where the chosen language is stored — the app's own cache (Hive on the
  /// device). The choice must survive a restart, or every launch would drop
  /// the traveller back to the device language.
  static const String cacheKey = 'settings:locale';

  @override
  Locale build() {
    final code = PlatformDispatcher.instance.locale.languageCode;
    final resolved = Locale(_supported.contains(code) ? code : 'en');
    _applyToTypography(resolved);
    _restore();
    return resolved;
  }

  /// Restores the saved language (the platform locale is only the default).
  Future<void> _restore() async {
    try {
      final cache = ref.read(offlineCacheProvider);
      // The disk cache may still be opening (see `main.dart`): read after it
      // attaches so a slow launch restores the chosen language instead of
      // silently dropping it back to the device locale.
      if (cache is DeferredOfflineCache && !cache.isAttached) {
        await cache.ready;
      }
      final stored = await cache.read(cacheKey);
      final String? saved = stored?['value'] as String?;
      if (saved != null && _supported.contains(saved)) {
        _applyToTypography(Locale(saved));
        state = Locale(saved);
      }
    } catch (_) {
      // Storage unavailable (tests, a very early launch): the platform locale
      // stays. Never block the app on a preference.
    }
  }

  /// Switches the app language (Settings) and re-syncs the type system.
  Future<void> setLocale(Locale locale) async {
    _applyToTypography(locale);
    if (locale != state) state = locale;
    try {
      await ref.read(offlineCacheProvider).write(cacheKey, <String, dynamic>{
        'value': locale.languageCode,
      });
    } catch (_) {}
  }

  void _applyToTypography(Locale locale) =>
      AppTypography.isArabicLocale = locale.languageCode == 'ar';
}

final localeProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);

/// Reactive display-currency preference (ISO code).
final currencyProvider = StateProvider<String>((ref) => 'USD');
