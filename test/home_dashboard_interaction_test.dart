import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/app/shell.dart';
import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_section.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/core/repositories/contracts/home_repository.dart';
import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/features/home/domain/home_action.dart';
import 'package:tokigo/features/home/domain/home_composer.dart';
import 'package:tokigo/features/home/presentation/home_controller.dart';
import 'package:tokigo/features/home/presentation/pages/home_page.dart';
import 'package:tokigo/features/home/providers/home_providers.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Dashboard data that is tall enough to scroll but needs no network images.
List<HomeSection> _sections() => <HomeSection>[
  HomeSection(
    id: 'discover',
    title: 'Discover',
    layout: HomeSectionLayout.grid,
    items: const <HomeItem>[
      HomeItem(
        id: 'cairo',
        type: HomeCardType.destination,
        title: 'Cairo',
        subtitle: 'Egypt',
      ),
    ],
  ),
];

List<HomeItem> _recommendedHotels() => const <HomeItem>[
  HomeItem(
    id: 'hotel-1',
    type: HomeCardType.hotel,
    title: 'Nile Hotel',
    subtitle: 'Cairo, Egypt',
    price: 2400,
    currency: 'EGP',
  ),
  HomeItem(
    id: 'hotel-2',
    type: HomeCardType.hotel,
    title: 'Desert Palm',
    subtitle: 'Luxor, Egypt',
    price: 1800,
    currency: 'EGP',
  ),
];

/// A repository that serves the dashboard without a real HTTP request.
class _DashboardRepository implements HomeRepository {
  _DashboardRepository({this.sections, this.hotels});

  final List<HomeSection>? sections;
  final List<HomeItem>? hotels;

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
  Future<ApiResult<List<HomeSection>>> getHomeSections() async =>
      ApiResult<List<HomeSection>>.success(sections ?? _sections());

  @override
  Future<ApiResult<List<HomeItem>>> getRecommendedHotels({
    int limit = 6,
    String? countryCode,
    String languageCode = 'en',
    String? currency,
  }) async => ApiResult<List<HomeItem>>.success(hotels ?? _recommendedHotels());

  @override
  Future<ApiResult<void>> refresh() async =>
      const ApiResult<void>.success(null);

  @override
  Future<SnapshotState> snapshotState({required String audience}) async =>
      SnapshotState.unavailable;
}

HomeController _controller({
  List<HomeSection>? sections,
  List<HomeItem>? hotels,
}) => HomeController(
  _DashboardRepository(sections: sections, hotels: hotels),
  audience: 'anon',
  contextBuilder: (_) async =>
      const HomeCompositionContext(userState: HomeUserState.freshAnonymous),
  liveValidation: null,
  countryCode: null,
  languageCode: null,
  currencyCode: null,
);

Widget _app({
  required GoRouter router,
  Locale locale = const Locale('en'),
  HomeController? controller,
}) {
  return ProviderScope(
    overrides: [
      homeControllerProvider.overrideWith((ref) => controller ?? _controller()),
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

/// A stand-in for a section route: a long scrolling list so tests can verify
/// that the pinned chrome and composer never move.
Widget _sectionPlaceholder(String name) => Scaffold(
  body: ListView(
    key: const ValueKey<String>('section-content-list'),
    children: <Widget>[
      for (int i = 0; i < 60; i++) ListTile(title: Text('Section: $name $i')),
    ],
  ),
);

/// A router that mirrors the production shell configuration: the six
/// top-level sections under the same `/` branch, plus `/ai-chat` outside the
/// shell.
GoRouter _router() {
  return GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => TokiGoShell(
          navigationShell: navigationShell,
          location: state.matchedLocation,
        ),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/',
                builder: (context, state) => const HomePage(),
              ),
              GoRoute(
                path: '/flights',
                builder: (context, state) =>
                    _sectionPlaceholder('flights'),
              ),
              GoRoute(
                path: '/hotels',
                builder: (context, state) => _sectionPlaceholder('hotels'),
              ),
              GoRoute(
                path: '/cars',
                builder: (context, state) => _sectionPlaceholder('cars'),
              ),
              GoRoute(
                path: '/packages',
                builder: (context, state) => _sectionPlaceholder('packages'),
              ),
              GoRoute(
                path: '/groups',
                builder: (context, state) => _sectionPlaceholder('groups'),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/ai-chat',
        builder: (context, state) {
          final Object? extra = state.extra;
          return Scaffold(body: Text(extra == null ? 'AI:empty' : 'AI:$extra'));
        },
      ),
    ],
  );
}

void _setPhoneSize(WidgetTester tester) {
  // 560dp x 700dp: wide enough that all six navigation tiles are on screen at
  // once (the fixed-68dp tiles plus gutters need a little over 480dp).
  tester.view.physicalSize = const Size(1120, 1400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _scrollList(WidgetTester tester, double offset) async {
  await tester.drag(
    find.byKey(const ValueKey<String>('section-content-list')),
    Offset(0, offset),
  );
  await tester.pumpAndSettle();
}

/// The selected state carried by the tile's [Semantics] annotation.
bool _selectedOf(WidgetTester tester, HomeAction action) {
  Semantics? found;
  tester
      .element(find.byKey(ValueKey<String>('home-action-${action.id}')))
      .visitAncestorElements((Element ancestor) {
        if (ancestor.widget is Semantics) {
          found = ancestor.widget as Semantics;
          return false;
        }
        return true;
      });
  return found?.properties.selected ?? false;
}

Future<void> _tapAction(WidgetTester tester, HomeAction action) async {
  // All six tiles are on screen at once at this viewport, so a plain tap is
  // reliable in both LTR and RTL.
  final Finder tile = find.byKey(ValueKey<String>('home-action-${action.id}'));
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('quick actions navigate to their section route', (tester) async {
    _setPhoneSize(tester);
    final GoRouter router = _router();
    await tester.pumpWidget(_app(router: router));
    await tester.pumpAndSettle();

    // The dashboard is the initial Home surface.
    expect(find.byType(HomePage), findsOneWidget);
    expect(router.state.matchedLocation, '/');

    await _tapAction(tester, HomeAction.flights);
    expect(router.state.matchedLocation, '/flights');
    expect(find.text('Section: flights 0'), findsOneWidget);
    expect(find.byType(HomePage), findsNothing);

    await _tapAction(tester, HomeAction.hotels);
    expect(router.state.matchedLocation, '/hotels');
    expect(find.text('Section: hotels 0'), findsOneWidget);

    // Tapping a section navigates; the dashboard itself has no tile any more,
    // so '/' is reached only through app navigation (back or deep links).
    expect(find.byKey(const ValueKey<String>('home-action-today')), findsNothing);
  });

  testWidgets('tapping the active section tile is a no-op', (tester) async {
    _setPhoneSize(tester);
    final GoRouter router = _router();
    await tester.pumpWidget(_app(router: router));
    await tester.pumpAndSettle();

    await _tapAction(tester, HomeAction.flights);
    expect(router.state.matchedLocation, '/flights');

    // Tapping the same tile again stays on the section and never stacks a
    // duplicate route.
    await _tapAction(tester, HomeAction.flights);
    expect(router.state.matchedLocation, '/flights');
    expect(find.text('Section: flights 0'), findsOneWidget);
  });

  testWidgets('the section pages render the persistent chrome and composer', (
    tester,
  ) async {
    _setPhoneSize(tester);
    final GoRouter router = _router();
    await tester.pumpWidget(_app(router: router));
    await tester.pumpAndSettle();

    await _tapAction(tester, HomeAction.flights);
    // TokiGo row + the navigation row + the AI composer stay pinned above
    // every section.
    expect(find.byKey(const ValueKey<String>('home-ai-composer')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('home-action-bar')), findsOneWidget);
    expect(router.state.matchedLocation, '/flights');
  });

  testWidgets('the AI composer stays visible while scrolling', (
    tester,
  ) async {
    _setPhoneSize(tester);
    final GoRouter router = _router();
    await tester.pumpWidget(_app(router: router));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('home-ai-composer')), findsOneWidget);

    // A section with an overflowing list: the composer never moves, even
    // after scrolling down and back up.
    await _tapAction(tester, HomeAction.flights);
    await _scrollList(tester, -600);
    expect(find.byKey(const ValueKey<String>('home-ai-composer')), findsOneWidget);

    await _scrollList(tester, 600);
    expect(find.byKey(const ValueKey<String>('home-ai-composer')), findsOneWidget);
  });

  testWidgets('the chrome and composer stay pinned while scrolling', (
    tester,
  ) async {
    _setPhoneSize(tester);
    final GoRouter router = _router();
    await tester.pumpWidget(_app(router: router));
    await tester.pumpAndSettle();

    final Finder bar = find.byKey(const ValueKey<String>('home-action-bar'));
    final Finder composer = find.byKey(
      const ValueKey<String>('home-ai-composer'),
    );
    expect(bar, findsOneWidget);
    expect(composer, findsOneWidget);

    final Rect barBefore = tester.getRect(bar);
    final Rect composerBefore = tester.getRect(composer);
    expect(barBefore.top, greaterThan(0));

    await _tapAction(tester, HomeAction.flights);
    expect(
      tester.getRect(
        find.byKey(const ValueKey<String>('section-content-list')),
      ).top,
      greaterThanOrEqualTo(barBefore.bottom),
    );

    await _scrollList(tester, -600);

    // The pinned chrome does not move; the composer stays with it.
    expect(tester.getRect(bar), barBefore);
    expect(tester.getRect(composer), composerBefore);
  });

  testWidgets('the composer sits under the navigation bar, above the feed', (
    tester,
  ) async {
    _setPhoneSize(tester);
    await tester.pumpWidget(_app(router: _router()));
    await tester.pumpAndSettle();

    final Finder pillFinder = find.byKey(
      const ValueKey<String>('home-ai-composer'),
    );
    final Rect pill = tester.getRect(pillFinder);
    final Rect bar = tester.getRect(
      find.byKey(const ValueKey<String>('home-action-bar')),
    );
    final Rect feed = tester.getRect(find.byType(CustomScrollView));

    // The composer is part of the pinned chrome: directly below the navigation
    // tiles and above the scrolling feed (no overlap, no dead band).
    expect(pill.top, greaterThanOrEqualTo(bar.bottom));
    expect(pill.bottom, lessThanOrEqualTo(feed.top));
  });

  testWidgets('the composer stays pinned in the chrome when the keyboard opens', (
    tester,
  ) async {
    _setPhoneSize(tester);
    final GoRouter router = _router();
    await tester.pumpWidget(_app(router: router));
    await tester.pumpAndSettle();

    final Finder composerFinder = find.byKey(
      const ValueKey<String>('home-ai-composer'),
    );
    final Rect before = tester.getRect(composerFinder);

    await tester.tap(
      find.byKey(const ValueKey<String>('home-ai-composer-field')),
    );
    await tester.pumpAndSettle();

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();

    // The composer lives in the pinned top chrome, so the keyboard resize must
    // not move it.
    expect(tester.getRect(composerFinder), before);
  });

  testWidgets('send submits the trimmed query through the AI chat route', (
    tester,
  ) async {
    _setPhoneSize(tester);
    final GoRouter router = _router();
    await tester.pumpWidget(_app(router: router));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('home-ai-composer-field')),
      '  find me a hotel  ',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('home-ai-composer-send')),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI:find me a hotel'), findsOneWidget);
    expect(router.state.matchedLocation, '/ai-chat');
  });

  testWidgets('the keyboard send action also submits and ignores empty input', (
    tester,
  ) async {
    _setPhoneSize(tester);
    final GoRouter router = _router();
    await tester.pumpWidget(_app(router: router));
    await tester.pumpAndSettle();

    // Empty input opens the chat without submitting an empty message.
    await tester.tap(
      find.byKey(const ValueKey<String>('home-ai-composer-send')),
    );
    await tester.pumpAndSettle();
    expect(find.text('AI:empty'), findsOneWidget);

    // Return to Home and submit with the keyboard action.
    router.pop();
    await tester.pumpAndSettle();

    final Finder field = find.byKey(
      const ValueKey<String>('home-ai-composer-field'),
    );
    await tester.enterText(field, 'weekend in Cairo');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(find.text('AI:weekend in Cairo'), findsOneWidget);
  });

  testWidgets('the composer sits under the navigation bar with a bottom inset', (
    tester,
  ) async {
    _setPhoneSize(tester);
    tester.view.padding = const FakeViewPadding(bottom: 68);
    addTearDown(tester.view.resetPadding);

    await tester.pumpWidget(_app(router: _router()));
    await tester.pumpAndSettle();

    final Rect composer = tester.getRect(
      find.byKey(const ValueKey<String>('home-ai-composer')),
    );
    final Rect bar = tester.getRect(
      find.byKey(const ValueKey<String>('home-action-bar')),
    );
    // The composer is pinned under the navigation tiles; the bottom system
    // inset belongs to the feed, not to the top chrome.
    expect(composer.top, greaterThanOrEqualTo(bar.bottom));
    expect(composer.bottom, lessThan(400));
  });

  testWidgets('Arabic shell keeps the composer and RTL navigation bar', (
    tester,
  ) async {
    _setPhoneSize(tester);
    final GoRouter router = _router();
    await tester.pumpWidget(_app(router: router, locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(
      Directionality.of(
        tester.element(find.byKey(const ValueKey<String>('home-ai-composer'))),
      ),
      TextDirection.rtl,
    );
    expect(
      Directionality.of(
        tester.element(find.byKey(const ValueKey<String>('home-action-bar'))),
      ),
      TextDirection.rtl,
    );

    await _tapAction(tester, HomeAction.flights);
    expect(router.state.matchedLocation, '/flights');
    expect(find.byType(HomePage), findsNothing);

    // No Today tile any more — the user returns to Home via back navigation.
    expect(find.byKey(const ValueKey<String>('home-action-today')), findsNothing);
  });

  testWidgets('Home shows no active tile and the section route selects its own', (
    tester,
  ) async {
    _setPhoneSize(tester);
    final GoRouter router = _router();
    await tester.pumpWidget(_app(router: router));
    await tester.pumpAndSettle();

    // `/` has no tile of its own any more — nothing reads as selected.
    expect(_selectedOf(tester, HomeAction.flights), isFalse);

    await _tapAction(tester, HomeAction.activities);
    expect(router.state.matchedLocation, '/packages');
    // The packages route marks its own Activities tile as selected.
    expect(_selectedOf(tester, HomeAction.activities), isTrue);
    expect(_selectedOf(tester, HomeAction.flights), isFalse);
  });
}
