import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/storage/offline_cache.dart';
import 'package:tokigo/core/storage/offline_cache_providers.dart';
import 'package:tokigo/shared/providers/theme_provider.dart';

/// Waits until the async restore in [ThemeModeController.build] has applied.
Future<void> _untilRestored(ProviderContainer container, ThemeMode expected) async {
  for (int i = 0; i < 50; i++) {
    if (container.read(themeModeProvider) == expected) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  test('a fresh isolated cache defaults to System mode', () {
    final container = ProviderContainer(
      overrides: [offlineCacheProvider.overrideWithValue(MemoryOfflineCache())],
    );
    addTearDown(container.dispose);

    expect(container.read(themeModeProvider), ThemeMode.system);
  });

  test('a missing or unknown stored value falls back to System', () {
    expect(ThemeModeController.fromStoredValue(null), ThemeMode.system);
    expect(ThemeModeController.fromStoredValue('nonsense'), ThemeMode.system);
    expect(ThemeModeController.fromStoredValue('light'), ThemeMode.light);
    expect(ThemeModeController.fromStoredValue('dark'), ThemeMode.dark);
    expect(ThemeModeController.fromStoredValue('system'), ThemeMode.system);
  });

  test('a selection persists and is restored by a fresh container', () async {
    final cache = MemoryOfflineCache();
    final container = ProviderContainer(
      overrides: [offlineCacheProvider.overrideWithValue(cache)],
    );
    addTearDown(container.dispose);

    await container
        .read(themeModeProvider.notifier)
        .setThemeMode(ThemeMode.dark);
    // The selection is written to the cache (the provider's own restore may
    // still be in flight, so the cache is the persistence authority here).
    expect(await cache.read(ThemeModeController.cacheKey), <String, dynamic>{
      'value': 'dark',
    });

    // A fresh container over the same cache restores the stored selection.
    final restored = ProviderContainer(
      overrides: [offlineCacheProvider.overrideWithValue(cache)],
    );
    addTearDown(restored.dispose);
    await _untilRestored(restored, ThemeMode.dark);
    expect(restored.read(themeModeProvider), ThemeMode.dark);
  });

  testWidgets('System mode follows the platform brightness', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        themeMode: ThemeMode.system,
        home: Builder(
          builder: (BuildContext context) => Text(
            Theme.of(context).brightness == Brightness.dark ? 'dark' : 'light',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('dark'), findsOneWidget);
  });
}
