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
import 'package:tokigo/features/home/presentation/widgets/home_ai_search_field.dart';
import 'package:tokigo/features/home/presentation/widgets/home_top_bar.dart';
import 'package:tokigo/features/home/providers/home_providers.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Structural checks for the Home header architecture (owner decision,
/// 2026-11).
///
/// The original header and the feed are ONE scroll view; the compact search is
/// an OVERLAY outside it. These checks complement the measured-geometry
/// contract in `home_header_scroll_animation_test.dart`.
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

List<HomeSection> _sections() => <HomeSection>[
      HomeSection(
        id: 'discover',
        title: 'Discover',
        layout: HomeSectionLayout.grid,
        items: <HomeItem>[
          for (int i = 0; i < 6; i++)
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
      for (int i = 0; i < 4; i++)
        HomeItem(
          id: 'hotel-$i',
          type: HomeCardType.hotel,
          title: 'Hotel $i',
          subtitle: 'Cairo',
          price: 100,
          currency: 'EGP',
        ),
    ];

Widget _app() => ProviderScope(
      overrides: <Override>[
        homeControllerProvider.overrideWith(
          (ref) => HomeController(
            _Repo(_sections(), _hotels()),
            audience: 'anon',
            contextBuilder: (_) async => const HomeCompositionContext(
              userState: HomeUserState.freshAnonymous,
            ),
            liveValidation: null,
            countryCode: null,
            languageCode: null,
            currencyCode: null,
          ),
        ),
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

void main() {
  testWidgets('the original header and the feed share one scroll view', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1120, 1400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // Every original header element is a descendant of the SAME scroll view
    // as the feed cards — nothing is pinned in a separate slot.
    for (final Finder finder in <Finder>[
      find.byType(HomeTopBar),
      _composer(),
      find.byType(HomeActionBar),
      find.text('City 0'),
    ]) {
      expect(
        find.descendant(
          of: find.byType(CustomScrollView),
          matching: finder,
        ),
        findsOneWidget,
        reason: '$finder must live inside the Home scroll view',
      );
    }
  });

  testWidgets('the compact search is an overlay outside the scroll view', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1120, 1400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // The secondary control is NOT inside the scroll view: it is a sibling
    // overlay, so it can never change the scroll extent.
    expect(
      find.descendant(
        of: find.byType(CustomScrollView),
        matching: _compact(),
      ),
      findsNothing,
    );
    expect(_compact(), findsOneWidget);

    // It is a distinct control from the original composer.
    expect(_composer(), findsOneWidget);
    expect(find.byType(HomeAiSearchField), findsNWidgets(2));
  });
}
