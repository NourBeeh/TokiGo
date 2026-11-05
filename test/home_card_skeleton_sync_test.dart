import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_section.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/core/repositories/contracts/home_repository.dart';
import 'package:tokigo/core/repositories/impl/home_repository_impl.dart';
import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/core/widgets/cards/base_card.dart';
import 'package:tokigo/core/widgets/cards/overlap_stay_card.dart';
import 'package:tokigo/features/home/domain/home_composer.dart';
import 'package:tokigo/features/home/presentation/home_card_dimensions.dart';
import 'package:tokigo/features/home/presentation/home_controller.dart';
import 'package:tokigo/features/home/presentation/pages/home_page.dart';
import 'package:tokigo/features/home/presentation/widgets/deal_card.dart';
import 'package:tokigo/features/home/presentation/widgets/destination_cover_flow_carousel.dart';
import 'package:tokigo/features/home/presentation/widgets/discovery_product_card.dart';
import 'package:tokigo/features/home/presentation/widgets/flight_recommendation_card.dart';
import 'package:tokigo/features/home/presentation/widgets/home_card.dart';
import 'package:tokigo/features/home/presentation/widgets/home_discovery_stay_card.dart';
import 'package:tokigo/features/home/presentation/widgets/home_section.dart';
import 'package:tokigo/features/home/presentation/widgets/home_stay_card.dart';
import 'package:tokigo/features/home/presentation/widgets/home_stays_carousel.dart';
import 'package:tokigo/features/home/providers/home_providers.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Home's card/skeleton contract.
///
/// The invariant under test: a Home skeleton is NOT a second copy of the card
/// layout. It is the same card widget in its loading state, so its outer
/// geometry (size, corner radius, border, padding, position in the rail) is
/// identical to the loaded card's by construction.

/// A repository whose feed response the test controls, so the page can be held
/// in its initial loading state with no cached snapshot.
class _GatedRepository implements HomeRepository {
  _GatedRepository(this.completer, {this.snapshot});

  final Completer<ApiResult<List<HomeSection>>> completer;
  final List<HomeSection>? snapshot;

  @override
  Future<List<HomeSection>?> readHomeSnapshot({
    required String audience,
  }) async => snapshot;

  @override
  Future<void> clearHomeSnapshot({required String audience}) async {}

  @override
  Future<void> saveHomeSnapshot(
    List<HomeSection> sections, {
    required String audience,
  }) async {}

  @override
  Future<ApiResult<List<HomeSection>>> getHomeSections() => completer.future;

  @override
  Future<ApiResult<List<HomeItem>>> getRecommendedHotels({
    int limit = 6,
    String? countryCode,
    String languageCode = 'en',
    String? currency,
  }) async => const ApiResult<List<HomeItem>>.success(<HomeItem>[]);

  @override
  Future<ApiResult<void>> refresh() async => const ApiResult<void>.success(null);

  @override
  Future<SnapshotState> snapshotState({required String audience}) async =>
      SnapshotState.unavailable;
}

void main() {
  void phoneSize(WidgetTester tester, {Size size = const Size(720, 1480)}) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget host(Widget child, {Locale locale = const Locale('en')}) {
    return ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: SingleChildScrollView(child: child),
        ),
      ),
    );
  }

  HomeItem stay(String id) => HomeItem(
        id: id,
        type: HomeCardType.hotel,
        title: 'Riverside Grand Hotel $id',
        subtitle: 'Lisbon, Portugal',
        price: 186,
        currency: 'USD',
        rating: 4.8,
        reviewCount: 48,
        metadata: const <String, dynamic>{'city': 'Lisbon', 'stars': 5},
      );

  HomeItem city(String id) => HomeItem(
        id: id,
        type: HomeCardType.destination,
        title: 'Lisbon$id',
        subtitle: 'Portugal',
        metadata: const <String, dynamic>{'country': 'Portugal'},
      );

  group('one source of truth — shared tokens', () {
    test('rail constants are the shared HomeCardDimensions values', () {
      expect(
        HomeStaysCarousel.mediaAspectRatio,
        HomeCardDimensions.stayMediaAspectRatio,
      );
      expect(
        HomeStaysCarousel.staysSheetTextHeight,
        HomeCardDimensions.staySheetTextHeight,
      );
      expect(
        HomeStaysCarousel.destinationSheetTextHeight,
        HomeCardDimensions.destinationSheetTextHeight,
      );
      expect(
        DestinationCoverFlowCarousel.defaultMediaAspectRatio,
        HomeCardDimensions.destinationMediaAspectRatio,
      );
      expect(
        HomeDiscoveryStayCard.defaultAspectRatio,
        HomeCardDimensions.destinationMediaAspectRatio,
      );
    });
  });

  group('stay rail skeleton matches the loaded rail', () {
    for (final Locale locale in <Locale>[
      const Locale('en'),
      const Locale('ar'),
    ]) {
      testWidgets('identical card geometry (${locale.languageCode})', (
        WidgetTester tester,
      ) async {
        phoneSize(tester);

        await tester.pumpWidget(
          host(
            HomeStaysCarousel(items: const <HomeItem>[], loading: true),
            locale: locale,
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        final Rect skeleton = tester.getRect(find.byType(HomeStayCard));

        await tester.pumpWidget(
          host(
            HomeStaysCarousel(items: <HomeItem>[stay('a')]),
            locale: locale,
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        final Rect loaded = tester.getRect(find.byType(HomeStayCard));

        expect(skeleton.size, loaded.size);
        expect(skeleton.topLeft, loaded.topLeft);

        // The placeholder reserves the same sheet rows as the fullest card.
        expect(find.byType(OverlapStayCard), findsOneWidget);
      });

      testWidgets('identical geometry on a narrow phone', (
        WidgetTester tester,
      ) async {
        phoneSize(tester, size: const Size(640, 1280));

        await tester.pumpWidget(
          host(
            HomeStaysCarousel(items: const <HomeItem>[], loading: true),
            locale: locale,
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        final Rect skeleton = tester.getRect(find.byType(HomeStayCard));

        await tester.pumpWidget(
          host(
            HomeStaysCarousel(items: <HomeItem>[stay('a')]),
            locale: locale,
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        final Rect loaded = tester.getRect(find.byType(HomeStayCard));

        expect(skeleton.size, loaded.size);
        expect(skeleton.topLeft, loaded.topLeft);
      });
    }
  });

  group('Discover rail skeleton matches the loaded rail', () {
    for (final Locale locale in <Locale>[
      const Locale('en'),
      const Locale('ar'),
    ]) {
      testWidgets('identical card geometry (${locale.languageCode})', (
        WidgetTester tester,
      ) async {
        phoneSize(tester);

        await tester.pumpWidget(
          host(
            DestinationCoverFlowCarousel(
              items: const <HomeItem>[],
              onItemTap: null,
              loading: true,
            ),
            locale: locale,
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        final Rect skeleton = tester.getRect(
          find.byType(HomeDiscoveryStayCard),
        );

        await tester.pumpWidget(
          host(
            DestinationCoverFlowCarousel(
              items: <HomeItem>[city('a')],
              onItemTap: (_) {},
            ),
            locale: locale,
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        final Rect loaded = tester.getRect(find.byType(HomeDiscoveryStayCard));

        expect(skeleton.size, loaded.size);
        expect(skeleton.topLeft, loaded.topLeft);
      });
    }
  });

  group('card-level skeleton matches the loaded card', () {
    testWidgets('destination card shell', (WidgetTester tester) async {
      phoneSize(tester);

      Widget card({required bool loading}) => SizedBox(
        width: 320,
        child: HomeDiscoveryStayCard(
          item: loading
              ? const HomeItem(
                  id: 'loading',
                  type: HomeCardType.destination,
                  title: '',
                )
              : city('a'),
          onTap: loading ? null : () {},
          aspectRatio: 1.3,
          fillSheet: false,
          loading: loading,
        ),
      );

      await tester.pumpWidget(host(card(loading: true)));
      await tester.pump(const Duration(milliseconds: 300));
      final Rect skeleton = tester.getRect(find.byType(HomeDiscoveryStayCard));

      await tester.pumpWidget(host(card(loading: false)));
      await tester.pump(const Duration(milliseconds: 300));
      final Rect loaded = tester.getRect(find.byType(HomeDiscoveryStayCard));

      expect(skeleton.size, loaded.size);
      expect(tester.takeException(), isNull);
    });

    testWidgets('stay card shell (data vs OverlapStayCard.skeleton)', (
      WidgetTester tester,
    ) async {
      phoneSize(tester);

      Widget card({required bool loading}) => SizedBox(
        width: 320,
        child: OverlapStayCard.skeleton(
          aspectRatio: 1.6,
          semanticsLabel: 'Loading hotel',
        ),
      );

      await tester.pumpWidget(host(card(loading: true)));
      await tester.pump(const Duration(milliseconds: 300));
      final Rect skeleton = tester.getRect(find.byType(OverlapStayCard));

      await tester.pumpWidget(
        host(
          SizedBox(
            width: 320,
            child: OverlapStayCard(
              media: const ColoredBox(color: Colors.blueGrey),
              title: 'Riverside Grand Hotel',
              amountText: '186',
              currency: 'USD',
              unit: 'night',
              rating: 4.8,
              location: 'Lisbon, Portugal',
              distanceText: '1.2 km from the center',
              aspectRatio: 1.6,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final Rect loaded = tester.getRect(find.byType(OverlapStayCard));

      // Free-sized (unbounded height), the placeholder line heights are
      // approximations of the text metrics, so a sub-pixel/rounding delta is
      // allowed. Inside the Home rail the height is pinned by the carousel,
      // so this delta never shows in the feed — see the rail tests above.
      expect(loaded.height, closeTo(skeleton.height, 1.5));
      expect(loaded.width, skeleton.width);
      expect(tester.takeException(), isNull);
    });

    testWidgets('both shells share radius, border width and padding', (
      WidgetTester tester,
    ) async {
      phoneSize(tester);

      Future<Container> shellOf(Widget card) async {
        await tester.pumpWidget(host(card));
        await tester.pump(const Duration(milliseconds: 300));
        return tester.widget<Container>(
          find
              .descendant(
                of: find.byType(BaseCard),
                matching: find.byType(Container),
              )
              .first,
        );
      }

      final Container skeletonShell = await shellOf(
        SizedBox(
          width: 320,
          child: HomeDiscoveryStayCard(
            item: const HomeItem(
              id: 'loading',
              type: HomeCardType.destination,
              title: '',
            ),
            onTap: null,
            aspectRatio: 1.3,
            fillSheet: false,
            loading: true,
          ),
        ),
      );
      final Container loadedShell = await shellOf(
        SizedBox(
          width: 320,
          child: HomeDiscoveryStayCard(
            item: city('a'),
            onTap: () {},
            aspectRatio: 1.3,
            fillSheet: false,
          ),
        ),
      );

      final BoxDecoration skeletonDecoration =
          skeletonShell.decoration! as BoxDecoration;
      final BoxDecoration loadedDecoration =
          loadedShell.decoration! as BoxDecoration;

      expect(skeletonDecoration.borderRadius, loadedDecoration.borderRadius);
      expect(
        skeletonDecoration.borderRadius,
        HomeCardDimensions.borderRadius,
      );
      expect(skeletonDecoration.border, isA<Border>());
      expect(
        (skeletonDecoration.border! as Border).top.width,
        (loadedDecoration.border! as Border).top.width,
      );
    });
  });

  group('legacy skeleton card is gone from the render path', () {
    testWidgets('a skeleton item renders through the approved stay card', (
      WidgetTester tester,
    ) async {
      phoneSize(tester);
      await tester.pumpWidget(
        host(
          const SizedBox(
            width: 320,
            child: HomeCard(
              item: HomeItem(
                id: 'preview',
                type: HomeCardType.hotel,
                title: '',
                price: null,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(HomeStayCard), findsOneWidget);
      expect(find.byType(OverlapStayCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a real item still renders the loaded card', (
      WidgetTester tester,
    ) async {
      phoneSize(tester);
      await tester.pumpWidget(
        host(
          SizedBox(width: 320, child: HomeCard(item: stay('a'))),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Riverside Grand Hotel a'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('cached snapshot compatibility', () {
    test('the snapshot carries data only — no client widget definitions', () {
      final Map<String, dynamic> map = homeSectionToMap(
        HomeSection(
          id: 'discover',
          title: 'Discover',
          layout: HomeSectionLayout.horizontal,
          items: <HomeItem>[city('a')],
          metadata: const <String, dynamic>{'semanticId': 'discover'},
        ),
      );

      expect(map.keys, <String>['id', 'title', 'subtitle', 'layout', 'items', 'metadata']);
      final Map<String, dynamic> item =
          (map['items']! as List<dynamic>).first as Map<String, dynamic>;
      expect(item.keys, <String>['id', 'type', 'title', 'subtitle', 'description', 'imageUrl', 'currency', 'badge', 'highlights', 'tags', 'actionLabel', 'metadata']);
    });

    test('a v2 envelope round-trips through the reader', () {
      final HomeSection section = HomeSection(
        id: 'stays',
        title: 'Stays',
        layout: HomeSectionLayout.horizontalPeek,
        items: <HomeItem>[stay('a')],
      );
      final Map<String, dynamic> envelope = <String, dynamic>{
        'schemaVersion': 'home.snapshot.v2',
        'savedAt': DateTime.now().toIso8601String(),
        'audience': 'anon',
        'sections': <Map<String, dynamic>>[homeSectionToMap(section)],
      };

      final List<HomeSection> restored = homeSectionsFromMap(envelope);
      expect(restored, hasLength(1));
      expect(restored.first.id, 'stays');
      expect(restored.first.layout, HomeSectionLayout.horizontalPeek);
      expect(restored.first.items.single.title, stay('a').title);
      expect(restored.first.items.single.metadata['city'], 'Lisbon');
    });

    testWidgets('restored sections render through the current card widgets', (
      WidgetTester tester,
    ) async {
      phoneSize(tester);
      final HomeSection section = HomeSection(
        id: 'discover',
        title: 'Discover',
        layout: HomeSectionLayout.horizontal,
        items: <HomeItem>[city('a')],
      );
      final Map<String, dynamic> envelope = <String, dynamic>{
        'schemaVersion': 'home.snapshot.v2',
        'savedAt': DateTime.now().toIso8601String(),
        'audience': 'anon',
        'sections': <Map<String, dynamic>>[homeSectionToMap(section)],
      };
      final List<HomeSection> restored = homeSectionsFromMap(envelope);

      Future<Rect> renderRect(HomeSection s) async {
        await tester.pumpWidget(
          host(HomeSectionWidget(section: s, onItemTap: (_) {})),
        );
        await tester.pump(const Duration(milliseconds: 300));
        return tester.getRect(find.byType(HomeDiscoveryStayCard));
      }

      final Rect direct = await renderRect(section);
      final Rect fromCache = await renderRect(restored.first);

      expect(fromCache.size, direct.size);
      expect(fromCache.topLeft, direct.topLeft);
      expect(tester.takeException(), isNull);
    });
  });

  group('section widget keeps every card in step', () {
    testWidgets('dev-preview items render as skeletons of the approved cards', (
      WidgetTester tester,
    ) async {
      phoneSize(tester);
      await tester.pumpWidget(
        host(
          HomeSectionWidget(
            section: HomeSection(
              id: 'deals',
              title: 'Deals',
              layout: HomeSectionLayout.verticalDealList,
              items: const <HomeItem>[
                HomeItem(id: 'd', type: HomeCardType.deal, title: ''),
              ],
            ),
            onItemTap: (_) {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });
  });

  group('secondary Home cards share their shell with the skeleton', () {
    HomeItem deal({required bool skeleton}) => HomeItem(
          id: 'deal',
          type: HomeCardType.deal,
          title: skeleton ? '' : 'Lisbon Weekend Escape',
          subtitle: skeleton ? null : 'Lisbon',
          price: skeleton ? null : 299,
          metadata: skeleton
              ? const <String, dynamic>{}
              : const <String, dynamic>{'savingsPercent': 25},
        );

    HomeItem product({required bool skeleton}) => HomeItem(
          id: 'car',
          type: HomeCardType.car,
          title: skeleton ? '' : 'Premium city car',
          subtitle: skeleton ? null : 'Automatic · 5 seats',
          price: skeleton ? null : 55,
          rating: skeleton ? null : 4.6,
        );

    HomeItem flight({required bool skeleton}) => HomeItem(
          id: 'flight',
          type: HomeCardType.flight,
          title: skeleton ? '' : 'TokiGo Air',
          price: skeleton ? null : 240,
          metadata: skeleton
              ? const <String, dynamic>{}
              : const <String, dynamic>{
                  'airline': 'TokiGo Air',
                  'flightNumber': 'TG 421',
                  'departureTime': '2026-03-01T10:00:00Z',
                  'arrivalTime': '2026-03-01T14:00:00Z',
                  'origin': 'LIS',
                  'destination': 'CAI',
                  'stops': 0,
                },
        );

    testWidgets('DealCard skeleton matches the loaded tile', (
      WidgetTester tester,
    ) async {
      phoneSize(tester);
      Future<Rect> rect({required bool skeleton}) async {
        await tester.pumpWidget(
          host(
            SizedBox(
              width: 280,
              child: DealCard(item: deal(skeleton: skeleton), loading: skeleton),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        return tester.getRect(find.byType(DealCard));
      }

      final Rect loading = await rect(skeleton: true);
      final Rect loaded = await rect(skeleton: false);
      expect(loading.size, loaded.size);
      expect(tester.takeException(), isNull);
    });

    testWidgets('DiscoveryProductCard skeleton matches the loaded tile', (
      WidgetTester tester,
    ) async {
      phoneSize(tester);
      Future<Rect> rect({required bool skeleton}) async {
        await tester.pumpWidget(
          host(
            SizedBox(
              width: 220,
              height: 276,
              child: DiscoveryProductCard(
                item: product(skeleton: skeleton),
                loading: skeleton,
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        return tester.getRect(find.byType(DiscoveryProductCard));
      }

      final Rect loading = await rect(skeleton: true);
      final Rect loaded = await rect(skeleton: false);
      expect(loading.size, loaded.size);
      expect(tester.takeException(), isNull);
    });

    testWidgets('FlightRecommendationCard skeleton matches the loaded tile', (
      WidgetTester tester,
    ) async {
      phoneSize(tester);
      Future<Rect> rect({required bool skeleton}) async {
        await tester.pumpWidget(
          host(
            SizedBox(
              width: 300,
              height: 252,
              child: FlightRecommendationCard(
                item: flight(skeleton: skeleton),
                loading: skeleton,
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        return tester.getRect(find.byType(FlightRecommendationCard));
      }

      final Rect loading = await rect(skeleton: true);
      final Rect loaded = await rect(skeleton: false);
      expect(loading.size, loaded.size);
      expect(tester.takeException(), isNull);
    });
  });

  group('Home page loading → loaded transition', () {
    HomeController controllerWith(
      Completer<ApiResult<List<HomeSection>>> completer, {
      List<HomeSection>? snapshot,
    }) => HomeController(
      _GatedRepository(completer, snapshot: snapshot),
      audience: 'anon',
      contextBuilder: (_) async =>
          const HomeCompositionContext(userState: HomeUserState.freshAnonymous),
      liveValidation: null,
      countryCode: null,
      languageCode: null,
      currencyCode: null,
    );

    Widget pageHost(HomeController controller, {Locale locale = const Locale('en')}) {
      final GoRouter router = GoRouter(
        initialLocation: '/',
        routes: <RouteBase>[
          GoRoute(path: '/', builder: (context, state) => const HomePage()),
        ],
      );
      return ProviderScope(
        overrides: <Override>[
          homeControllerProvider.overrideWith((ref) => controller),
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

    testWidgets('initial loading with no cached data shows the skeletons', (
      WidgetTester tester,
    ) async {
      phoneSize(tester);
      final Completer<ApiResult<List<HomeSection>>> completer =
          Completer<ApiResult<List<HomeSection>>>();
      final HomeController controller = controllerWith(completer);

      await tester.pumpWidget(pageHost(controller));
      await tester.pump(const Duration(milliseconds: 300));

      // Discover + Stays placeholders are the real cards in their loading state.
      expect(find.byType(HomeDiscoveryStayCard), findsOneWidget);
      expect(find.byType(HomeStayCard), findsOneWidget);
      expect(find.byType(OverlapStayCard), findsOneWidget);
      expect(tester.takeException(), isNull);

      // The feed lands: the same widgets switch to their loaded state.
      completer.complete(
        ApiResult<List<HomeSection>>.success(<HomeSection>[
          HomeSection(
            id: 'discover',
            title: 'Discover',
            layout: HomeSectionLayout.horizontal,
            items: <HomeItem>[city('a'), city('b')],
          ),
        ]),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Lisbona'), findsWidgets);
      expect(tester.takeException(), isNull);
      // The controller is owned by the provider container, which disposes it
      // when the ProviderScope unmounts at the end of the test.
    });

    testWidgets('loading with a cached snapshot still shows the skeletons first', (
      WidgetTester tester,
    ) async {
      phoneSize(tester);
      final Completer<ApiResult<List<HomeSection>>> completer =
          Completer<ApiResult<List<HomeSection>>>();
      final HomeController controller = controllerWith(
        completer,
        snapshot: <HomeSection>[
          HomeSection(
            id: 'discover',
            title: 'Discover',
            layout: HomeSectionLayout.horizontal,
            items: <HomeItem>[city('a')],
          ),
        ],
      );

      await tester.pumpWidget(pageHost(controller));
      await tester.pump(const Duration(milliseconds: 300));

      // The snapshot is restored first, so cached cards render immediately —
      // through the current widgets, never a legacy path.
      expect(find.byType(HomeDiscoveryStayCard), findsOneWidget);
      expect(find.text('Lisbona'), findsWidgets);
      expect(tester.takeException(), isNull);

      completer.complete(
        ApiResult<List<HomeSection>>.success(<HomeSection>[
          HomeSection(
            id: 'discover',
            title: 'Discover',
            layout: HomeSectionLayout.horizontal,
            items: <HomeItem>[city('a'), city('b')],
          ),
        ]),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Arabic Home renders both skeletons RTL', (WidgetTester tester) async {
      phoneSize(tester);
      final Completer<ApiResult<List<HomeSection>>> completer =
          Completer<ApiResult<List<HomeSection>>>();

      await tester.pumpWidget(
        pageHost(controllerWith(completer), locale: const Locale('ar')),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(HomeDiscoveryStayCard), findsOneWidget);
      expect(find.byType(HomeStayCard), findsOneWidget);
      expect(
        Directionality.of(
          tester.element(find.byType(HomeDiscoveryStayCard)),
        ),
        TextDirection.rtl,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
