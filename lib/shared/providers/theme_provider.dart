import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tokigo/core/storage/deferred_offline_cache.dart';
import 'package:tokigo/core/storage/offline_cache_providers.dart';

/// Reactive app-wide theme mode (Dark / Light / System).
///
/// Defaults to System for new installations, so the app follows the device's
/// light/dark appearance. Persisted via the offline cache.
class ThemeModeController extends Notifier<ThemeMode> {
  ThemeModeController({this.initialMode = ThemeMode.system});

  static const String cacheKey = 'settings:themeMode';

  final ThemeMode initialMode;

  static ThemeMode fromStoredValue(Object? value) => switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  @override
  ThemeMode build() {
    _restore();
    return initialMode;
  }

  Future<void> _restore() async {
    try {
      final cache = ref.read(offlineCacheProvider);
      if (cache is DeferredOfflineCache && !cache.isAttached) {
        await cache.ready;
      }
      final stored = await cache.read(cacheKey);
      state = fromStoredValue(stored?['value']);
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
      final String value = switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
      await ref.read(offlineCacheProvider).write(cacheKey, <String, dynamic>{
        'value': value,
      });
    } catch (_) {}
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);
