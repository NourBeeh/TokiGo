import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';

import 'package:tokigo/features/search/presentation/pages/flight_search_page.dart';
import 'package:tokigo/features/search/presentation/pages/hotel_search_page.dart';
import 'package:tokigo/features/search/presentation/pages/car_search_page.dart';
import 'package:tokigo/features/search/presentation/pages/packages_search_page.dart';
import 'package:tokigo/core/storage/offline_cache.dart';
import 'package:tokigo/core/storage/offline_cache_providers.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Interaction coverage for the rebuilt search pages (Wave 2): forms render,
/// pickers open, no layout errors — pages are mounted through a real
/// GoRouter because they read router state in didChangeDependencies.
void main() {
  setUpAll(() {
    Hive.init(Directory.systemTemp.createTempSync('wt_search_smoke').path);
  });

  Widget wrap(Widget page) {
    final router = GoRouter(
      initialLocation: '/test',
      routes: <RouteBase>[
        GoRoute(path: '/test', builder: (_, __) => page),
      ],
    );
    return ProviderScope(
      overrides: <Override>[
        offlineCacheProvider.overrideWithValue(MemoryOfflineCache()),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    );
  }

  testWidgets('flight search page renders without exceptions', (tester) async {
    await tester.pumpWidget(wrap(const FlightSearchPage()));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.text('Flights'), findsWidgets);
  });

  testWidgets('hotel search page renders without exceptions', (tester) async {
    await tester.pumpWidget(wrap(const HotelSearchPage()));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.text('Hotels'), findsWidgets);
  });

  testWidgets('car search page renders without exceptions', (tester) async {
    await tester.pumpWidget(wrap(const CarSearchPage()));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.text('Cars'), findsWidgets);
  });

  testWidgets('packages search page renders without exceptions', (tester) async {
    await tester.pumpWidget(wrap(const PackagesSearchPage()));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.text('Tour packages'), findsWidgets);
  });

  testWidgets('flight page prefill via router extra works', (tester) async {
    final router = GoRouter(
      initialLocation: '/test',
      routes: <RouteBase>[
        GoRoute(
          path: '/test',
          builder: (_, __) => const FlightSearchPage(),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          offlineCacheProvider.overrideWithValue(MemoryOfflineCache()),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });
}
