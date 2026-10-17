import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';

import 'package:tokigo/app/app.dart';
import 'package:tokigo/core/storage/offline_cache.dart';
import 'package:tokigo/core/storage/offline_cache_providers.dart';
import 'package:tokigo/app/widgets/app_bottom_nav.dart';
import 'package:tokigo/app/widgets/home_nav_buttons.dart';

void main() {
  setUpAll(() {
    // The onboarding controller opens a Hive settings box on boot.
    Hive.init(Directory.systemTemp.createTempSync('wt_app_smoke').path);
  });

  testWidgets('full app boots and navigates without exceptions (NAV: no bottom bar)',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          offlineCacheProvider.overrideWithValue(MemoryOfflineCache()),
        ],
        child: const TokiGoApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    // NAV: the floating bottom navigation pill is GONE — Home-centric.
    expect(find.byType(AppBottomNav), findsNothing);

    // Home renders its welcome line AND the Home-centric nav buttons.
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.byType(HomeNavButtons), findsOneWidget);

    // Navigate through the Home nav buttons — looking for runtime exceptions
    // (each vertical is a pushed route on the Home branch now).
    final router = GoRouter.of(tester.element(find.byType(HomeNavButtons)));

    Future<void> visit(String label) async {
      await tester.tap(find.text(label));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      // Back to Home (full-screen pages use their own headers — no system
      // back button in the widget tree, so route back explicitly).
      router.go('/');
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
    }

    await visit('Flights');
    await visit('Explore');
    await visit('Groups');
  });
}
