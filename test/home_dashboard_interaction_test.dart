import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/app/shell.dart';
import 'package:tokigo/app/widgets/home_nav_buttons.dart';
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

/// A stand-in for a section route: a long scrolling list so tests can drive
/// the scroll-direction hiding of the floating composer.
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

/// The shell's floating composer, identified by its [IgnorePointer] key.
Finder _composer() => find.byKey(const ValueKey<String>('shell-ai-composer'));

/// The [AnimatedOpacity] that hides/reveals the floating composer.
Finder _composerOpacity() =>
    find.byKey(const ValueKey<String>('shell-composer-opacity'));

double _composerOpacityOf(WidgetTester tester) =>
    tester.widget<AnimatedOpacity>(_composerOpacity()).opacity;

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

    // Back to the dashboard through the Today tile.
    await _tapAction(tester, HomeAction.today);
    expect(router.state.matchedLocation, '/');
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.text('Section: flights 0'), findsNothing);
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
    // TokiGo row + the navigation row stay pinned; the composer floats above
    // every section.
    expect(find.byKey(const ValueKey<String>('home-ai-composer')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('home-action-bar')), findsOneWidget);
    expect(router.state.matchedLocation, '/flights');
  });

  testWidgets('the composer hides on scroll-down and shows on scroll-up', (
    tester,
  ) async {
    _setPhoneSize(tester);
    final GoRouter router = _router();
    await tester.pumpWidget(_app(router: router));
    await tester.pumpAndSettle();

    expect(_composerOpacityOf(tester), 1);

    // Six sections: the feed may not scroll, so drive the same behaviour on a
    // section route with an overflowing list.
    await _tapAction(tester, HomeAction.flights);
    expect(_composerOpacityOf(tester), 1);

    // Scroll down: the pill slides away and fades out.
    await _scrollList(tester, -600);
    expect(_composerOpacityOf(tester), 0);

    // Scroll up: it comes back.
    await _scrollList(tester, 600);
    expect(_composerOpacityOf(tester), 1);
  });

  testWidgets('the composer is visible at the top even while scrolling down', (
    tester,
  ) async {
    _setPhoneSize(tester);
    final GoRouter router = _router();
    await tester.pumpWidget(_app(router: router));
    await tester.pumpAndSettle();

    await _tapAction(tester, HomeAction.flights);
    // A tiny downward nudge does not hide the pill: it only hides once the
    // user has clearly scrolled away.
    await _scrollList(tester, -8);
    expect(_composerOpacityOf(tester), 1);
  });

  testWidgets('the chrome stays pinned and the pill floats while scrolling', (
    tester,
  ) async {
    _setPhoneSize(tester);
    final GoRouter router = _router();
    await tester.pumpWidget(_app(router: router));
    await tester.pumpAndSettle();

    final Finder bar = find.byKey(const ValueKey<String>('home-action-bar'));
    expect(bar, findsOneWidget);
    expect(_composer(), findsOneWidget);

    final Rect barBefore = tester.getRect(bar);
    expect(barBefore.top, greaterThan(0));

    await _tapAction(tester, HomeAction.flights);
    expect(
      tester.getRect(
        find.byKey(const ValueKey<String>('section-content-list')),
      ).top,
      greaterThanOrEqualTo(barBefore.bottom),
    );

    await _scrollList(tester, -600);

    // The pinned chrome does not move; the pill itself slides away.
    expect(tester.getRect(bar), barBefore);
    expect(_composerOpacityOf(tester), 0);
  });

  testWidgets('the composer floats with no full-width bar and no dead band', (
    tester,
  ) async {
    _setPhoneSize(tester);
    await tester.pumpWidget(_app(router: _router()));
    await tester.pumpAndSettle();

    final Finder pillFinder = find.byKey(
      const ValueKey<String>('home-ai-composer'),
    );
    final Rect pill = tester.getRect(pillFinder);

    // No ANCESTOR of the pill paints a full-width bar behind it. Stop at the
    // shell; above it may sit MaterialApp transition boxes.
    bool hasColoredBoxAncestor = false;
    tester.element(pillFinder).visitAncestorElements((Element ancestor) {
      if (ancestor.widget is TokiGoShell) return false;
      if (ancestor.widget is ColoredBox) hasColoredBoxAncestor = true;
      return true;
    });
    expect(
      hasColoredBoxAncestor,
      isFalse,
      reason: 'the floating pill must have no ColoredBox ancestor',
    );

    final Rect feed = tester.getRect(find.byType(CustomScrollView));
    expect(feed.bottom, greaterThan(pill.top));
  });

  testWidgets('keyboard inset forces the floating composer visible', (
    tester,
  ) async {
    _setPhoneSize(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(_app(router: _router()));
    await tester.pumpAndSettle();

    final Rect composerRect = tester.getRect(
      find.byKey(const ValueKey<String>('home-ai-composer')),
    );
    // The whole bottom interaction area rides above the keyboard.
    expect(composerRect.bottom, lessThanOrEqualTo(550));
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

  testWidgets('the composer keeps clear of the system navigation inset', (
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
    // 700dp tall view - 34dp system inset - 12dp gap under the floating pill.
    expect(composer.bottom, closeTo(654, 1));
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

    await _tapAction(tester, HomeAction.today);
    expect(router.state.matchedLocation, '/');
    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('Today tile is the first navigation tile and reads as selected', (
    tester,
  ) async {
    _setPhoneSize(tester);
    final GoRouter router = _router();
    await tester.pumpWidget(_app(router: router));
    await tester.pumpAndSettle();

    // Today reads as the selected section while on `/`.
    expect(
      _selectedOf(tester, HomeAction.today),
      isTrue,
      reason: 'the Today tile must read as selected on /',
    );

    await _tapAction(tester, HomeAction.activities);
    expect(router.state.matchedLocation, '/packages');
    // Today is no longer the active tile.
    expect(_selectedOf(tester, HomeAction.today), isFalse);
  });
}
