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
import 'package:tokigo/features/home/domain/explore_catalog.dart';
import 'package:tokigo/features/home/domain/explore_catalog_item.dart';
import 'package:tokigo/features/home/domain/explore_home_section.dart';
import 'package:tokigo/features/home/presentation/pages/explore_cities_page.dart';
import 'package:tokigo/features/home/presentation/pages/home_page.dart';
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

  testWidgets('Home renders Explore with no backend feed dependency', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1480);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Home renders the bundled catalog directly; no Home feed is fetched.
    await tester.pumpWidget(_app(const HomePage()));
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

  group('backend merge protection', () {
    HomeItem catalogItem(String id) =>
        exploreCityToHomeItem(exploreCityById(id)!);

    test('matching backend id with no image keeps the bundled photo', () {
      final HomeItem catalog = catalogItem('oslo');
      final HomeItem merged = mergeExploreDestination(
        catalog,
        HomeItem(
          id: 'oslo',
          type: HomeCardType.destination,
          title: 'Oslo',
          imageUrl: null,
        ),
      );
      expect(merged.imageUrl, catalog.imageUrl);
      expect(merged.imageUrl, 'assets/explore/cities/oslo.webp');
    });

    test('matching backend id with an empty image keeps the bundled photo', () {
      final HomeItem catalog = catalogItem('oslo');
      final HomeItem merged = mergeExploreDestination(
        catalog,
        HomeItem(
          id: 'oslo',
          type: HomeCardType.destination,
          title: 'Oslo',
          imageUrl: '',
        ),
      );
      expect(merged.imageUrl, catalog.imageUrl);
    });

    test('matching backend id with a valid bundled image uses it', () {
      final HomeItem merged = mergeExploreDestination(
        catalogItem('oslo'),
        HomeItem(
          id: 'oslo',
          type: HomeCardType.destination,
          title: 'Oslo',
          imageUrl: 'assets/explore/cities/lyon.webp',
        ),
      );
      expect(merged.imageUrl, 'assets/explore/cities/lyon.webp');
    });

    test('a remote backend image is ignored (Explore stays bundled-only)', () {
      final HomeItem catalog = catalogItem('oslo');
      final HomeItem merged = mergeExploreDestination(
        catalog,
        HomeItem(
          id: 'oslo',
          type: HomeCardType.destination,
          title: 'Oslo',
          imageUrl: 'https://example.com/oslo.jpg',
        ),
      );
      expect(merged.imageUrl, catalog.imageUrl);
    });

    test('incomplete backend data does not erase catalog content', () {
      final HomeItem catalog = catalogItem('oslo');
      final HomeItem merged = mergeExploreDestination(
        catalog,
        HomeItem(
          id: 'oslo',
          type: HomeCardType.destination,
          title: '',
          subtitle: '',
          description: '',
          imageUrl: '',
          metadata: const <String, dynamic>{
            'imageCredit': null,
            'imageLicense': '',
          },
        ),
      );
      expect(merged.title, catalog.title);
      expect(merged.subtitle, catalog.subtitle);
      expect(merged.description, catalog.description);
      expect(merged.imageUrl, catalog.imageUrl);
      expect(merged.metadata['imageCredit'], catalog.metadata['imageCredit']);
      expect(merged.metadata['imageLicense'], catalog.metadata['imageLicense']);
    });

    test('valid backend fields override the catalog per field', () {
      final HomeItem catalog = catalogItem('oslo');
      final HomeItem merged = mergeExploreDestination(
        catalog,
        HomeItem(
          id: 'oslo',
          type: HomeCardType.destination,
          title: 'Oslo Updated',
          description: 'A fresh backend description',
          imageUrl: null,
          metadata: const <String, dynamic>{
            'country': 'Norway',
            'region': 'Europe',
          },
        ),
      );
      expect(merged.id, 'oslo');
      expect(merged.title, 'Oslo Updated');
      expect(merged.description, 'A fresh backend description');
      expect(merged.imageUrl, catalog.imageUrl);
      expect(merged.metadata['country'], 'Norway');
      expect(merged.metadata['region'], 'Europe');
    });

    test('duplicate backend destinations collapse into one merged entry', () {
      final HomeSection section = buildAllCitiesSection();
      final HomeItem dup1 = HomeItem(
        id: 'oslo',
        type: HomeCardType.destination,
        title: 'Oslo',
        imageUrl: null,
      );
      final HomeItem dup2 = HomeItem(
        id: 'oslo',
        type: HomeCardType.destination,
        title: 'Oslo',
        imageUrl: 'assets/explore/cities/lyon.webp',
      );
      final HomeSection merged = mergeBackendDestinations(
        section,
        backendDestinations: <HomeItem>[dup1, dup2],
      );
      final List<HomeItem> oslo =
          merged.items.where((HomeItem i) => i.id == 'oslo').toList();
      expect(oslo.length, 1);
      expect(oslo.first.imageUrl, 'assets/explore/cities/lyon.webp');
      expect(merged.items.length, section.items.length);
    });

    test('a backend-only destination is appended', () {
      final HomeSection section = buildAllCitiesSection();
      final int before = section.items.length;
      final HomeSection merged = mergeBackendDestinations(
        section,
        backendDestinations: <HomeItem>[
          HomeItem(
            id: 'bergen',
            type: HomeCardType.destination,
            title: 'Bergen',
            imageUrl: null,
          ),
        ],
      );
      expect(merged.items.length, before + 1);
      expect(merged.items.last.id, 'bergen');
    });

    test('offline catalog is unchanged when there are no backend destinations',
        () {
      final HomeSection section = buildAllCitiesSection();
      final HomeSection merged = mergeBackendDestinations(
        section,
        backendDestinations: const <HomeItem>[],
      );
      expect(merged.items.map((HomeItem i) => i.id),
          section.items.map((HomeItem i) => i.id));
      for (final HomeItem item in merged.items) {
        expect(item.imageUrl, isNotNull);
        expect(item.imageUrl, startsWith('assets/'));
      }
    });
  });

  group('View All chip direction', () {
    testWidgets('RTL places the chip on the trailing edge and opens Explore',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(720, 1480);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_app(const HomePage(), locale: const Locale('ar')));
      await tester.pumpAndSettle();

      expect(
        Directionality.of(tester.element(find.byType(Scaffold).first)),
        TextDirection.rtl,
      );

      final Finder chip = find.text('عرض الكل');
      expect(chip, findsOneWidget);
      final double width =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      // RTL: the trailing chip sits on the LEFT half of the header row.
      expect(tester.getCenter(chip).dx, lessThan(width / 2));

      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(find.byType(ExploreCitiesPage), findsOneWidget);
    });

    testWidgets('LTR keeps the chip on the trailing edge and opens Explore',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(720, 1480);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_app(const HomePage()));
      await tester.pumpAndSettle();

      expect(
        Directionality.of(tester.element(find.byType(Scaffold).first)),
        TextDirection.ltr,
      );

      final Finder chip = find.text('View all');
      expect(chip, findsOneWidget);
      final double width =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      expect(tester.getCenter(chip).dx, greaterThan(width / 2));

      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(find.byType(ExploreCitiesPage), findsOneWidget);
    });
  });
}
