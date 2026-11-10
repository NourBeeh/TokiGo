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
import 'package:tokigo/features/home/domain/home_action.dart';
import 'package:tokigo/features/home/domain/home_composer.dart';
import 'package:tokigo/features/home/presentation/home_controller.dart';
import 'package:tokigo/features/home/presentation/pages/home_page.dart';
import 'package:tokigo/features/home/presentation/widgets/home_top_bar.dart';
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
/// that section pages are standalone pushed pages with their own back control.
Widget _sectionPlaceholder(String name) => Scaffold(
  appBar: AppBar(),
  body: ListView(
    key: const ValueKey<String>('section-content-list'),
    children: <Widget>[
      for (int i = 0; i < 60; i++) ListTile(title: Text('Section: $name $i')),
    ],
  ),
);

/// A router that mirrors the production configuration: Today at '/', every
/// section pushed on top of it, and `/ai-chat` as a root route.
GoRouter _router() {
  return GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (context, state) => const HomePage(),
        routes: <RouteBase>[
          GoRoute(
            path: 'flights',
            builder: (context, state) => _sectionPlaceholder('flights'),
          ),
          GoRoute(
            path: 'hotels',
            builder: (context, state) => _sectionPlaceholder('hotels'),
          ),
          GoRoute(
            path: 'cars',
            builder: (context, state) => _sectionPlaceholder('cars'),
          ),
          GoRoute(
            path: 'packages',
            builder: (context, state) => _sectionPlaceholder('packages'),
          ),
          GoRoute(
            path: 'groups',
            builder: (context, state) => _sectionPlaceholder('groups'),
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
  // 560dp x 700dp: wide enough that all navigation tiles are on screen at
  // once (the fixed-68dp tiles plus gutters need a little over 480dp).
  tester.view.physicalSize = const Size(1120, 1400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Finder _composer() => find.byKey(const ValueKey<String>('home-ai-composer'));

Finder _actionBar() => find.byKey(const ValueKey<String>('home-action-bar'));

Future<void> _tapAction(WidgetTester tester, HomeAction action) async {
  // All tiles are on screen at once at this viewport, so a plain tap is
  // reliable in both LTR and RTL.
  final Finder tile = find.byKey(ValueKey<String>('home-action-${action.id}'));
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Today renders the top bar, AI composer and navigation bar', (
    tester,
  ) async {
    _setPhoneSize(tester);
    await tester.pumpWidget(_app(router: _router()));
    await tester.pumpAndSettle();

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(HomeTopBar), findsOneWidget);
    expect(_composer(), findsOneWidget);
    expect(_actionBar(), findsOneWidget);

    final Rect topBar = tester.getRect(find.byType(HomeTopBar));
    final Rect composer = tester.getRect(_composer());
    final Rect bar = tester.getRect(_actionBar());

    // Owner order: wordmark row → AI composer → navigation tiles.
    expect(composer.top, greaterThanOrEqualTo(topBar.bottom));
    expect(bar.top, greaterThanOrEqualTo(composer.bottom));
  });

  testWidgets('quick actions push their section route', (tester) async {
    _setPhoneSize(tester);
    final GoRouter router = _router();
    await tester.pumpWidget(_app(router: router));
    await tester.pumpAndSettle();

    expect(router.state.matchedLocation, '/');

    await _tapAction(tester, HomeAction.flights);
    expect(router.state.matchedLocation, '/flights');
    expect(find.text('Section: flights 0'), findsOneWidget);
    expect(find.byType(HomePage), findsNothing);
  });

  testWidgets('section pages are standalone: Today chrome is not pinned', (
    tester,
  ) async {
    _setPhoneSize(tester);
    final GoRouter router = _router();
    await tester.pumpWidget(_app(router: router));
    await tester.pumpAndSettle();

    await _tapAction(tester, HomeAction.flights);

    // The wordmark row, composer and navigation tiles live on Today only.
    expect(find.byType(HomeTopBar), findsNothing);
    expect(_composer(), findsNothing);
    expect(_actionBar(), findsNothing);
    expect(router.state.matchedLocation, '/flights');
  });

  testWidgets('the section back control returns to Today', (tester) async {
    _setPhoneSize(tester);
    final GoRouter router = _router();
    await tester.pumpWidget(_app(router: router));
    await tester.pumpAndSettle();

    await _tapAction(tester, HomeAction.flights);
    expect(find.text('Section: flights 0'), findsOneWidget);

    // The pushed section owns a back control; leaving it lands on Today with
    // the chrome restored.
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(router.state.matchedLocation, '/');
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(HomeTopBar), findsOneWidget);
    expect(_composer(), findsOneWidget);
    expect(_actionBar(), findsOneWidget);
  });

  testWidgets('the AI composer stays visible while the feed scrolls', (
    tester,
  ) async {
    _setPhoneSize(tester);
    await tester.pumpWidget(_app(router: _router()));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(_composer(), findsOneWidget);
    // The composer is pinned: it stays fully inside the viewport.
    final Rect viewport = tester.getRect(find.byType(CustomScrollView));
    final Rect composer = tester.getRect(_composer());
    expect(composer.top, greaterThanOrEqualTo(viewport.top));
    expect(composer.bottom, lessThanOrEqualTo(viewport.bottom));
  });

  testWidgets('the Home header scrolls away and the composer stays pinned', (
    tester,
  ) async {
    _setPhoneSize(tester);
    await tester.pumpWidget(_app(router: _router()));
    await tester.pumpAndSettle();

    final Rect topBarBefore = tester.getRect(find.byType(HomeTopBar));
    expect(topBarBefore.bottom, greaterThan(0));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();

    // The wordmark row has scrolled out of view (its sliver is disposed once
    // it leaves the viewport's cache extent)…
    expect(find.byType(HomeTopBar), findsNothing);

    // …while the composer is still fully visible.
    final Rect viewport = tester.getRect(find.byType(CustomScrollView));
    final Rect composer = tester.getRect(_composer());
    expect(composer.top, greaterThanOrEqualTo(viewport.top));
    expect(composer.bottom, lessThanOrEqualTo(viewport.bottom));

    // Scrolling back restores the header.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byType(HomeTopBar)).bottom,
      greaterThan(0),
    );
  });

  testWidgets('the composer stays pinned when the keyboard opens', (
    tester,
  ) async {
    _setPhoneSize(tester);
    final GoRouter router = _router();
    await tester.pumpWidget(_app(router: router));
    await tester.pumpAndSettle();

    final Rect before = tester.getRect(_composer());

    await tester.tap(
      find.byKey(const ValueKey<String>('home-ai-composer-field')),
    );
    await tester.pumpAndSettle();

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();

    // The composer is part of Today's pinned chrome at the top of the page,
    // so the keyboard resize must not move it.
    expect(tester.getRect(_composer()), before);
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

    // Return to Today and submit with the keyboard action.
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

  testWidgets('Arabic Today keeps the composer and RTL navigation bar', (
    tester,
  ) async {
    _setPhoneSize(tester);
    final GoRouter router = _router();
    await tester.pumpWidget(_app(router: router, locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(Directionality.of(tester.element(_composer())), TextDirection.rtl);
    expect(Directionality.of(tester.element(_actionBar())), TextDirection.rtl);

    await _tapAction(tester, HomeAction.flights);
    expect(router.state.matchedLocation, '/flights');
    expect(find.byType(HomePage), findsNothing);
  });
}
