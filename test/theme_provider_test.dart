import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/storage/offline_cache.dart';
import 'package:tokigo/core/storage/offline_cache_providers.dart';
import 'package:tokigo/shared/providers/theme_provider.dart';

void main() {
  test('a fresh isolated cache defaults to Dark mode', () {
    final container = ProviderContainer(
      overrides: [offlineCacheProvider.overrideWithValue(MemoryOfflineCache())],
    );
    addTearDown(container.dispose);

    expect(container.read(themeModeProvider), ThemeMode.dark);
  });
}
