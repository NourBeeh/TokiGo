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
import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/features/home/domain/explore_catalog.dart';
import 'package:tokigo/features/home/presentation/home_controller.dart';
import 'package:tokigo/features/home/presentation/pages/explore_cities_page.dart';
import 'package:tokigo/features/home/presentation/pages/home_page.dart';
import 'package:tokigo/features/home/presentation/widgets/home_section.dart';
import 'package:tokigo/features/home/providers/home_providers.dart';
import 'package:tokigo/l10n/app_localizations.dart';

Widget _app(Widget child, {Locale locale = const Locale('en')}) {
  final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(path: '/', builder: (context, state) => child),
      GoRoute(
        path: '/explore',
        builder: (context, state) => const ExploreCitiesPage(),
      ),
      GoRoute(
        path: '/city',
        builder: (context, state) => Scaffold(
          body: Text('City opened: ${(state.extra as HomeItem).title}'),
        ),
      ),
    ],
  );
  return ProviderScope(
    overrides: <Override>[
      homeControllerProvider.overrideWith((ref) => _TestHomeController()),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
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
  testWidgets('Home renders the curated Explore rail and opens View All', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1480);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(const HomePage()));
    await tester.pumpAndSettle();

    // The section heading is the localized 'Explore'.
    expect(find.text('Explore'), findsWidgets);

    // Only the curated subset is on Home. The cover-flow rail virtualizes its
    // pages, so swipe through it and collect every city name that renders.
    final Set<String> allNames =
        kExploreCities.map((ExploreCity c) => c.name).toSet();
    final Set<String> seen = <String>{};
    for (int i = 0; i < curatedHomeCityIds.length + 2; i++) {
      for (final Text t in tester.widgetList<Text>(find.byType(Text))) {
        final String data = t.data ?? '';
        if (allNames.contains(data)) seen.add(data);
      }
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();
    }
    expect(seen, curatedHomeCities.map((ExploreCity c) => c.name).toSet(),
        reason: 'Home must show exactly the curated cities');

    // View All opens the existing destinations page, expanded.
    // The section's view-all affordance is a small chip labelled 'View all'.
    await tester.tap(find.text('View all'));
    await tester.pumpAndSettle();
    expect(find.byType(ExploreCitiesPage), findsOneWidget);
  });

  testWidgets('View All exposes the complete destination catalog', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1480);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(const ExploreCitiesPage()));
    await tester.pumpAndSettle();

    // The expanded catalog is rendered as grid tiles. The grid virtualizes, so
    // scroll through it and collect every city name that appears.
    final Set<String> seen = <String>{};
    for (int i = 0; i < 40; i++) {
      for (final Text t in tester.widgetList<Text>(find.byType(Text))) {
        final String data = t.data ?? '';
        if (kExploreCities.any((ExploreCity c) => c.name == data)) seen.add(data);
      }
      await tester.drag(find.byType(GridView), const Offset(0, -600));
      await tester.pumpAndSettle();
    }
    final Set<String> all =
        kExploreCities.map((ExploreCity c) => c.name).toSet();
    expect(seen, all,
        reason: 'View All must expose every catalog city');
  });

  testWidgets('Home drops every backend section except Explore and Stays', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1480);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // The backend's real seeded sections, by title.
    final List<HomeSection> backend = <HomeSection>[
      HomeSection(
        id: 'recommended',
        title: 'Recommended for you',
        layout: HomeSectionLayout.horizontalPeek,
        items: <HomeItem>[
          HomeItem(
            id: 'h1',
            type: HomeCardType.hotel,
            title: 'Grand Palm Hotel',
            subtitle: 'Paris, France',
            price: 320,
            currency: 'USD',
          ),
        ],
      ),
      HomeSection(
        id: 'trending',
        title: 'Trending destinations',
        layout: HomeSectionLayout.grid,
        items: <HomeItem>[
          HomeItem(
            id: 'istanbul',
            type: HomeCardType.destination,
            title: 'Istanbul',
            subtitle: 'Turkey',
          ),
        ],
      ),
      HomeSection(
        id: 'packages',
        title: 'Tour packages',
        layout: HomeSectionLayout.horizontal,
        items: <HomeItem>[
          HomeItem(
            id: 'p1',
            type: HomeCardType.package,
            title: 'Sharm El Sheikh · 5 days',
            price: 599,
            currency: 'USD',
          ),
        ],
      ),
      HomeSection(
        id: 'experiences',
        title: 'Experiences & stories',
        layout: HomeSectionLayout.vertical,
        items: <HomeItem>[
          HomeItem(
            id: 'e1',
            type: HomeCardType.deal,
            title: 'Sunset felucca ride',
            price: 25,
            currency: 'USD',
          ),
        ],
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          homeControllerProvider.overrideWith((ref) => _TestHomeController(backend)),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const HomePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Only Explore survives; the destination card is merged into it.
    expect(find.text('Explore'), findsWidgets);
    // Exactly ONE section renders, and it carries the backend destination.
    final HomeSectionWidget section = tester.widget<HomeSectionWidget>(
      find.byType(HomeSectionWidget),
    );
    expect(find.byType(HomeSectionWidget), findsOneWidget);
    expect(section.section.items.map((HomeItem i) => i.id), contains('istanbul'));
    expect(find.text('Tour packages'), findsNothing);
    expect(find.text('Experiences & stories'), findsNothing);
    expect(find.text('Recommended for you'), findsNothing);
    expect(find.text('Sharm El Sheikh · 5 days'), findsNothing);
    expect(find.text('Sunset felucca ride'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a FAILED feed still renders Explore (offline launch)', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1480);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Backend unreachable — the worst case for a first offline launch.
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          homeControllerProvider.overrideWith(
            (ref) => _TestHomeController(const <HomeSection>[], true),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const HomePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Explore'), findsWidgets);
    expect(find.text('Paris'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Arabic renders the section title and RTL', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1480);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(const HomePage(), locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(Directionality.of(tester.element(find.byType(Scaffold).first)),
        TextDirection.rtl);
    expect(find.text('استكشف'), findsWidgets);
  });
}

class _TestHomeController extends HomeController {
  _TestHomeController([
    List<HomeSection> sections = const <HomeSection>[],
    bool failFeed = false,
  ]) : super(_TestHomeRepository(sections, failFeed));
}

class _TestHomeRepository implements HomeRepository {
  _TestHomeRepository([
    this.sections = const <HomeSection>[],
    this.failFeed = false,
  ]);

  final List<HomeSection> sections;
  final bool failFeed;

  @override
  Future<ApiResult<List<HomeSection>>> getHomeSections() async => failFeed
      ? const ApiResult<List<HomeSection>>.failure(
          ApiNetworkError(message: 'offline'),
        )
      : ApiResult<List<HomeSection>>.success(sections);

  @override
  Future<ApiResult<List<HomeItem>>> getRecommendedHotels({
    int limit = 6,
    String? countryCode,
    String languageCode = 'en',
    String? currency,
  }) async => const ApiResult<List<HomeItem>>.success(<HomeItem>[]);

  @override
  Future<ApiResult<void>> refresh() async =>
      const ApiResult<void>.success(null);

  @override
  Future<List<HomeSection>?> readHomeSnapshot({required String audience}) async =>
      null;

  @override
  Future<void> clearHomeSnapshot({required String audience}) async {}

  @override
  Future<void> saveHomeSnapshot(List<HomeSection> sections,
      {required String audience}) async {}

  @override
  Future<SnapshotState> snapshotState({required String audience}) async =>
      SnapshotState.fresh;
}
