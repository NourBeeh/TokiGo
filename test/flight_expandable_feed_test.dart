import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/auth/auth_provider.dart';
import 'package:tokigo/core/domain/models/offers/flight_offer.dart';
import 'package:tokigo/core/domain/models/search/flight_search_params.dart';
import 'package:tokigo/core/network/api_error.dart';
import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/core/repositories/contracts/flight_repository.dart';
import 'package:tokigo/core/storage/offline_cache.dart';
import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/core/usecases/search_flights_usecase.dart';
import 'package:tokigo/features/home/providers/home_providers.dart';
import 'package:tokigo/features/search/application/controllers/flight_search_controller.dart';
import 'package:tokigo/features/search/application/providers/search_providers.dart';
import 'package:tokigo/features/search/presentation/pages/flight_search_page.dart';
import 'package:tokigo/features/search/presentation/widgets/flight_search_card.dart';
import 'package:tokigo/features/search/presentation/widgets/search_scaffold.dart';
import 'package:tokigo/l10n/app_localizations.dart';
import 'package:tokigo/shared/providers/locale_provider.dart';

/// Flight Search Results as an EXPANDABLE VERTICAL FEED (Phase 2).
///
/// The card's own drawing is pinned by `flight_card_ui_test.dart`, the
/// compact-summary behaviour by `flight_compact_summary_test.dart`, and the
/// passenger party by the passenger suites. What is pinned here is the
/// expansion contract: collapsed by default, one card open at a time, inline
/// reveal with no navigation, real provider data only, and an intact
/// details hand-off.
FlightOffer _offer(
  String id, {
  String airline = 'Emirates',
  String flightNumber = 'EK123',
  double price = 100,
  String origin = 'CAI',
  String destination = 'DXB',
  DateTime? departure,
  DateTime? arrival,
  int? stops,
  String? cabinClass,
  Map<String, dynamic>? metadata,
}) => FlightOffer(
      id: id,
      providerId: 'provider',
      providerName: 'Provider',
      title: 'Flight',
      price: price,
      currency: 'USD',
      origin: origin,
      destination: destination,
      departureTime: departure ?? DateTime(2026, 1, 1, 10),
      arrivalTime: arrival ?? DateTime(2026, 1, 1, 14),
      airline: airline,
      flightNumber: flightNumber,
      stops: stops,
      cabinClass: cabinClass,
      metadata: metadata ?? const <String, dynamic>{},
    );

class _FakeFlightRepository implements FlightRepository {
  _FakeFlightRepository(this.offers, {this.failures = 0});

  final List<FlightOffer> offers;
  int failures;
  int calls = 0;

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
  }) async {
    calls++;
    if (failures > 0) {
      failures--;
      return const ApiResult.failure(ApiNetworkError(message: 'offline'));
    }
    return ApiResult.success(offers);
  }

  @override
  Future<ApiResult<FlightOffer>> getById(String id) async =>
      ApiResult.success(offers.first);
}

Future<GoRouter> _pump(
  WidgetTester tester, {
  List<FlightOffer> offers = const <FlightOffer>[],
  FlightRepository? repository,
  TextDirection direction = TextDirection.ltr,
  Size size = const Size(800, 3200),
  double pixelRatio = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = pixelRatio;
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
      GoRoute(
        path: '/offer-details',
        builder: (BuildContext context, GoRouterState state) {
          final FlightOffer? offer = state.extra as FlightOffer?;
          return Scaffold(body: Text('OFFER ${offer?.id ?? ''}'));
        },
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
        builder: (BuildContext context, Widget? child) =>
            Directionality(textDirection: direction, child: child!),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

/// Cairo → Dubai on the default date, then "Find flights".
Future<void> _search(WidgetTester tester) async {
  await tester.tap(find.byType(SearchFieldInput).at(0));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Cairo International'));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(SearchFieldInput).at(1));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Dubai International'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Find flights'));
  await tester.pumpAndSettle();
}

/// The panel's own title — the clearest single signal that a card is open.
Finder _panel() => find.text('Flight details');

void main() {
  testWidgets('every card starts collapsed', (WidgetTester tester) async {
    await _pump(
      tester,
      offers: <FlightOffer>[_offer('f1'), _offer('f2')],
    );
    await _search(tester);

    expect(find.byType(FlightSearchCard), findsNWidgets(2));
    expect(_panel(), findsNothing);
    expect(find.text('Airline'), findsNothing);
    expect(find.text('Flight number'), findsNothing);
    // The collapsed cards still carry the expand affordance.
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a card expands it inline, without navigating', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      offers: <FlightOffer>[_offer('f1'), _offer('f2')],
    );
    await _search(tester);

    await tester.tap(find.byType(FlightSearchCard).first);
    await tester.pumpAndSettle();

    expect(_panel(), findsOneWidget);
    expect(find.text('Airline'), findsOneWidget);
    expect(find.text('Flight number'), findsOneWidget);
    expect(find.text('Departure'), findsOneWidget);
    expect(find.text('Arrival'), findsOneWidget);
    expect(find.text('Duration'), findsOneWidget);
    expect(find.text('Stops'), findsOneWidget);
    expect(find.text('View offer and book'), findsOneWidget);
    // Still on the results page: no route was pushed.
    expect(find.text('OFFER f1'), findsNothing);
    expect(find.byType(FlightSearchCard), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping the open card again collapses it', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      offers: <FlightOffer>[_offer('f1'), _offer('f2')],
    );
    await _search(tester);

    await tester.tap(find.byType(FlightSearchCard).first);
    await tester.pumpAndSettle();
    expect(_panel(), findsOneWidget);

    await tester.tap(find.byType(FlightSearchCard).first);
    await tester.pumpAndSettle();
    expect(_panel(), findsNothing);
    expect(find.text('Airline'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the open card offers an explicit way to collapse', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      offers: <FlightOffer>[_offer('f1')],
    );
    await _search(tester);

    await tester.tap(find.byType(FlightSearchCard).first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hide details'));
    await tester.pumpAndSettle();
    expect(_panel(), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping another card moves the expansion, leaving one open', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      offers: <FlightOffer>[_offer('f1'), _offer('f2')],
    );
    await _search(tester);

    await tester.tap(find.byType(FlightSearchCard).first);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(FlightSearchCard).first,
        matching: _panel(),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byType(FlightSearchCard).at(1));
    await tester.pumpAndSettle();

    expect(_panel(), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(FlightSearchCard).first,
        matching: _panel(),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(FlightSearchCard).at(1),
        matching: _panel(),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('expanding does not move the tapped card', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      offers: <FlightOffer>[_offer('f1'), _offer('f2')],
    );
    await _search(tester);

    final double firstBefore = tester.getTopLeft(
      find.byType(FlightSearchCard).first,
    ).dy;
    final double secondBefore = tester.getTopLeft(
      find.byType(FlightSearchCard).at(1),
    ).dy;

    await tester.tap(find.byType(FlightSearchCard).first);
    await tester.pumpAndSettle();

    // The card the traveller tapped stays put; the card below is pushed down.
    expect(
      tester.getTopLeft(find.byType(FlightSearchCard).first).dy,
      firstBefore,
    );
    expect(
      tester.getTopLeft(find.byType(FlightSearchCard).at(1)).dy,
      greaterThan(secondBefore),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a long result list (lazy slivers) expands inline too', (
    WidgetTester tester,
  ) async {
    final List<FlightOffer> many = <FlightOffer>[
      for (int i = 0; i < 13; i++) _offer('f$i', airline: 'Air $i'),
    ];
    await _pump(tester, offers: many, size: const Size(800, 6000));
    await _search(tester);

    expect(find.byType(FlightSearchCard), findsWidgets);
    await tester.tap(find.byType(FlightSearchCard).first);
    await tester.pumpAndSettle();

    expect(_panel(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the expanded panel shows the facts the provider sent', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      offers: <FlightOffer>[
        _offer(
          'f1',
          cabinClass: 'Business',
          stops: 1,
          metadata: <String, dynamic>{
            'layoverDuration': '2h 30m',
            'aircraft': 'A350',
            'fareFamily': 'Flex',
            'refundable': true,
            'baggage': <String, dynamic>{'quantity': 2, 'type': 'checked'},
          },
        ),
      ],
    );
    await _search(tester);

    await tester.tap(find.byType(FlightSearchCard).first);
    await tester.pumpAndSettle();

    expect(find.text('Layover'), findsOneWidget);
    expect(find.text('2h 30m'), findsOneWidget);
    expect(find.text('Cabin'), findsOneWidget);
    // The collapsed card already shows the cabin as a feature chip.
    expect(find.text('Business'), findsNWidgets(2));
    expect(find.text('Baggage'), findsOneWidget);
    // Typed fare facts format the provider's 2 checked bags; the collapsed
    // card's feature chip states the same fact.
    expect(find.text('2 checked bags'), findsNWidgets(2));
    expect(find.text('Aircraft'), findsOneWidget);
    expect(find.text('A350'), findsOneWidget);
    expect(find.text('Fare'), findsOneWidget);
    expect(find.text('Flex'), findsOneWidget);
    expect(find.text('Refundable'), findsOneWidget);
    expect(find.text('Yes'), findsOneWidget);
    // The next-day marker is inlined with the arrival value.
    expect(find.textContaining('(+1)'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a next-day arrival is marked in the expanded panel', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      offers: <FlightOffer>[
        _offer(
          'f1',
          departure: DateTime(2026, 1, 1, 23, 50),
          arrival: DateTime(2026, 1, 2, 5, 10),
        ),
      ],
    );
    await _search(tester);

    await tester.tap(find.byType(FlightSearchCard).first);
    await tester.pumpAndSettle();

    expect(find.textContaining('(+1)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing optional data adds no row and no empty value', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      offers: <FlightOffer>[
        _offer('f1', cabinClass: null, stops: null),
      ],
    );
    await _search(tester);

    await tester.tap(find.byType(FlightSearchCard).first);
    await tester.pumpAndSettle();

    expect(find.text('Layover'), findsNothing);
    expect(find.text('Cabin'), findsNothing);
    expect(find.text('Baggage'), findsNothing);
    expect(find.text('Aircraft'), findsNothing);
    expect(find.text('Fare'), findsNothing);
    expect(find.text('Refundable'), findsNothing);
    // The facts that ARE present still render honestly.
    expect(find.text('Non-stop'), findsWidgets);
    expect(find.text('Airline'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the expanded action opens the details of THAT offer', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      offers: <FlightOffer>[_offer('f1'), _offer('f2')],
    );
    await _search(tester);

    await tester.tap(find.byType(FlightSearchCard).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View offer and book'));
    await tester.pumpAndSettle();

    expect(find.text('OFFER f2'), findsOneWidget);
    expect(find.text('OFFER f1'), findsNothing);
  });

  testWidgets('sorting still reorders the feed', (WidgetTester tester) async {
    await _pump(
      tester,
      offers: <FlightOffer>[
        _offer('expensive', airline: 'Air Alpha', price: 300),
        _offer('cheap', airline: 'Air Beta', price: 100),
      ],
    );
    await _search(tester);

    // "Recommended" keeps the provider's order.
    double dyOf(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(dyOf('Air Alpha'), lessThan(dyOf('Air Beta')));

    await tester.tap(find.text('Cheapest'));
    await tester.pumpAndSettle();

    expect(dyOf('Air Beta'), lessThan(dyOf('Air Alpha')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed search still shows the error state and retry works', (
    WidgetTester tester,
  ) async {
    final _FakeFlightRepository repository = _FakeFlightRepository(
      <FlightOffer>[_offer('f1')],
      failures: 1,
    );
    await _pump(tester, repository: repository);
    await _search(tester);

    expect(find.text('Connection error'), findsOneWidget);
    expect(find.byType(FlightSearchCard), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Connection error'), findsNothing);
    expect(find.byType(FlightSearchCard), findsOneWidget);
    expect(repository.calls, 2);
  });

  testWidgets('an empty result set still shows the empty state', (
    WidgetTester tester,
  ) async {
    await _pump(tester, offers: const <FlightOffer>[]);
    await _search(tester);

    expect(find.text('No flights found'), findsOneWidget);
    expect(find.byType(FlightSearchCard), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the feed expands in Arabic (RTL) without breaking', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      direction: TextDirection.rtl,
      offers: <FlightOffer>[_offer('f1')],
    );
    await _search(tester);

    await tester.tap(find.byType(FlightSearchCard).first);
    await tester.pumpAndSettle();

    expect(_panel(), findsOneWidget);
    expect(find.text('Airline'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduce motion reveals the panel without an animation', (
    WidgetTester tester,
  ) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );

    await _pump(tester, offers: <FlightOffer>[_offer('f1')]);
    await _search(tester);

    await tester.tap(find.byType(FlightSearchCard).first);
    // One frame is enough: the reveal duration collapses to zero.
    await tester.pump(const Duration(milliseconds: 1));

    expect(_panel(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a 320pt phone expands without overflowing', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      size: const Size(640, 1280),
      pixelRatio: 2,
      offers: <FlightOffer>[
        _offer(
          'f1',
          airline: 'A Very Long Airline Name For Testing Purposes',
          origin: 'CAI',
          destination: 'DXB',
          metadata: <String, dynamic>{
            'aircraft': 'Airbus A350-1000',
            'fareFamily': 'Flex Plus Extra',
          },
        ),
      ],
    );
    await _search(tester);

    await tester.tap(find.byType(FlightSearchCard).first);
    await tester.pumpAndSettle();

    expect(_panel(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
