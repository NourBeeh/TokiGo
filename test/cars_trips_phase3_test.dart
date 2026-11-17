import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/domain/models/offers/car_offer.dart';
import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/core/widgets/cards/card_image.dart';
import 'package:tokigo/features/bag/application/bag_controller.dart';
import 'package:tokigo/features/bag/domain/trip.dart';
import 'package:tokigo/features/bag/presentation/pages/bag_page.dart';
import 'package:tokigo/features/bag/presentation/pages/trip_details_page.dart';
import 'package:tokigo/features/home/application/trip_draft_provider.dart';
import 'package:tokigo/features/home/presentation/pages/trip_builder_page.dart';
import 'package:tokigo/features/search/presentation/pages/car_search_page.dart';
import 'package:tokigo/features/search/presentation/widgets/car_search_card.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Phase 3 — Cars & Trips card presentation contracts.
///
/// These are the surfaces the other suites do not cover: the car result card,
/// the My Trips list/details cards and the trip-builder selection rows. They
/// pin what each card states, the presentation it uses at phone widths, and
/// the fact that a compact screen must reflow rather than clip.
CarOffer _car({
  String title = 'Kia Picanto',
  String carType = 'Economy',
  String transmission = 'Automatic',
  int seats = 5,
  double price = 25,
  Map<String, dynamic>? metadata,
}) => CarOffer(
  id: 'c1',
  providerId: 'p',
  providerName: 'Provider',
  title: title,
  price: price,
  currency: 'USD',
  pickupLocation: 'Cairo Airport',
  dropoffLocation: 'Cairo Downtown',
  pickupTime: DateTime(2026, 12, 1, 9),
  dropoffTime: DateTime(2026, 12, 3, 9),
  carType: carType,
  transmission: transmission,
  seats: seats,
  imageUrl: 'https://example.com/a.jpg',
  metadata: metadata ?? const <String, dynamic>{},
);

TripSummary _trip({
  String tripId = 'trip-bk_1',
  String title = 'Riverside Grand',
  String destination = 'Cairo',
  String status = 'confirmed',
  int? travelers,
}) => TripSummary(
  tripId: tripId,
  bookingId: 'bk_1',
  type: 'hotel',
  destination: destination,
  title: title,
  startDate: DateTime(2026, 12, 1),
  endDate: DateTime(2026, 12, 3),
  status: status,
  total: 480,
  currency: 'USD',
  bookingReference: 'WT-8F3K2Q',
  providerName: 'Nuitee',
  travelersCount: travelers,
);

Widget _wrap(Widget child, {TextDirection direction = TextDirection.ltr}) {
  return MaterialApp(
    theme: AppTheme.light(),
    locale: const Locale('en'),
    supportedLocales: const <Locale>[Locale('en')],
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Directionality(
      textDirection: direction,
      child: Scaffold(body: child),
    ),
  );
}

/// Sets the logical viewport for a test and restores it afterwards.
void _viewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  TextDirection direction = TextDirection.ltr,
  Size size = const Size(412, 900),
  double textScale = 1.0,
}) async {
  _viewport(tester, size);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(_wrap(child, direction: direction));
  await tester.pumpAndSettle();
}

ProviderContainer _bagContainer(BagController controller) {
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      bagControllerProvider.overrideWith((ref) => controller),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Skeleton cards animate a shimmer forever, so `pumpAndSettle` would never
/// return — pump a fixed frame instead.
Future<void> _pumpFrames(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(412, 900),
}) async {
  _viewport(tester, size);
  await tester.pumpWidget(child);
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('Cars cards', () {
    testWidgets('a result card states exactly what the offer carries', (
      tester,
    ) async {
      await _pump(tester, CarSearchCard(offer: _car()));

      expect(find.text('Kia Picanto'), findsOneWidget);
      expect(find.text('Economy'), findsOneWidget);
      expect(find.text('Automatic'), findsOneWidget);
      expect(find.text('5 seats'), findsOneWidget);
      // Per-day price plus the derived two-day total.
      expect(find.text('/day'), findsWidgets);
      expect(find.text('total'), findsOneWidget);
      expect(find.text('USD 25'), findsWidgets);
      expect(find.text('USD 50'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping the result card hands off to car details', (
      tester,
    ) async {
      bool opened = false;
      await _pump(
        tester,
        CarSearchCard(offer: _car(), onTap: () => opened = true),
      );

      await tester.tap(find.byType(CarSearchCard));
      await tester.pumpAndSettle();

      expect(opened, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the regular phone width keeps the approved horizontal split', (
      tester,
    ) async {
      await _pump(tester, CarSearchCard(offer: _car()));

      final Rect image = tester.getRect(find.byType(CardImage).first);
      final Rect title = tester.getRect(find.text('Kia Picanto'));
      // LTR: the photo leads, the text follows.
      expect(image.right, lessThan(title.left));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a compact screen stacks the card instead of clipping it', (
      tester,
    ) async {
      // 320dp with large accessibility text — the case a 45% text column
      // cannot serve.
      await _pump(
        tester,
        CarSearchCard(
          offer: _car(
            title: 'Mercedes-Benz E-Class Long Wheelbase Executive Edition',
            metadata: const <String, dynamic>{
              'originalPrice': 120,
              'orSimilar': true,
              'freeCancellation': true,
              'mileagePolicy': 'Unlimited',
              'luggage': '3 bags',
            },
          ),
          onFavorite: (_) {},
        ),
        size: const Size(320, 900),
        textScale: 1.5,
      );

      expect(
        find.text('Mercedes-Benz E-Class Long Wheelbase Executive Edition'),
        findsOneWidget,
      );
      expect(find.text('79% OFF'), findsOneWidget);
      expect(find.text('3 bags'), findsOneWidget);
      // Stacked: the photo is above the text, both full card width.
      final Rect image = tester.getRect(find.byType(CardImage).first);
      final Rect title = tester.getRect(
        find.text('Mercedes-Benz E-Class Long Wheelbase Executive Edition'),
      );
      expect(image.bottom, lessThan(title.top));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the loading skeleton mirrors both layouts without data', (
      tester,
    ) async {
      await _pumpFrames(
        tester,
        _wrap(const CarSearchCard.loading()),
        size: const Size(320, 900),
      );
      expect(tester.takeException(), isNull);

      await _pumpFrames(
        tester,
        _wrap(const CarSearchCard.loading()),
        size: const Size(412, 900),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the card mirrors its split in RTL', (tester) async {
      await _pump(
        tester,
        CarSearchCard(offer: _car()),
        direction: TextDirection.rtl,
      );

      final Rect image = tester.getRect(find.byType(CardImage).first);
      final Rect title = tester.getRect(find.text('Kia Picanto'));
      expect(image.left, greaterThan(title.right));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the car surface stays honestly gated with no invented cars', (
      tester,
    ) async {
      await _pump(tester, const ProviderScope(child: CarSearchPage()));

      expect(find.text('Cars Rental is coming soon'), findsOneWidget);
      expect(find.byType(CarSearchCard), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('Trips cards', () {
    testWidgets('a trip card states the booked item, dates and reference', (
      tester,
    ) async {
      final BagController controller = BagController()
        ..addCurrent(_trip(travelers: 2));
      _viewport(tester, const Size(412, 900));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: _bagContainer(controller),
          child: _wrap(const BagPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Riverside Grand'), findsOneWidget);
      expect(find.text('Cairo'), findsOneWidget);
      expect(find.text('Hotel'), findsOneWidget);
      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.textContaining('WT-8F3K2Q'), findsOneWidget);
      expect(find.text('USD 480.00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an empty period says so instead of inventing a trip', (
      tester,
    ) async {
      final BagController controller = BagController();
      _viewport(tester, const Size(412, 900));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: _bagContainer(controller),
          child: _wrap(const BagPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No upcoming trips yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping a trip card opens its details', (tester) async {
      final BagController controller = BagController()..addCurrent(_trip());
      final GoRouter router = GoRouter(
        initialLocation: '/bag',
        routes: <RouteBase>[
          GoRoute(
            path: '/bag',
            builder: (BuildContext context, GoRouterState state) =>
                const BagPage(),
          ),
          GoRoute(
            path: '/bag/:tripId',
            builder: (BuildContext context, GoRouterState state) =>
                TripDetailsPage(tripId: state.pathParameters['tripId']!),
          ),
        ],
      );
      addTearDown(router.dispose);
      _viewport(tester, const Size(412, 900));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: _bagContainer(controller),
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

      await tester.tap(find.text('Riverside Grand'));
      await tester.pumpAndSettle();

      expect(find.byType(TripDetailsPage), findsOneWidget);
      expect(find.text('WT-8F3K2Q'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'the details page states the provider facts and the reference',
      (tester) async {
        final BagController controller = BagController()..addCurrent(_trip());
        _viewport(tester, const Size(412, 900));
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: _bagContainer(controller),
            child: _wrap(const TripDetailsPage(tripId: 'trip-bk_1')),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Riverside Grand'), findsOneWidget);
        expect(find.text('Total'), findsOneWidget);
        expect(find.text('USD 480.00'), findsOneWidget);
        expect(find.text('WT-8F3K2Q'), findsOneWidget);
        expect(find.text('Cancel booking'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('an unknown trip id says the trip is not in the bag', (
      tester,
    ) async {
      final BagController controller = BagController();
      _viewport(tester, const Size(412, 900));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: _bagContainer(controller),
          child: _wrap(const TripDetailsPage(tripId: 'missing')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Trip not found'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the trip builder lists a selected car and its total', (
      tester,
    ) async {
      final TripDraftController draft = TripDraftController()..create('Cairo');
      draft.add(_car());
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[tripDraftProvider.overrideWith((ref) => draft)],
      );
      addTearDown(container.dispose);
      _viewport(tester, const Size(412, 900));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _wrap(const TripBuilderPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kia Picanto'), findsOneWidget);
      expect(find.text('USD 25.00'), findsWidgets);
      expect(find.text('Current total'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('trips surfaces fit a 320dp screen in LTR and RTL', (
      tester,
    ) async {
      final TripSummary trip = _trip(
        title: 'A long booked hotel name that must stay readable',
      );
      _viewport(tester, const Size(320, 700));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: _bagContainer(BagController()..addCurrent(trip)),
          child: _wrap(const BagPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: _bagContainer(BagController()..addCurrent(trip)),
          child: _wrap(const BagPage(), direction: TextDirection.rtl),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: _bagContainer(BagController()..addCurrent(trip)),
          child: _wrap(const TripDetailsPage(tripId: 'trip-bk_1')),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
