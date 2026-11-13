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
import 'package:tokigo/features/home/providers/home_providers.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Home's scroll conflict contract (owner decision, 2026-11).
///
/// The original AI composer scrolls away with the header; the compact search
/// is a separate overlay that appears only after the navigation rail has left.
/// Measured-geometry regression:
/// * the two search controls never share the viewport — there is never a
///   moment with two stacked/overlapping search pills;
/// * the overlay never shifts the original header's layout or the scroll
///   extent.
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

Widget _app() => ProviderScope(
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
          ],
        ),
        theme: AppTheme.light(),
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    );

Finder _composer() => find.byKey(const ValueKey<String>('home-ai-composer'));
Finder _compact() =>
    find.byKey(const ValueKey<String>('home-ai-compact-search'));
Finder _scrollable() => find
    .descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    )
    .first;

bool _visible(Rect rect, Rect viewport) =>
    rect.bottom > viewport.top && rect.top < viewport.bottom;

Future<void> _jump(
  WidgetTester tester,
  ScrollableState scrollable,
  double offset,
) async {
  scrollable.position.jumpTo(offset);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the two search controls never share the viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1120, 1400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final ScrollableState scrollable = tester.state(_scrollable());
    final Rect viewport = tester.getRect(find.byType(CustomScrollView));

    // The navigation rail's own bottom edge is the reveal threshold.
    final double threshold = tester.getRect(find.byType(HomeActionBar)).bottom;

    for (final double offset in <double>[
      0,
      threshold * 0.5,
      threshold - 20,
      threshold - 5,
      threshold,
      threshold + 5,
      threshold + 40,
      threshold + 120,
    ]) {
      await _jump(tester, scrollable, offset);

      final bool composerVisible = _composer().evaluate().isNotEmpty &&
          _visible(tester.getRect(_composer()), viewport);
      final bool compactVisible = _visible(tester.getRect(_compact()), viewport);

      expect(
        composerVisible && compactVisible,
        isFalse,
        reason: 'both search controls are visible at offset $offset',
      );
    }
  });

  testWidgets('the overlay never shifts the original header or the extent', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1120, 1400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final ScrollableState scrollable = tester.state(_scrollable());
    final double extentBefore = scrollable.position.maxScrollExtent;
    final Rect composerBefore = tester.getRect(_composer());

    final double threshold = tester.getRect(find.byType(HomeActionBar)).bottom;
    await _jump(tester, scrollable, threshold + 5);

    // The compact search is pinned, and the scroll extent is unchanged.
    expect(
      _visible(
        tester.getRect(_compact()),
        tester.getRect(find.byType(CustomScrollView)),
      ),
      isTrue,
    );
    expect(scrollable.position.maxScrollExtent, extentBefore);

    // Back at the top the composer occupies exactly its original rectangle.
    await _jump(tester, scrollable, 0);
    expect(tester.getRect(_composer()).top, closeTo(composerBefore.top, 0.5));
    expect(tester.getRect(_composer()).bottom, closeTo(composerBefore.bottom, 0.5));
  });
}
