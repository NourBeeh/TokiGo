import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/auth/auth_provider.dart';
import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/features/home/providers/home_providers.dart';
import 'package:tokigo/features/search/presentation/pages/flight_search_page.dart';
import 'package:tokigo/features/search/presentation/pages/hotel_search_page.dart';
import 'package:tokigo/features/search/presentation/widgets/search_scaffold.dart';
import 'package:tokigo/l10n/app_localizations.dart';
import 'package:tokigo/shared/providers/locale_provider.dart';

/// Pumps a search page on a small phone (360x640 logical) with the providers
/// the pages read, and returns the router.
Future<GoRouter> pumpPage(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(720, 1280);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      authUserProvider.overrideWith((ref) => null),
      geoCountryProvider.overrideWith((ref) async => null),
      currencyProvider.overrideWith(() => CurrencyController()),
    ],
  );
  addTearDown(container.dispose);

  final GoRouter router = GoRouter(
    initialLocation: '/search',
    routes: <RouteBase>[
      GoRoute(path: '/search', builder: (context, state) => page),
    ],
  );

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.light(),
        locale: const Locale('en'),
        supportedLocales: const <Locale>[Locale('en')],
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('the flight search form is compact on a small screen', (
    tester,
  ) async {
    await pumpPage(tester, const FlightSearchPage());

    final double height = tester
        .getSize(find.byKey(const ValueKey<String>('flight-search-form')))
        .height;

    // Four grouped rows plus the submit action stay well inside one screen,
    // leaving the results visible without scrolling the form away.
    expect(height, lessThanOrEqualTo(320));
  });

  testWidgets('the hotel search form is compact on a small screen', (
    tester,
  ) async {
    await pumpPage(tester, const HotelSearchPage());

    final double height = tester
        .getSize(find.byKey(const ValueKey<String>('hotel-search-form')))
        .height;

    expect(height, lessThanOrEqualTo(360));
  });

  testWidgets('neither form overflows on a narrow screen', (tester) async {
    await pumpPage(tester, const FlightSearchPage());
    expect(tester.takeException(), isNull);

    await pumpPage(tester, const HotelSearchPage());
    expect(tester.takeException(), isNull);
  });

  testWidgets('both forms keep their submit action reachable', (tester) async {
    await pumpPage(tester, const FlightSearchPage());
    expect(find.byType(SearchSubmitButton), findsOneWidget);

    await pumpPage(tester, const HotelSearchPage());
    expect(find.byType(SearchSubmitButton), findsOneWidget);
  });
}
