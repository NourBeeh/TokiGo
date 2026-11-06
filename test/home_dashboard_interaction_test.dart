import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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
import 'package:tokigo/features/home/presentation/widgets/home_ai_search_field.dart';
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

  /// Overrides the dashboard sections; null uses the default Discover feed.
  final List<HomeSection>? sections;

  /// Overrides the recommended stays; null uses the default rail.
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

GoRouter _router() {
  return GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(path: '/', builder: (context, state) => const HomePage()),
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
  tester.view.physicalSize = const Size(780, 1400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Finder _content(HomeAction action) =>
    find.byKey(ValueKey<String>('home-${action.id}-content'));

Future<void> _tapAction(WidgetTester tester, HomeAction action) async {
  final Finder tile = find.byKey(ValueKey<String>('home-action-${action.id}'));
  // The quick-action row is a lazy horizontal list: on a phone the later
  // tiles (Activities, Groups, Trips) start off-screen, so bring the target
  // into view before tapping it.
  await tester.scrollUntilVisible(
    tile,
    80,
    scrollable: find.descendant(
      of: find.byKey(const ValueKey<String>('home-action-bar')),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('quick actions switch Home content in place', (tester) async {
    _setPhoneSize(tester);
    final GoRouter router = _router();
    await tester.pumpWidget(_app(router: router));
    await tester.pumpAndSettle();

    // The dashboard is the initial Home surface.
    expect(find.byType(HomePage), findsOneWidget);
    expect(_content(HomeAction.flights), findsNothing);
    expect(router.state.matchedLocation, '/');

    // The quick-action bar no longer carries Trips (owner decision,
    // 2026-11): the bar's tiles are the ones the definitions actually list.
    for (final HomeActionDefinition definition in homeActionDefinitions(
      AppLocalizations.of(tester.element(find.byType(HomePage)))!,
    )) {
      final HomeAction action = definition.action;
      await _tapAction(tester, action);

      // The feature is rendered INSIDE Home: same route, same page.
      expect(_content(action), findsOneWidget);
      expect(find.byType(HomePage), findsOneWidget);
      expect(router.state.matchedLocation, '/');

      // The quick-action row stays available and marks the active tile.
      final SemanticsNode semantics = tester.getSemantics(
        find.byKey(ValueKey<String>('home-action-${action.id}')),
      );
      expect(
        semantics.flagsCollection.isSelected.toBoolOrNull(),
        isTrue,
        reason: '${action.id} tile must read as selected',
      );

      // The persistent AI composer is not replaced by the feature content.
      expect(
        find.byKey(const ValueKey<String>('home-ai-composer')),
        findsOneWidget,
      );
    }

    // Tapping the active action again returns to the dashboard and clears its
    // selected state.
    final HomeAction last = homeActionDefinitions(
      AppLocalizations.of(tester.element(find.byType(HomePage)))!,
    ).last.action;
    await _tapAction(tester, last);
    expect(_content(last), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('home-ai-composer')),
      findsOneWidget,
    );
    expect(router.state.matchedLocation, '/');
    expect(
      tester
          .getSemantics(find.byKey(ValueKey<String>('home-action-${last.id}')))
          .flagsCollection
          .isSelected
          .toBoolOrNull(),
      isFalse,
    );
  });

  testWidgets('the composer and quick-action row keep a fixed size while scrolling', (
    tester,
  ) async {
    _setPhoneSize(tester);
    await tester.pumpWidget(_app(router: _router()));
    await tester.pumpAndSettle();

    final Finder composer = find.byKey(
      const ValueKey<String>('home-ai-composer'),
    );
    final Finder bar = find.byKey(const ValueKey<String>('home-action-bar'));
    final Rect composerBefore = tester.getRect(composer);
    final Rect barBefore = tester.getRect(bar);
    final Size tileBefore = tester.getSize(
      find.byKey(const ValueKey<String>('home-action-flights')),
    );
    expect(find.text('Search destinations, hotels & more'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pumpAndSettle();

    // Nothing about the pinned chrome changes with scroll: same size, same
    // position, same placeholder. There is no compact state any more.
    expect(tester.getRect(composer), composerBefore);
    expect(tester.getRect(bar), barBefore);
    expect(
      tester.getSize(find.byKey(const ValueKey<String>('home-action-flights'))),
      tileBefore,
    );
    expect(find.text('Search destinations, hotels & more'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('home-ai-composer')),
      findsOneWidget,
    );
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

  testWidgets(
    'the quick-action row is pinned under the header and never moves',
    (tester) async {
      _setPhoneSize(tester);
      await tester.pumpWidget(_app(router: _router()));
      await tester.pumpAndSettle();

      final Finder bar = find.byKey(const ValueKey<String>('home-action-bar'));
      final Finder composer = find.byKey(
        const ValueKey<String>('home-ai-composer'),
      );
      expect(bar, findsOneWidget);
      expect(composer, findsOneWidget);

      final Rect barBefore = tester.getRect(bar);
      // The row sits directly under the header, at the very top of the screen,
      // with the scrolling feed starting below it.
      expect(barBefore.top, greaterThan(0));
      expect(
        tester.getRect(find.byType(CustomScrollView)).top,
        greaterThanOrEqualTo(barBefore.bottom),
      );

      // The dashboard is the only vertical scrollable; the pinned row must not
      // move with it.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(tester.getRect(bar), barBefore);
      expect(tester.getRect(composer).bottom, greaterThan(barBefore.bottom));
    },
  );

  testWidgets('the pill floats with no full-width bar and no dead band', (
    tester,
  ) async {
    _setPhoneSize(tester);
    await tester.pumpWidget(_app(router: _router()));
    await tester.pumpAndSettle();

    final Rect pill = tester.getRect(
      find.byKey(const ValueKey<String>('home-ai-composer')),
    );

    // No ANCESTOR of the pill paints a full-width bar behind it (the feed's own
    // card images are ColoredBoxes too, but they scroll beneath the pill — only
    // an ancestor would be a solid bar pinned behind it).
    bool hasColoredBoxAncestor = false;
    tester.element(find.byKey(const ValueKey<String>('home-ai-composer'))).visitAncestorElements(
      (Element ancestor) {
        // Stop at HomePage: above it sit MaterialApp's route-transition
        // ColoredBox and other app-shell boxes that legitimately span the
        // whole screen. Only a box INSIDE Home's own subtree would be a bar
        // pinned behind the pill.
        if (ancestor.widget is HomePage) return false;
        if (ancestor.widget is ColoredBox) hasColoredBoxAncestor = true;
        return true;
      },
    );
    expect(
      hasColoredBoxAncestor,
      isFalse,
      reason: 'the floating pill must have no ColoredBox ancestor',
    );

    // The pill's footprint is reserved ONCE, inside the scrollable, so the
    // feed's viewport runs beneath the pill. If the Expanded still carried the
    // reserve as padding, the feed would stop above the pill and this would
    // fail — that was the old dead-band bug.
    final Rect feed = tester.getRect(find.byType(CustomScrollView));
    expect(feed.bottom, greaterThan(pill.top));

    // …and the reserve is exactly the pill's own footprint (56 pill + 12
    // bottom margin + bottom safe-area inset), not a second copy of it.
    final BuildContext context = tester.element(find.byType(HomePage));
    expect(
      feed.bottom - pill.top,
      56 + 12 + MediaQuery.paddingOf(context).bottom,
    );
  });

  testWidgets('keyboard inset lifts the whole bottom interaction area', (
    tester,
  ) async {
    _setPhoneSize(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(_app(router: _router()));
    await tester.pumpAndSettle();

    final Finder bar = find.byKey(const ValueKey<String>('home-action-bar'));
    final Finder composer = find.byKey(
      const ValueKey<String>('home-ai-composer'),
    );
    final Rect barRect = tester.getRect(bar);
    final Rect composerRect = tester.getRect(composer);

    // 700dp view - 150dp keyboard = 550dp body; the composer keeps its 8dp
    // inner padding and the action bar sits directly above it.
    expect(composerRect.bottom, lessThanOrEqualTo(550));
    expect(barRect.bottom, lessThanOrEqualTo(composerRect.top));
    expect(barRect.top, greaterThan(0));
  });

  testWidgets('Arabic Home keeps the composer and switches content in RTL', (
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
      find.byKey(const ValueKey<String>('home-ai-composer')),
      findsOneWidget,
    );
    expect(
      Directionality.of(
        tester.element(find.byKey(const ValueKey<String>('home-action-bar'))),
      ),
      TextDirection.rtl,
    );

    await _tapAction(tester, HomeAction.flights);
    expect(_content(HomeAction.flights), findsOneWidget);
    expect(router.state.matchedLocation, '/');
  });
}
