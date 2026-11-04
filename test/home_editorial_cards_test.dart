import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/core/widgets/app_icon_action.dart';
import 'package:tokigo/core/widgets/app_back_button.dart';
import 'package:tokigo/core/widgets/cards/card_overlap.dart';
import 'package:tokigo/core/widgets/cards/card_image.dart';
import 'package:tokigo/core/widgets/cards/overlap_stay_card.dart';
import 'package:tokigo/core/widgets/page_header.dart';
import 'package:tokigo/features/home/presentation/widgets/deal_card.dart';
import 'package:tokigo/features/home/presentation/widgets/destination_discovery_card.dart';
import 'package:tokigo/features/home/presentation/widgets/discovery_product_card.dart';
import 'package:tokigo/features/home/presentation/widgets/flight_recommendation_card.dart';
import 'package:tokigo/features/home/presentation/widgets/home_discovery_stay_card.dart';
import 'package:tokigo/features/home/presentation/widgets/home_ai_search_field.dart';
import 'package:tokigo/app/widgets/home_nav_buttons.dart';
import 'package:tokigo/l10n/app_localizations.dart';

void _setPhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(720, 1480);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

HomeItem _item({
  required String id,
  required HomeCardType type,
  required String title,
  String? subtitle,
  double? price,
  double? rating,
  Map<String, dynamic> metadata = const <String, dynamic>{},
}) => HomeItem(
  id: id,
  type: type,
  title: title,
  subtitle: subtitle,
  price: price,
  currency: 'USD',
  rating: rating,
  reviewCount: 48,
  metadata: metadata,
);

Widget _app({
  required ThemeMode themeMode,
  required Locale locale,
  required Widget child,
}) {
  final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: SingleChildScrollView(
            child: Padding(padding: const EdgeInsets.all(16), child: child),
          ),
        ),
      ),
      GoRoute(
        path: '/flights',
        builder: (context, state) =>
            const Scaffold(body: Text('Flight search opened')),
      ),
      GoRoute(
        path: '/hotels',
        builder: (context, state) =>
            const Scaffold(body: Text('Hotel search opened')),
      ),
      GoRoute(
        path: '/cars',
        builder: (context, state) =>
            const Scaffold(body: Text('Car search opened')),
      ),
      GoRoute(
        path: '/packages',
        builder: (context, state) =>
            const Scaffold(body: Text('Activities opened')),
      ),
      GoRoute(
        path: '/bag',
        builder: (context, state) =>
            const Scaffold(body: Text('My trips opened')),
      ),
      GoRoute(
        path: '/explore',
        builder: (context, state) =>
            const Scaffold(body: Text('Explore cities opened')),
      ),
    ],
  );
  return MaterialApp.router(
    routerConfig: router,
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    themeMode: themeMode,
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
  );
}

void main() {
  testWidgets('Home search surface follows the active theme', (
    WidgetTester tester,
  ) async {
    for (final ThemeMode mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
      await tester.pumpWidget(
        _app(
          themeMode: mode,
          locale: const Locale('en'),
          child: const HomeAiSearchField(),
        ),
      );
      await tester.pumpAndSettle();

      final Container field = tester.widget<Container>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.constraints?.minHeight == 56 &&
              widget.decoration is BoxDecoration,
        ),
      );
      final BoxDecoration decoration = field.decoration! as BoxDecoration;
      expect(
        decoration.color,
        mode == ThemeMode.dark ? const Color(0xFF1A2338) : Colors.white,
      );
      expect(
        decoration.boxShadow,
        isEmpty,
      );
    }
  });

  for (final ThemeMode mode in <ThemeMode>[ThemeMode.dark, ThemeMode.light]) {
    for (final Locale locale in <Locale>[
      const Locale('en'),
      const Locale('ar'),
    ]) {
      testWidgets('Home cards fit in $mode / ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        _setPhoneSize(tester);
        final HomeItem hotel = _item(
          id: 'hotel',
          type: HomeCardType.hotel,
          title: 'Riverside Grand Hotel',
          subtitle: 'Lisbon, Portugal',
          price: 186,
          rating: 4.8,
          metadata: const <String, dynamic>{'stars': 5},
        );
        final HomeItem city = _item(
          id: 'city',
          type: HomeCardType.destination,
          title: 'Lisbon',
          subtitle: 'Portugal',
          metadata: const <String, dynamic>{
            'country': 'Portugal',
            'staysCount': 24,
          },
        );
        final HomeItem deal = _item(
          id: 'deal',
          type: HomeCardType.deal,
          title: 'Lisbon Weekend Escape',
          subtitle: 'Lisbon',
          price: 299,
          metadata: const <String, dynamic>{'savingsPercent': 25},
        );
        final HomeItem product = _item(
          id: 'car',
          type: HomeCardType.car,
          title: 'Premium city car',
          subtitle: 'Automatic · 5 seats',
          price: 55,
          rating: 4.6,
        );
        final HomeItem flight = _item(
          id: 'flight',
          type: HomeCardType.flight,
          title: 'TokiGo Air',
          price: 240,
          metadata: const <String, dynamic>{
            'airline': 'TokiGo Air',
            'flightNumber': 'TG 421',
            'departureTime': '2026-03-01T10:00:00Z',
            'arrivalTime': '2026-03-01T14:00:00Z',
            'origin': 'LIS',
            'destination': 'CAI',
            'stops': 0,
          },
        );

        await tester.pumpWidget(
          _app(
            themeMode: mode,
            locale: locale,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(width: 360, child: const HomeNavButtons()),
                const SizedBox(height: 12),
                OverlapStayCard(
                  media: const ColoredBox(color: Colors.blueGrey),
                  title: hotel.title,
                  amountText: '186',
                  currency: 'USD',
                  unit: locale.languageCode == 'ar' ? 'ليلة' : 'night',
                  rating: hotel.rating,
                  reviewCount: hotel.reviewCount,
                  location: hotel.subtitle,
                  aspectRatio: 1.6,
                ),
                const SizedBox(height: 12),
                HomeDiscoveryStayCard(
                  item: city,
                  onTap: () {},
                  aspectRatio: 1.3,
                  fillSheet: false,
                ),
                const SizedBox(height: 12),
                DealCard(item: deal, onTap: () {}),
                const SizedBox(height: 12),
                DiscoveryProductCard(item: product, onTap: () {}),
                const SizedBox(height: 12),
                FlightRecommendationCard(item: flight, onTap: () {}),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Riverside Grand Hotel'), findsOneWidget);
        expect(find.text('Lisbon Weekend Escape'), findsOneWidget);
        expect(find.text('Premium city car'), findsOneWidget);
        expect(find.text('TokiGo Air'), findsOneWidget);
        expect(find.byIcon(Icons.bed_outlined), findsNothing);
        if (locale.languageCode == 'ar') {
          expect(find.text('ليلة'), findsOneWidget);
          expect(find.text('/ ليلة'), findsNothing);
        }
        expect(find.byType(CardOverlap), findsNothing);
        final Rect cityRect = tester.getRect(
          find.byType(HomeDiscoveryStayCard),
        );
        final Rect cityImageRect = tester.getRect(
          find.descendant(
            of: find.byType(HomeDiscoveryStayCard),
            matching: find.byType(CardImage),
          ),
        );
        expect(cityImageRect.left, cityRect.left + 1);
        expect(cityImageRect.top, cityRect.top + 1);
        expect(
          cityImageRect.size,
          Size(cityRect.width - 2, cityRect.height - 2),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('Home navigation tiles still open their destination', (
    WidgetTester tester,
  ) async {
    _setPhoneSize(tester);
    await tester.pumpWidget(
      _app(
        themeMode: ThemeMode.light,
        locale: const Locale('en'),
        child: const SizedBox(width: 360, child: HomeNavButtons()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Flights'));
    await tester.pumpAndSettle();

    expect(find.text('Flight search opened'), findsOneWidget);
  });

  testWidgets('Home navigation has four tiles in a single row', (
    WidgetTester tester,
  ) async {
    _setPhoneSize(tester);
    await tester.pumpWidget(
      _app(
        themeMode: ThemeMode.light,
        locale: const Locale('en'),
        child: const SizedBox(width: 360, child: HomeNavButtons()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Expanded), findsNWidgets(4));
    expect(find.text('Flights'), findsOneWidget);
    expect(find.text('Stays'), findsOneWidget);
    expect(find.text('Cars Rental'), findsOneWidget);
    expect(find.text('Trips'), findsOneWidget);
    // Activities was replaced by the Trips tile; Explore was never a Home one.
    expect(find.text('Activities'), findsNothing);
    expect(find.text('Explore'), findsNothing);

    final Offset flights = tester.getCenter(find.text('Flights'));
    final Offset stays = tester.getCenter(find.text('Stays'));
    final Offset cars = tester.getCenter(find.text('Cars Rental'));
    final Offset trips = tester.getCenter(find.text('Trips'));
    // One row: the four labels share a baseline. Compared with a tolerance
    // because a label long enough to be scaled by the FittedBox lands on a
    // sub-pixel offset (the row itself is exact).
    expect(flights.dy, closeTo(stays.dy, 0.01));
    expect(stays.dy, closeTo(cars.dy, 0.01));
    expect(cars.dy, closeTo(trips.dy, 0.01));
    expect(flights.dx, lessThan(stays.dx));
    expect(stays.dx, lessThan(cars.dx));
    expect(cars.dx, lessThan(trips.dx));
  });

  testWidgets('Cars and Trips tiles open their pages', (
    WidgetTester tester,
  ) async {
    _setPhoneSize(tester);
    await tester.pumpWidget(
      _app(
        themeMode: ThemeMode.light,
        locale: const Locale('en'),
        child: const SizedBox(width: 360, child: HomeNavButtons()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cars Rental'));
    await tester.pumpAndSettle();
    expect(find.text('Car search opened'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      _app(
        themeMode: ThemeMode.light,
        locale: const Locale('en'),
        child: const SizedBox(width: 360, child: HomeNavButtons()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trips'));
    await tester.pumpAndSettle();
    expect(find.text('My trips opened'), findsOneWidget);
  });

  testWidgets('Stay price aligns to the start of the card', (
    WidgetTester tester,
  ) async {
    _setPhoneSize(tester);
    for (final TextDirection direction in <TextDirection>[
      TextDirection.ltr,
      TextDirection.rtl,
    ]) {
      await tester.pumpWidget(
        _app(
          themeMode: ThemeMode.light,
          locale: const Locale('en'),
          child: Directionality(
            textDirection: direction,
            // A bare amount (no currency/unit) so the price line is exactly
            // the text we measure.
            child: const SizedBox(
              width: 320,
              child: OverlapStayCard(
                media: ColoredBox(color: Colors.blueGrey),
                title: 'Riverside Grand Hotel',
                amountText: '186',
                aspectRatio: 1.6,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Rect card = tester.getRect(find.byType(OverlapStayCard));
      final Rect price = tester.getRect(find.text('186'));

      if (direction == TextDirection.ltr) {
        // English reads left-to-right: the nightly price sits on the LEFT.
        expect(price.center.dx, lessThan(card.center.dx));
      } else {
        // Arabic mirrors: the price keeps the right (start) side.
        expect(price.center.dx, greaterThan(card.center.dx));
      }
    }
  });

  testWidgets('Arabic page headers mirror titles and back button position', (
    WidgetTester tester,
  ) async {
    _setPhoneSize(tester);
    await tester.pumpWidget(
      _app(
        themeMode: ThemeMode.light,
        locale: const Locale('ar'),
        child: const AppPageHeader(title: 'الإعدادات'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('الإعدادات'), findsOneWidget);
    final BuildContext backControl = tester.element(find.byType(AppIconAction));
    // Arabic RTL: back control sits on the right side of the title and reads
    // right-to-left.
    expect(Directionality.of(backControl), TextDirection.rtl);
    expect(find.byType(AppBackButton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editorial card skeletons preserve their distinct layouts', (
    WidgetTester tester,
  ) async {
    _setPhoneSize(tester);
    await tester.pumpWidget(
      _app(
        themeMode: ThemeMode.dark,
        locale: const Locale('en'),
        child: const Column(
          children: <Widget>[
            SizedBox(
              width: 220,
              child: DestinationDiscoveryCard(
                item: HomeItem(
                  id: 'loading-city',
                  type: HomeCardType.destination,
                  title: '',
                ),
                loading: true,
              ),
            ),
            SizedBox(height: 12),
            SizedBox(
              width: 220,
              child: OverlapStayCard.skeleton(aspectRatio: 1.6),
            ),
            SizedBox(height: 12),
            SizedBox(
              width: 280,
              child: DealCard(
                item: HomeItem(
                  id: 'loading',
                  type: HomeCardType.deal,
                  title: '',
                ),
                loading: true,
              ),
            ),
            SizedBox(height: 12),
            SizedBox(
              width: 220,
              height: 276,
              child: DiscoveryProductCard.loading(),
            ),
            SizedBox(height: 12),
            SizedBox(
              width: 300,
              height: 252,
              child: FlightRecommendationCard(
                item: HomeItem(
                  id: 'loading-flight',
                  type: HomeCardType.flight,
                  title: '',
                ),
                loading: true,
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(DealCard), findsOneWidget);
    expect(find.byType(DiscoveryProductCard), findsOneWidget);
    expect(find.byType(FlightRecommendationCard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
