import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_section.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/core/network/api_error.dart';
import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/core/repositories/contracts/home_repository.dart';
import 'package:tokigo/features/home/domain/promotional_stay.dart';
import 'package:tokigo/features/home/presentation/nearby_stays_controller.dart';
import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/core/widgets/cards/card_favorite.dart';
import 'package:tokigo/features/home/presentation/home_card_dimensions.dart';
import 'package:tokigo/features/home/presentation/pages/home_page.dart';
import 'package:tokigo/features/home/presentation/widgets/cover_flow_carousel.dart';
import 'package:tokigo/features/home/presentation/widgets/home_discovery_stay_card.dart';
import 'package:tokigo/features/home/presentation/widgets/home_split_stay_card.dart';
import 'package:tokigo/features/home/presentation/widgets/home_stay_card.dart';
import 'package:tokigo/features/home/presentation/widgets/home_stays_carousel.dart';
import 'package:tokigo/features/home/providers/home_providers.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Section 5 — Home "Stays Near You" card geometry.
///
/// The approved contract, measured on the RENDERED widgets:
/// * the stay rail shares the Trending Destinations page width, and its card
///   is deliberately TALLER: the hotel photo on top, its description below
///   (owner request, 2026-11);
/// * the photo region sits above the description region;
/// * the loading skeleton occupies exactly the loaded card's box;
/// * the split card itself keeps the approved 60 / 40 regions for the
///   surfaces that opt into `splitLayout`;
/// * the shared 3D cover flow and the card's own interactions are intact.
///
/// Every assertion here measures a rendered rect; none of them inspects a
/// constant in place of a layout.

// A 360 x 740 logical phone — the same size the other Home rail tests use.
const Size _phone = Size(720, 1480);
// Tall enough to lay out BOTH rails of the real Home page in one viewport.
const Size _tallPhone = Size(720, 2800);

// Sub-pixel rounding in the PageView's viewport-fraction layout is the only
// source of difference between two cards that share one page formula, so a
// 1px tolerance is the honest bound.
const double _tolerance = 1.0;

void _setView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void _setTextScale(WidgetTester tester, double scale) {
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

HomeItem _stay(String id) => HomeItem(
  id: id,
  type: HomeCardType.hotel,
  title: 'Riverside Grand Hotel $id',
  subtitle: 'Lisbon',
  price: 186,
  currency: 'USD',
  rating: 4.8,
  reviewCount: 48,
  metadata: const <String, dynamic>{'city': 'Lisbon', 'stars': 5},
);

HomeItem _city(String id) => HomeItem(
  id: id,
  type: HomeCardType.destination,
  title: 'Lisbon$id',
  subtitle: 'Portugal',
  metadata: const <String, dynamic>{'country': 'Portugal'},
);

/// The Home "Stays Near You" rail, wired exactly as the Home page wires it.
Widget _splitRail(List<HomeItem> items, {bool loading = false}) {
  return HomeStaysCarousel(
    items: items,
    loading: loading,
    splitLayout: true,
    showHeartPlatter: false,
    viewportFraction: HomeCardDimensions.destinationViewportFraction,
    cardHeightBuilder: HomeStaysCarousel.splitCardHeightFor,
  );
}

Widget _railHost(Widget child, {TextDirection direction = TextDirection.ltr}) {
  return ProviderScope(
    child: MaterialApp(
      theme: AppTheme.light(),
      home: Directionality(
        textDirection: direction,
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
}

/// A bounded host for a bare card: the split body's `Spacer` needs a bounded
/// height, which a `SingleChildScrollView` does not provide.
Widget _cardHost(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

Finder _splitRow() => find
    .descendant(of: find.byType(HomeSplitStayCard), matching: find.byType(Row))
    .first;

List<Rect> _splitRegions(WidgetTester tester) {
  final Finder expanded = find.descendant(
    of: find.byType(HomeSplitStayCard),
    matching: find.byType(Expanded),
  );
  return <Rect>[
    tester.getRect(expanded.at(0)), // photo
    tester.getRect(expanded.at(1)), // information
  ];
}

// ── Real Home page harness ─────────────────────────────────────────────────

class _NearbyRepo implements HomeRepository {
  _NearbyRepo(this.response);

  final NearbyStaysResponse? response;

  @override
  Future<NearbyStaysResponse?> readCachedNearbyStays({String? scope}) async =>
      response;

  @override
  Future<void> writeCachedNearbyStays(
    NearbyStaysResponse response, {
    String? scope,
  }) async {}

  @override
  Future<ApiResult<NearbyStaysResponse>> fetchNearbyStays({
    double? latitude,
    double? longitude,
    double? accuracy,
    String? cityId,
    String? city,
    String? country,
    String languageCode = 'en',
    String? currency,
  }) async => response == null
      ? const ApiResult<NearbyStaysResponse>.failure(
          ApiNetworkError(message: 'no nearby payload'),
        )
      : ApiResult<NearbyStaysResponse>.success(response!);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PromotionalStay _promotionalStay(String id) => PromotionalStay(
  hotelId: 'promo-$id',
  hotelName: 'Riverside Grand Hotel $id',
  city: 'Lisbon',
  country: 'PT',
  image: null,
  latitude: 38.72,
  longitude: -9.14,
  distanceKm: 1.2,
  rating: 4.8,
  reviewCount: 48,
  promotionalMinimumPrice: 186,
  currency: 'USD',
  searchedFromDate: '2026-11-21',
  searchedToDate: '2026-11-28',
  occupancy: 2,
  nationality: 'EG',
  provider: 'nuitee',
  fetchedAt: DateTime.utc(2026, 11, 21),
  locationConfidence: 'high',
);

Widget _pageHost({
  Locale locale = const Locale('en'),
  List<PromotionalStay> nearbyStays = const <PromotionalStay>[],
}) {
  final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(path: '/', builder: (context, state) => const HomePage()),
    ],
  );
  final NearbyStaysResponse? nearbyResponse = nearbyStays.isEmpty
      ? null
      : NearbyStaysResponse(
          stays: nearbyStays,
          radiusKm: 10,
          locationConfidence: 'high',
          locationSource: 'gps',
          locationRequired: false,
          currency: 'USD',
          occupancy: 2,
          nationality: 'EG',
          rankingVersion: 'nearby-ranking-v1',
          partialFailure: false,
          fetchedAt: DateTime.utc(2026, 11, 21),
        );
  return ProviderScope(
    overrides: <Override>[
      nearbyStaysControllerProvider.overrideWith(
        (ref) => NearbyStaysController(_NearbyRepo(nearbyResponse)),
      ),
      geoCountryProvider.overrideWith((ref) async => null),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      theme: AppTheme.light(),
      locale: locale,
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

void main() {
  group('Section 5 — split stay card geometry', () {
    testWidgets(
      'the tall stay card keeps the city width, photo above description',
      (tester) async {
        _setView(tester, _tallPhone);

        await tester.pumpWidget(
          _pageHost(
            nearbyStays: <PromotionalStay>[
              _promotionalStay('a'),
              _promotionalStay('b'),
            ],
          ),
        );
        // Let the controller's startup (snapshot → load → rail) settle.
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        final Rect city = tester.getRect(
          find.byType(HomeDiscoveryStayCard).at(0),
        );
        final Finder stayCard = find.byType(HomeStayCard).first;
        final Rect stay = tester.getRect(stayCard);

        // Both rails are full-width slivers of the SAME scroll view, so their
        // page boxes share one width. The stay card is deliberately TALLER
        // (owner request, 2026-11): the hotel photo on top, the description
        // below it.
        expect(stay.width, closeTo(city.width, _tolerance));
        expect(stay.height, greaterThan(city.height + 100));
        expect(stay.width, greaterThan(0));
        expect(stay.height, greaterThan(0));

        // Photo above the description: the media box starts at the card's top
        // edge and ends before the title.
        final Rect media = tester.getRect(
          find
              .descendant(of: stayCard, matching: find.byType(AspectRatio))
              .first,
        );
        final Rect title = tester.getRect(
          find.descendant(
            of: stayCard,
            matching: find.text('Riverside Grand Hotel a'),
          ),
        );
        // The photo is INSET inside the card (white margin, rounded corners), so
        // it starts below the card's top edge and ends before the title.
        expect(media.top, greaterThan(stay.top));
        expect(media.left, greaterThan(stay.left));
        expect(media.bottom, lessThanOrEqualTo(title.top + _tolerance));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('the loaded Nearby stay card matches the city width', (
      tester,
    ) async {
      _setView(tester, _tallPhone);
      await tester.pumpWidget(
        _pageHost(
          nearbyStays: <PromotionalStay>[
            _promotionalStay('a'),
            _promotionalStay('b'),
          ],
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // The promotional rail renders the same approved photo-above-description
      // card, at the same page width as the Explore rail.
      expect(find.byType(HomeStayCard), findsWidgets);
      final Rect city = tester.getRect(
        find.byType(HomeDiscoveryStayCard).at(0),
      );
      final Rect loaded = tester.getRect(find.byType(HomeStayCard).first);
      expect(loaded.width, closeTo(city.width, _tolerance));
      expect(loaded.height, greaterThan(city.height + 100));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'the photo and information regions keep the approved 60/40 split',
      (tester) async {
        _setView(tester, _phone);
        await tester.pumpWidget(_railHost(_splitRail(<HomeItem>[_stay('a')])));
        await tester.pump(const Duration(milliseconds: 300));

        final Rect row = tester.getRect(_splitRow());
        final List<Rect> regions = _splitRegions(tester);

        expect(regions[0].width, closeTo(row.width * 0.6, _tolerance));
        expect(regions[1].width, closeTo(row.width * 0.4, _tolerance));
        // The two regions tile the row exactly: no gutter, no overlap.
        expect(regions[0].right, closeTo(regions[1].left, _tolerance));
        expect(regions[0].left, closeTo(row.left, _tolerance));
        expect(regions[1].right, closeTo(row.right, _tolerance));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'the 60/40 split survives a large text scale and a narrow phone',
      (tester) async {
        for (final Size size in <Size>[
          _phone,
          const Size(640, 1280), // 320 logical
        ]) {
          for (final double scale in <double>[1.5, 2.0]) {
            _setView(tester, size);
            _setTextScale(tester, scale);
            await tester.pumpWidget(
              _railHost(_splitRail(<HomeItem>[_stay('a')])),
            );
            await tester.pump(const Duration(milliseconds: 300));

            final Rect row = tester.getRect(_splitRow());
            final List<Rect> regions = _splitRegions(tester);
            expect(
              regions[0].width,
              closeTo(row.width * 0.6, _tolerance),
              reason: 'width=$size scale=$scale',
            );
            expect(
              regions[1].width,
              closeTo(row.width * 0.4, _tolerance),
              reason: 'width=$size scale=$scale',
            );
            expect(
              tester.takeException(),
              isNull,
              reason: 'width=$size scale=$scale',
            );
          }
        }
      },
    );

    testWidgets(
      'the photo sits on the starting side in LTR and mirrors in RTL',
      (tester) async {
        _setView(tester, _phone);

        await tester.pumpWidget(
          _railHost(
            _splitRail(<HomeItem>[_stay('a')]),
            direction: TextDirection.ltr,
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        final Rect ltrRow = tester.getRect(_splitRow());
        final List<Rect> ltr = _splitRegions(tester);
        expect(ltr[0].left, closeTo(ltrRow.left, _tolerance));
        expect(ltr[1].right, closeTo(ltrRow.right, _tolerance));

        await tester.pumpWidget(
          _railHost(
            _splitRail(<HomeItem>[_stay('a')]),
            direction: TextDirection.rtl,
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        final Rect rtlRow = tester.getRect(_splitRow());
        final List<Rect> rtl = _splitRegions(tester);
        // RTL: the starting side is the RIGHT edge.
        expect(rtl[0].right, closeTo(rtlRow.right, _tolerance));
        expect(rtl[1].left, closeTo(rtlRow.left, _tolerance));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('the loading skeleton occupies exactly the loaded card box', (
      tester,
    ) async {
      _setView(tester, _phone);

      await tester.pumpWidget(
        _railHost(_splitRail(const <HomeItem>[], loading: true)),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final Rect skeleton = tester.getRect(find.byType(HomeStayCard));

      await tester.pumpWidget(_railHost(_splitRail(<HomeItem>[_stay('a')])));
      await tester.pump(const Duration(milliseconds: 300));
      final Rect loaded = tester.getRect(find.byType(HomeStayCard));

      expect(skeleton.size, loaded.size);
      expect(skeleton.topLeft, loaded.topLeft);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the skeleton keeps the loaded box at a large text scale too', (
      tester,
    ) async {
      _setView(tester, _phone);
      _setTextScale(tester, 2.0);

      await tester.pumpWidget(
        _railHost(_splitRail(const <HomeItem>[], loading: true)),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final Rect skeleton = tester.getRect(find.byType(HomeStayCard));

      await tester.pumpWidget(_railHost(_splitRail(<HomeItem>[_stay('a')])));
      await tester.pump(const Duration(milliseconds: 300));
      final Rect loaded = tester.getRect(find.byType(HomeStayCard));

      expect(skeleton.size, loaded.size);
      expect(skeleton.topLeft, loaded.topLeft);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the cover flow is preserved and one swipe advances one card', (
      tester,
    ) async {
      _setView(tester, _phone);

      await tester.pumpWidget(
        _railHost(_splitRail(<HomeItem>[_stay('a'), _stay('b'), _stay('c')])),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(CoverFlowCarousel), findsOneWidget);

      final Rect viewport = tester.getRect(find.byType(PageView));
      final Rect focal = tester.getRect(find.byType(HomeStayCard).at(0));
      final Rect neighbour = tester.getRect(find.byType(HomeStayCard).at(1));

      // Centred cover flow: the focal card is centred and the neighbour peeks.
      expect(focal.center.dx, closeTo(viewport.center.dx, _tolerance));
      expect(focal.width, closeTo(viewport.width * 0.9, _tolerance));
      expect(neighbour.intersect(viewport).width, greaterThan(0));
      expect(neighbour.width, lessThan(focal.width));

      await tester.drag(find.byType(PageView), const Offset(-320, 0));
      await tester.pumpAndSettle();

      final PageController controller = tester
          .widget<PageView>(find.byType(PageView))
          .controller!;
      expect(controller.page, closeTo(1, 0.001));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the favourite heart and the card tap stay wired', (
      tester,
    ) async {
      _setView(tester, _phone);
      bool saved = false;
      int taps = 0;

      await tester.pumpWidget(
        _cardHost(
          HomeSplitStayCard(
            media: const ColoredBox(color: Colors.red),
            title: 'Riverside Grand',
            amountText: '186',
            currency: 'USD',
            rating: 4.8,
            location: 'Lisbon, Portugal',
            onFavorite: (bool value) => saved = value,
            onTap: () => taps++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CardFavorite));
      await tester.pumpAndSettle();
      expect(saved, isTrue);

      await tester.tap(find.byType(HomeSplitStayCard));
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    });
  });
}
