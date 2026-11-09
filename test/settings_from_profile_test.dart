import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/app/app.dart';
import 'package:tokigo/core/auth/auth_provider.dart';
import 'package:tokigo/features/home/providers/home_providers.dart';
import 'package:tokigo/features/profile/presentation/pages/profile_page.dart';
import 'package:tokigo/features/profile/presentation/pages/settings_page.dart';
import 'package:tokigo/shared/providers/last_route_provider.dart';
import 'package:tokigo/shared/providers/onboarding_provider.dart';
import 'package:tokigo/shared/providers/theme_provider.dart';

void main() {
  testWidgets('open settings from profile', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authUserProvider.overrideWithValue(null),
          geoCountryProvider.overrideWith((ref) async => null),
          lastInitialRouteProvider.overrideWithValue('/profile'),
          onboardingProvider.overrideWith(
            (ref) => OnboardingController.pinned(
              const OnboardingState(seen: true, ready: true),
            ),
          ),
          themeModeProvider.overrideWith(
            () => ThemeModeController(initialMode: ThemeMode.dark),
          ),
        ],
        child: const TokiGoApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.byType(ProfilePage), findsOneWidget);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
  });
}
