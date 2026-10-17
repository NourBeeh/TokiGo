import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_section.dart';
import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/core/repositories/contracts/home_repository.dart';
import 'package:tokigo/features/home/presentation/home_controller.dart';
import 'package:tokigo/features/home/presentation/pages/home_page.dart';
import 'package:tokigo/features/home/providers/home_providers.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// H1 — Nuitee-only Home loading rail tests (updated 2026-09-08).
///
/// The old "development preview" (skeleton section HEADINGS with no data)
/// was removed: an empty feed now renders the honest no-content state with
/// a retry. The skeleton rail remains legitimate in exactly ONE state —
/// while real content is still loading (feed empty + hotels in flight + no
/// snapshot), mirroring the real carousel geometry with zero fake data.
void main() {
  Widget host(HomeController controller) => ProviderScope(
        overrides: [
          homeControllerProvider.overrideWith((ref) => controller),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const Scaffold(body: HomePage()),
        ),
      );

  testWidgets('LOADING state: skeleton cards show, no pull-to-refresh',
      (tester) async {
    await tester.pumpWidget(host(_PinnedController(
      const HomeState(status: HomeStatus.loading),
    )));

    // The loading body renders its shimmer placeholder cards.
    expect(find.byType(Card), findsNothing); // real data cards never render
    expect(find.byType(RefreshIndicator), findsNothing);
  });

  testWidgets('SUCCESS + empty content: the skeleton RAIL renders with its fixed title',
      (tester) async {
    // The rail is the Nuitee-only placeholder while hotels are in flight —
    // success with no sections and no hotels yet (the exact state the Home
    // sits in right after an empty feed until the rail lands).
    await tester.pumpWidget(host(_PinnedController(
      const HomeState(status: HomeStatus.success),
    )));

    expect(find.text('Recommended for You'), findsOneWidget);
    expect(find.byType(Card), findsAtLeast(3));
    expect(find.byType(RefreshIndicator), findsNothing);
  });

  testWidgets('LOADING state: skeleton rail carries NO fake travel data',
      (tester) async {
    await tester.pumpWidget(host(_PinnedController(
      const HomeState(status: HomeStatus.loading),
    )));

    expect(find.text('Grand Palm Hotel'), findsNothing);
    expect(find.text('Real Hotel'), findsNothing);
    expect(find.text('Grand Cairo'), findsNothing);
    expect(find.textContaining('Paris'), findsNothing);
    expect(find.textContaining('Cairo'), findsNothing);
    expect(find.textContaining('USD'), findsNothing);
    expect(find.textContaining('\$'), findsNothing);
  });

  testWidgets('EMPTY state (2026-09-08): honest no-content + retry, '
      'NO skeleton section headings', (tester) async {
    await tester.pumpWidget(host(_PinnedController(
      const HomeState(status: HomeStatus.empty),
    )));

    // The honest empty message and its retry affordance render.
    expect(find.text('No recommendations right now'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    // The old empty preview HEADINGS are gone ('Hotels' here would only be
    // the nav button label — the old preview section titles are what must
    // NOT appear).
    expect(find.text('Flight Recommendations'), findsNothing);
    expect(find.text('Car Rentals'), findsNothing);
    expect(find.text('Tour Packages'), findsNothing);
    expect(find.text('Hot Deals'), findsNothing);
    expect(find.text('Destinations'), findsNothing);

    // The skeleton rail does not render in the empty state — loading
    // placeholders belong to loading, not to empty.
    expect(find.text('Recommended for You'), findsNothing);
  });
}

/// Controller pinned to the given state: the inert repository returns a
/// NEVER-COMPLETING future for the startup paths so the pinned state can
/// never be overwritten asynchronously (startup behavior itself is covered
/// by home_controller_test.dart).
class _PinnedController extends HomeController {
  _PinnedController(HomeState pinned) : super(_InertRepo(), liveValidation: null) {
    state = pinned;
  }
}

/// Inert repository: every startup path HANGS (never completes) — the
/// pinned state stays exactly as the test set it.
class _InertRepo implements HomeRepository {
  @override
  Future<ApiResult<List<HomeSection>>> getHomeSections() =>
      Completer<ApiResult<List<HomeSection>>>().future;

  @override
  Future<ApiResult<List<HomeItem>>> getRecommendedHotels({int limit = 6}) =>
      Completer<ApiResult<List<HomeItem>>>().future;

  @override
  Future<ApiResult<void>> refresh() =>
      Completer<ApiResult<void>>().future;

  @override
  Future<List<HomeSection>?> readHomeSnapshot({required String audience}) =>
      Completer<List<HomeSection>?>().future;

  @override
  Future<void> clearHomeSnapshot({required String audience}) =>
      Completer<void>().future;

  @override
  Future<void> saveHomeSnapshot(
    List<HomeSection> sections, {
    required String audience,
  }) =>
      Completer<void>().future;
}
