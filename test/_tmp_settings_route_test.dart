import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/app/app.dart';
import 'package:tokigo/core/auth/auth_provider.dart';
import 'package:tokigo/features/home/providers/home_providers.dart';
import 'package:tokigo/features/profile/presentation/pages/settings_page.dart';
import 'package:tokigo/shared/providers/last_route_provider.dart';
import 'package:tokigo/shared/providers/onboarding_provider.dart';
import 'package:tokigo/shared/providers/theme_provider.dart';

void main() {
  testWidgets('settings route screenshot', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const key = ValueKey<String>('capture');
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProviderScope(
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
              () => ThemeModeController(initialMode: ThemeMode.dark),
            ),
          ],
          child: const TokiGoApp(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    // ignore: avoid_print
    print('settings: ${find.byType(SettingsPage).evaluate().length}');
    expect(find.byType(SettingsPage), findsOneWidget);

    final RenderRepaintBoundary boundary =
        tester.renderObject<RenderRepaintBoundary>(find.byKey(key));

    // `toImage`/`toByteData` complete on the real event loop. Inside the
    // fake-async test zone their continuations are never flushed, so the
    // capture must run through `runAsync` — the same mechanism
    // `matchesGoldenFile` uses.
    final Uint8List? png = await tester.binding.runAsync<Uint8List>(() async {
      final ui.Image image = await boundary.toImage(pixelRatio: 1);
      final ByteData data = (await image.toByteData(
        format: ui.ImageByteFormat.png,
      ))!;
      return data.buffer.asUint8List();
    });

    expect(png, isNotNull);
    expect(png!.isNotEmpty, isTrue);

    final File file = File(
      r'C:\Users\mnour\AppData\Local\Temp\opencode\settings_dark.png',
    );
    file.writeAsBytesSync(png);
    expect(file.existsSync(), isTrue);
    expect(file.lengthSync(), greaterThan(0));
  });
}
