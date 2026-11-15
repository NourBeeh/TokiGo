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
import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/features/home/presentation/home_controller.dart';
import 'package:tokigo/features/home/presentation/pages/explore_cities_page.dart';
import 'package:tokigo/features/home/providers/home_providers.dart';
import 'package:tokigo/l10n/app_localizations.dart';

HomeItem _city(
  String id,
  String title, {
  String country = 'Norway',
  List<String> tags = const <String>[],
  Map<String, dynamic> metadata = const <String, dynamic>{},
}) => HomeItem(
  id: id,
  type: HomeCardType.destination,
  title: title,
  imageUrl: null,
  tags: tags,
  metadata: <String, dynamic>{'country': country, ...metadata},
);

HomeSection _section(List<HomeItem> items) => HomeSection(
  id: 'discover',
  title: 'Discover',
  layout: HomeSectionLayout.grid,
  items: items,
);

void main() {
  final List<HomeItem> cities = <HomeItem>[
    _city(
      'oslo',
      'Oslo',
      tags: const <String>['city', 'families'],
      metadata: const <String, dynamic>{
        'country': 'Norway',
        'moods': <String>['city'],
        'audiences': <String>['families'],
      },
    ),
    _city(
      'bergen',
      'Bergen',
      tags: const <String>['nature', 'honeymoon'],
      metadata: const <String, dynamic>{
        'country': 'Norway',
        'moods': <String>['nature'],
        'audiences': <String>['honeymoon'],
      },
    ),
    _city('cairo', 'Cairo', country: 'Egypt'),
    HomeItem(id: 'hotel', type: HomeCardType.hotel, title: 'Hotel'),
  ];

  test(
    'collects unique destination cards and filters by query and metadata',
    () {
      final List<HomeItem> collected = discoverCitiesFromSections(<HomeSection>[
        _section(cities),
        _section(<HomeItem>[cities.first]),
      ]);

      expect(collected.map((HomeItem item) => item.id), <String>[
        'oslo',
        'bergen',
        'cairo',
      ]);
      expect(
        filterDiscoverCities(
          collected,
          query: 'norway',
          filter: ExploreCityFilter.all,
        ).map((HomeItem item) => item.id),
        <String>['oslo', 'bergen'],
      );
      expect(
        filterDiscoverCities(
          collected,
          query: '',
          filter: ExploreCityFilter.families,
        ).map((HomeItem item) => item.id),
        <String>['oslo'],
      );
      expect(
        filterDiscoverCities(
          collected,
          query: '',
          filter: ExploreCityFilter.nature,
        ).map((HomeItem item) => item.id),
        <String>['bergen'],
      );
    },
  );

  testWidgets('Explore searches and opens a city from the Discover data', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1480);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final GoRouter router = GoRouter(
      initialLocation: '/explore',
      routes: <RouteBase>[
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
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          homeControllerProvider.overrideWith(
            (ref) => _TestHomeController(<HomeSection>[_section(cities)]),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
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
    await tester.pumpAndSettle();

    // The Explore page now renders the bundled catalog as well as the
    // backend's Discover cards, so the grid virtualizes and the backend
    // entries sit far down the list. Search is what makes them reachable.
    //
    // 'Bergen' exists ONLY in the injected backend data (not in the catalog),
    // so it proves backend destinations survive the merge.
    await tester.enterText(find.byType(TextField), 'Bergen');
    await tester.pumpAndSettle();
    // The search field's own EditableText also matches, so assert on the tile.
    expect(find.byKey(const ValueKey<String>('explore-city-bergen')),
        findsOneWidget);
    // A catalog city is filtered out by the same query.
    expect(find.text('Cairo'), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('explore-city-bergen')));
    await tester.pumpAndSettle();
    expect(find.text('City opened: Bergen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _TestHomeController extends HomeController {
  _TestHomeController(List<HomeSection> sections)
    : super(_TestHomeRepository(sections));
}

class _TestHomeRepository implements HomeRepository {
  _TestHomeRepository(this.sections);

  final List<HomeSection> sections;

  @override
  Future<ApiResult<List<HomeSection>>> getHomeSections() async =>
      ApiResult<List<HomeSection>>.success(sections);

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
  Future<List<HomeSection>?> readHomeSnapshot({
    required String audience,
  }) async => null;

  @override
  Future<void> clearHomeSnapshot({required String audience}) async {}

  @override
  Future<void> saveHomeSnapshot(
    List<HomeSection> sections, {
    required String audience,
  }) async {}

  @override
  Future<SnapshotState> snapshotState({required String audience}) async =>
      SnapshotState.fresh;
}
