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
import 'package:tokigo/features/home/domain/home_composer.dart';
import 'package:tokigo/features/home/presentation/home_controller.dart';
import 'package:tokigo/features/home/presentation/pages/home_page.dart';
import 'package:tokigo/features/home/presentation/widgets/home_top_bar.dart';
import 'package:tokigo/features/home/providers/home_providers.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Home's scroll header contract (owner decision, 2026-11).
///
/// * the wordmark row animates away when the feed scrolls AWAY from the top and
///   animates back when the traveller returns toward the top;
/// * the transition is a single smooth animation, not a jump;
/// * the pinned AI composer NEVER moves with the header and is never hidden.
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
  }) async => ApiResult<List<HomeItem>>.success(hotels);

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

void main() {
  testWidgets('scrolling away hides the wordmark row smoothly', (tester) async {
    tester.view.physicalSize = const Size(1120, 1400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byType(HomeTopBar), findsOneWidget);
    final Rect composerBox = tester.getRect(
      find.byKey(const ValueKey<String>('home-ai-composer')),
    );

    // A long drag away from the top: the header animates out.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();

    // The header has been hidden by the animation (its widget is removed once
    // the visibility factor reaches zero)…
    expect(find.byType(HomeTopBar), findsNothing);

    // …and the pinned composer keeps exactly its SIZE and width (it never
    // collapses or is displaced sideways by the header's disappearance).
    final Rect composerAfter = tester.getRect(_composer());
    expect(composerAfter.size, composerBox.size);
    expect(composerAfter.left, composerBox.left);
    expect(composerAfter.right, composerBox.right);
  });

  testWidgets('scrolling back toward the top reveals the header again', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1120, 1400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.byType(HomeTopBar), findsNothing);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(find.byType(HomeTopBar), findsOneWidget);
    expect(
      tester.getRect(find.byType(HomeTopBar)).bottom,
      greaterThan(0),
    );
  });

  testWidgets('the pinned composer is always fully inside the viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1120, 1400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    for (final double delta in <double>[-120, -260, -140, 300]) {
      await tester.drag(find.byType(CustomScrollView), Offset(0, delta));
      await tester.pumpAndSettle();
      final Rect viewport = tester.getRect(find.byType(CustomScrollView));
      final Rect composer = tester.getRect(_composer());
      expect(composer.top, greaterThanOrEqualTo(viewport.top - 0.5));
      expect(composer.bottom, lessThanOrEqualTo(viewport.bottom + 0.5));
    }
  });
}
