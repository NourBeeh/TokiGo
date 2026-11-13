import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/auth/auth_provider.dart';
import 'package:tokigo/core/domain/models/offers/flight_offer.dart';
import 'package:tokigo/core/domain/models/search/flight_search_params.dart';
import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/core/repositories/contracts/flight_repository.dart';
import 'package:tokigo/core/storage/offline_cache.dart';
import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/core/usecases/search_flights_usecase.dart';
import 'package:tokigo/features/home/providers/home_providers.dart';
import 'package:tokigo/features/search/application/controllers/flight_search_controller.dart';
import 'package:tokigo/features/search/application/providers/search_providers.dart';
import 'package:tokigo/features/search/presentation/pages/flight_search_page.dart';
import 'package:tokigo/features/search/presentation/widgets/compact_search_summary.dart';
import 'package:tokigo/features/search/presentation/widgets/flight_search_card.dart';
import 'package:tokigo/features/search/presentation/widgets/search_scaffold.dart';
import 'package:tokigo/l10n/app_localizations.dart';
import 'package:tokigo/shared/providers/locale_provider.dart';

/// The flight search form's compact-after-results behaviour (owner decision,
/// 2026-11).
///
/// * the full form shows initially and while a search is loading;
/// * a successful, non-empty search collapses it into the shared compact
///   summary, with the results still on screen;
/// * tapping the summary reopens the form with every criterion preserved and
///   the results, filters and sorting untouched;
/// * an empty result set does NOT collapse the form.
FlightOffer _offer() => FlightOffer(
      id: 'f1',
      providerId: 'provider',
      providerName: 'Provider',
      title: 'Flight',
      price: 100,
      currency: 'USD',
      origin: 'CAI',
      destination: 'DXB',
      departureTime: DateTime(2026, 1, 1, 10),
      arrivalTime: DateTime(2026, 1, 1, 14),
      airline: 'Emirates',
      flightNumber: 'EK123',
    );

class _FakeFlightRepository implements FlightRepository {
  _FakeFlightRepository(this._offers);

  final List<FlightOffer> _offers;

  @override
  Future<ApiResult<List<FlightOffer>>> search({
    required String origin,
    required String destination,
    required DateTime departure,
    DateTime? returnDate,
    int? passengers,
    int? children,
    int? infants,
    List<int>? childAges,
    List<int>? infantAges,
    List<FlightSearchLeg>? legs,
    String? cabinClass,
    bool? directOnly,
  }) async => ApiResult.success(_offers);

  @override
  Future<ApiResult<FlightOffer>> getById(String id) async =>
      ApiResult.success(_offer());
}

class _ControlledFlightRepository implements FlightRepository {
  _ControlledFlightRepository(this.completer);

  final Completer<List<FlightOffer>> completer;

  @override
  Future<ApiResult<List<FlightOffer>>> search({
    required String origin,
    required String destination,
    required DateTime departure,
    DateTime? returnDate,
    int? passengers,
    int? children,
    int? infants,
    List<int>? childAges,
    List<int>? infantAges,
    List<FlightSearchLeg>? legs,
    String? cabinClass,
    bool? directOnly,
  }) async => ApiResult.success(await completer.future);

  @override
  Future<ApiResult<FlightOffer>> getById(String id) async =>
      ApiResult.success(_offer());
}

Future<GoRouter> _pumpPage(
  WidgetTester tester, {
  List<FlightOffer> offers = const <FlightOffer>[],
  FlightRepository? repository,
}) async {
  tester.view.physicalSize = const Size(800, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final FlightSearchController controller = FlightSearchController(
    SearchFlightsUseCase(
      repository ?? _FakeFlightRepository(offers),
    ),
    MemoryOfflineCache(),
  );

  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      authUserProvider.overrideWith((ref) => null),
      geoCountryProvider.overrideWith((ref) async => null),
      currencyProvider.overrideWith(() => CurrencyController()),
      flightSearchControllerProvider.overrideWith((ref) => controller),
    ],
  );
  addTearDown(container.dispose);

  final GoRouter router = GoRouter(
    initialLocation: '/flights',
    routes: <RouteBase>[
      GoRoute(
        path: '/flights',
        builder: (BuildContext context, GoRouterState state) =>
            const FlightSearchPage(),
      ),
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

/// Fills the route through the pickers and submits the search.
Future<void> _searchCairoToDubai(WidgetTester tester) async {
  await tester.tap(find.byType(SearchFieldInput).at(0));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Cairo International'));
  await tester.pumpAndSettle();

  await tester.tap(find.byType(SearchFieldInput).at(1));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Dubai International'));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Find flights'));
}

void main() {
  testWidgets('a successful search collapses the form into the summary', (
    tester,
  ) async {
    await _pumpPage(tester, offers: <FlightOffer>[_offer()]);

    // Initially the full form is shown.
    expect(
      find.byKey(const ValueKey<String>('flight-search-form')),
      findsOneWidget,
    );
    expect(find.byType(CompactSearchSummary), findsNothing);

    await _searchCairoToDubai(tester);
    await tester.pumpAndSettle();

    // The summary replaces the form; the results are still on screen.
    expect(find.byType(CompactSearchSummary), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('flight-search-form')),
      findsNothing,
    );
    expect(find.text('CAI → DXB'), findsOneWidget);
    expect(find.byType(FlightSearchCard), findsOneWidget);
  });

  testWidgets('tapping the summary reopens the form without losing results', (
    tester,
  ) async {
    await _pumpPage(tester, offers: <FlightOffer>[_offer()]);
    await _searchCairoToDubai(tester);
    await tester.pumpAndSettle();
    expect(find.byType(CompactSearchSummary), findsOneWidget);

    await tester.tap(find.byType(CompactSearchSummary));
    await tester.pumpAndSettle();

    // The full form is back with the criteria preserved.
    expect(
      find.byKey(const ValueKey<String>('flight-search-form')),
      findsOneWidget,
    );
    expect(find.byType(CompactSearchSummary), findsNothing);
    expect(find.text('CAI'), findsNWidgets(2)); // form field + result card
    expect(find.text('DXB'), findsNWidgets(2)); // form field + result card

    // The results, filters and sorting are untouched.
    expect(find.byType(FlightSearchCard), findsOneWidget);
  });

  testWidgets('the form stays visible while the search is loading', (
    tester,
  ) async {
    final Completer<List<FlightOffer>> completer =
        Completer<List<FlightOffer>>();
    await _pumpPage(
      tester,
      repository: _ControlledFlightRepository(completer),
    );

    await _searchCairoToDubai(tester);
    await tester.pump();

    // Loading: the form is still shown, not the summary.
    expect(
      find.byKey(const ValueKey<String>('flight-search-form')),
      findsOneWidget,
    );
    expect(find.byType(CompactSearchSummary), findsNothing);

    // The search succeeds: the summary takes over.
    completer.complete(<FlightOffer>[_offer()]);
    await tester.pumpAndSettle();
    expect(find.byType(CompactSearchSummary), findsOneWidget);
  });

  testWidgets('an empty result set does not collapse the form', (tester) async {
    await _pumpPage(tester, offers: const <FlightOffer>[]);

    await _searchCairoToDubai(tester);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('flight-search-form')),
      findsOneWidget,
    );
    expect(find.byType(CompactSearchSummary), findsNothing);
  });
}
