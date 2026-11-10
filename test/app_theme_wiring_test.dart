import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/app/app.dart';
import 'package:tokigo/core/auth/auth_provider.dart';
import 'package:tokigo/core/storage/offline_cache.dart';
import 'package:tokigo/core/storage/offline_cache_providers.dart';
import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/features/home/providers/home_providers.dart';
import 'package:tokigo/features/profile/presentation/pages/settings_page.dart';
import 'package:tokigo/shared/providers/last_route_provider.dart';
import 'package:tokigo/shared/providers/onboarding_provider.dart';
import 'package:tokigo/shared/providers/theme_provider.dart';

/// Task 4A — the REAL TokiGo app wiring (TokiGoApp → themeModeProvider →
/// MaterialApp), not Flutter's generic ThemeMode behavior in isolation.
void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authUserProvider.overrideWithValue(null),
          geoCountryProvider.overrideWith((ref) async => null),
          lastInitialRouteProvider.overrideWithValue('/settings'),
          onboardingProvider.overrideWith(
            (ref) => OnboardingController.pinned(
              const OnboardingState(seen: true, ready: true),
            ),
          ),
          themeModeProvider.overrideWith(
            () => ThemeModeController(initialMode: ThemeMode.system),
          ),
        ],
        child: const TokiGoApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  }

  testWidgets('System mode follows the platform brightness', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await pumpApp(tester);

    final BuildContext context = tester.element(find.byType(SettingsPage));
    expect(Theme.of(context).brightness, Brightness.dark);
    // The TokiGo dark palette is the one actually active.
    expect(context.tokigoColors.background, TokiGoColors.dark().background);
  });

  testWidgets('System mode follows a light platform back', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await pumpApp(tester);

    final BuildContext context = tester.element(find.byType(SettingsPage));
    expect(Theme.of(context).brightness, Brightness.light);
    expect(context.tokigoColors.background, TokiGoColors.light().background);
  });

  testWidgets('a manual Light selection overrides the platform', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    // The selection is persisted, exactly as a real user's choice would be.
    final cache = MemoryOfflineCache();
    await cache.write(ThemeModeController.cacheKey, <String, dynamic>{
      'value': 'light',
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authUserProvider.overrideWithValue(null),
          geoCountryProvider.overrideWith((ref) async => null),
          lastInitialRouteProvider.overrideWithValue('/settings'),
          onboardingProvider.overrideWith(
            (ref) => OnboardingController.pinned(
              const OnboardingState(seen: true, ready: true),
            ),
          ),
          offlineCacheProvider.overrideWithValue(cache),
          themeModeProvider.overrideWith(
            () => ThemeModeController(initialMode: ThemeMode.light),
          ),
        ],
        child: const TokiGoApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    final BuildContext context = tester.element(find.byType(SettingsPage));
    expect(Theme.of(context).brightness, Brightness.light);
  });
}
