import 'package:flutter/material.dart';
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
import 'package:tokigo/features/home/domain/home_composer.dart';
import 'package:tokigo/features/home/presentation/home_controller.dart';
import 'package:tokigo/features/home/presentation/pages/home_page.dart';
import 'package:tokigo/features/home/presentation/widgets/home_top_bar.dart';
import 'package:tokigo/features/home/providers/home_providers.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Home header scroll architecture (owner decision, 2026-11).
///
/// The ORIGINAL header — wordmark, AI composer and navigation rail — is part
/// of the scrollable page content and leaves the viewport naturally. The
/// secondary compact search overlay was removed (owner request, 2026-11), so
/// nothing is pinned above the feed while scrolling.
///
/// Every test measures real widget rectangles and visibility across scroll
/// states — no opacity flags or internal state are asserted.
class _Repo implements HomeRepository {
  _Repo(this.sections, this.hotels);

  final List<HomeSection> sections;
  final List<HomeItem> hotels;

  @override
  Future<List<HomeSection>?> readHomeSnapshot({required String audience}) async =>
      null;

  @override
  Future<void> clearHomeSnapshot({required String audience}) async {}

  @override
  Future<void> saveHomeSnapshot(
    List<HomeSection> sections, {
    required String audience,
  }) async {}

  @override
  Future<ApiResult<List<HomeSection>>> getHomeSections() async =>
      ApiResult<List<HomeSection>>.success(sections);

  @override
  Future<ApiResult<List<HomeItem>>> getRecommendedHotels({
    int limit = 6,
    String? countryCode,
    String languageCode = 'en',
    String? currency,
  }) async =>
      ApiResult<List<HomeItem>>.success(hotels);

  @override
  Future<ApiResult<void>> refresh() async => const ApiResult<void>.success(null);

  @override
  Future<SnapshotState> snapshotState({required String audience}) async =>
      SnapshotState.unavailable;
}

List<HomeSection> _tallSections() => <HomeSection>[
      HomeSection(
        id: 'discover',
        title: 'Discover',
        layout: HomeSectionLayout.grid,
        items: <HomeItem>[
          for (int i = 0; i < 12; i++)
            HomeItem(
              id: 'city-$i',
              type: HomeCardType.destination,
              title: 'City $i',
              subtitle: 'Country',
            ),
        ],
      ),
    ];

List<HomeItem> _hotels() => <HomeItem>[
      for (int i = 0; i < 6; i++)
        HomeItem(
          id: 'hotel-$i',
          type: HomeCardType.hotel,
          title: 'Hotel $i',
          subtitle: 'Cairo',
          price: 100,
          currency: 'EGP',
        ),
    ];

HomeController _controller() => HomeController(
      _Repo(_tallSections(), _hotels()),
      audience: 'anon',
      contextBuilder: (_) async => const HomeCompositionContext(
        userState: HomeUserState.freshAnonymous,
      ),
      liveValidation: null,
      countryCode: null,
      languageCode: null,
      currencyCode: null,
    );

Widget _app({Locale locale = const Locale('en')}) => ProviderScope(
      overrides: <Override>[
        homeControllerProvider.overrideWith((ref) => _controller()),
        geoCountryProvider.overrideWith((ref) async => null),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/',
          routes: <RouteBase>[
            GoRoute(
              path: '/',
              builder: (context, state) => const HomePage(),
            ),
            GoRoute(
              path: '/ai-chat',
              builder: (context, state) {
                final Object? extra = state.extra;
                return Scaffold(
                  body: Text(extra == null ? 'AI:empty' : 'AI:$extra'),
                );
              },
            ),
            for (final String path in <String>[
              '/flights',
              '/hotels',
              '/cars',
              '/packages',
              '/groups',
            ])
              GoRoute(
                path: path,
                builder: (context, state) => Scaffold(
                  appBar: AppBar(),
                  body: Text('Section: $path'),
                ),
              ),
          ],
        ),
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

Finder _topBar() => find.byType(HomeTopBar);
Finder _composer() => find.byKey(const ValueKey<String>('home-ai-composer'));
Finder _nav() => find.byType(HomeActionBar);
Finder _scrollable() => find
    .descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> _pump(WidgetTester tester, {Locale locale = const Locale('en')}) async {
  tester.view.physicalSize = const Size(1120, 1400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_app(locale: locale));
  await tester.pumpAndSettle();
}

Future<void> _jump(
  WidgetTester tester,
  ScrollableState scrollable,
  double offset,
) async {
  scrollable.position.jumpTo(offset);
  await tester.pumpAndSettle();
}

Rect _viewport(WidgetTester tester) => tester.getRect(find.byType(CustomScrollView));

bool _visible(Rect rect, Rect viewport) =>
    rect.bottom > viewport.top && rect.top < viewport.bottom;

/// The scroll offset at which the navigation rail has fully left the
/// viewport. Measured from the live layout, never hard-coded.
double _navThreshold(WidgetTester tester) => tester.getRect(_nav()).bottom;

void main() {
  group('the original header is part of the scrollable content', () {
    testWidgets('at the top the complete original header is visible', (
      tester,
    ) async {
      await _pump(tester);
      final Rect viewport = _viewport(tester);

      expect(_topBar(), findsOneWidget);
      expect(_composer(), findsOneWidget);
      expect(_nav(), findsOneWidget);

      expect(_visible(tester.getRect(_topBar()), viewport), isTrue);
      expect(_visible(tester.getRect(_composer()), viewport), isTrue);
      expect(_visible(tester.getRect(_nav()), viewport), isTrue);
    });

    testWidgets('the header scrolls with the page and is not pinned', (
      tester,
    ) async {
      await _pump(tester);
      final ScrollableState scrollable = tester.state(_scrollable());

      final Rect topBefore = tester.getRect(_topBar());
      final Rect composerBefore = tester.getRect(_composer());
      final Rect navBefore = tester.getRect(_nav());

      await _jump(tester, scrollable, 50);

      // Every header element moved up by exactly the scroll delta.
      expect(tester.getRect(_topBar()).top, closeTo(topBefore.top - 50, 0.5));
      expect(
        tester.getRect(_composer()).top,
        closeTo(composerBefore.top - 50, 0.5),
      );
      expect(tester.getRect(_nav()).top, closeTo(navBefore.top - 50, 0.5));
    });

    testWidgets('the wordmark disappears naturally', (tester) async {
      await _pump(tester);
      final ScrollableState scrollable = tester.state(_scrollable());
      final double threshold = _navThreshold(tester);

      await _jump(tester, scrollable, threshold + 40);

      // The header sliver is disposed once it leaves the cache extent; if it
      // is still materialised, it must be entirely above the viewport.
      if (_topBar().evaluate().isNotEmpty) {
        expect(
          tester.getRect(_topBar()).bottom,
          lessThanOrEqualTo(_viewport(tester).top + 0.5),
        );
      } else {
        expect(_topBar(), findsNothing);
      }
    });

    testWidgets('the original search box disappears naturally', (tester) async {
      await _pump(tester);
      final ScrollableState scrollable = tester.state(_scrollable());
      final double threshold = _navThreshold(tester);

      await _jump(tester, scrollable, threshold + 40);

      if (_composer().evaluate().isNotEmpty) {
        expect(
          tester.getRect(_composer()).bottom,
          lessThanOrEqualTo(_viewport(tester).top + 0.5),
        );
      } else {
        expect(_composer(), findsNothing);
      }
    });
  });

  group('state and robustness', () {
    testWidgets('the original AI composer keeps its draft across scrolling', (
      tester,
    ) async {
      await _pump(tester);
      final ScrollableState scrollable = tester.state(_scrollable());
      final double threshold = _navThreshold(tester);

      await tester.enterText(
        find.byKey(const ValueKey<String>('home-ai-composer-field')),
        'hotel in Cairo',
      );
      await tester.pump();

      await _jump(tester, scrollable, threshold + 50);
      await _jump(tester, scrollable, 0);

      // The draft survived the header being scrolled out and back.
      final TextField field = tester.widget<TextField>(
        find.byKey(const ValueKey<String>('home-ai-composer-field')),
      );
      expect(field.controller?.text, 'hotel in Cairo');

      // The composer is still functional.
      await tester.tap(
        find.byKey(const ValueKey<String>('home-ai-composer-send')),
      );
      await tester.pumpAndSettle();
      expect(find.text('AI:hotel in Cairo'), findsOneWidget);
    });

    testWidgets('the behavior works in Arabic RTL', (tester) async {
      await _pump(tester, locale: const Locale('ar'));
      final ScrollableState scrollable = tester.state(_scrollable());
      final Rect viewport = _viewport(tester);

      // At the top the whole header is visible.
      expect(_visible(tester.getRect(_topBar()), viewport), isTrue);
      expect(_visible(tester.getRect(_composer()), viewport), isTrue);
      expect(_visible(tester.getRect(_nav()), viewport), isTrue);

      final double threshold = _navThreshold(tester);
      await _jump(tester, scrollable, threshold - 5);
      expect(_visible(tester.getRect(_nav()), viewport), isTrue);

      await _jump(tester, scrollable, threshold + 5);
      expect(_visible(tester.getRect(_nav()), viewport), isFalse);
      expect(_visible(tester.getRect(_composer()), viewport), isFalse);

      await _jump(tester, scrollable, 0);
      expect(_visible(tester.getRect(_topBar()), viewport), isTrue);
      expect(_visible(tester.getRect(_nav()), viewport), isTrue);
    });

    testWidgets('fast scrolling and reversal settle in the correct state', (
      tester,
    ) async {
      await _pump(tester);

      // A fast fling down past the whole header: the header leaves the
      // viewport with the content (nothing is pinned in its place). Offscreen
      // slivers are not built at all, so an empty finder means "not visible".
      await tester.fling(find.byType(CustomScrollView), const Offset(0, -1200), 2400);
      await tester.pumpAndSettle();
      final Rect viewport = _viewport(tester);
      expect(
        _topBar().evaluate().isNotEmpty &&
            _visible(tester.getRect(_topBar()), viewport),
        isFalse,
      );
      expect(
        _nav().evaluate().isNotEmpty &&
            _visible(tester.getRect(_nav()), viewport),
        isFalse,
      );

      // A fast fling back up: the header returns with the content.
      await tester.fling(find.byType(CustomScrollView), const Offset(0, 1200), 2400);
      await tester.pumpAndSettle();
      expect(_visible(tester.getRect(_topBar()), viewport), isTrue);
      expect(_visible(tester.getRect(_nav()), viewport), isTrue);
    });

    testWidgets('Home cards, carousels and navigation remain functional', (
      tester,
    ) async {
      await _pump(tester);
      final ScrollableState scrollable = tester.state(_scrollable());

      // The loaded feed renders the approved cards — the bundled
      // Explore catalog leads it.
      expect(find.text('Paris'), findsWidgets);

      // A navigation tile still pushes its section route.
      await tester.tap(find.byKey(const ValueKey<String>('home-action-flights')));
      await tester.pumpAndSettle();
      expect(find.text('Section: /flights'), findsOneWidget);

      // Returning to Home restores the header and the feed.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(_topBar(), findsOneWidget);
      expect(_composer(), findsOneWidget);
      expect(_nav(), findsOneWidget);
      // The bundled Explore catalog leads the restored feed.
      expect(find.text('Paris'), findsWidgets);

      // The Discover cover-flow carousel is still swipeable.
      await tester.drag(find.byType(PageView).first, const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // The recommended stays rail renders its cards further down the feed.
      await _jump(tester, scrollable, 600);
      expect(find.text('Hotel 0'), findsWidgets);
    });
  });
}
