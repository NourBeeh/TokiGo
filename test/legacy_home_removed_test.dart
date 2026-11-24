import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/domain/models/home/home_section.dart';
import 'package:tokigo/core/network/api_error.dart';
import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/core/repositories/contracts/home_repository.dart';
import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/features/home/domain/promotional_stay.dart';
import 'package:tokigo/features/home/presentation/pages/home_page.dart';
import 'package:tokigo/features/home/presentation/widgets/nearby_stays_section.dart';
import 'package:tokigo/features/home/providers/home_providers.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Regression guards for the legacy Home removal.
///
/// The old Home system (snapshot restore/persist, live price validation,
/// composer/personalization, recommended rail) must not be initialized,
/// executed or referenced by the new Home.
void main() {
  test('HomeRepository no longer exposes the old snapshot/recommended API', () {
    final String source = File(
      'lib/core/repositories/contracts/home_repository.dart',
    ).readAsStringSync();
    for (final String obsolete in <String>[
      'readHomeSnapshot',
      'saveHomeSnapshot',
      'clearHomeSnapshot',
      'snapshotState',
      'getRecommendedHotels',
      'SnapshotState',
    ]) {
      expect(source.contains(obsolete), isFalse, reason: obsolete);
    }
    // The promotional cache key is the one Home cache that must survive.
    expect(source.contains('readCachedNearbyStays'), isTrue);
    expect(source.contains('fetchNearbyStays'), isTrue);
  });

  test('the old Home providers/services are not registered', () {
    final String providers = File(
      'lib/features/home/providers/home_providers.dart',
    ).readAsStringSync();
    expect(providers.contains('homeControllerProvider'), isFalse);
    expect(providers.contains('HomeController'), isFalse);
    expect(providers.contains('HomeLiveValidationService'), isFalse);
    expect(providers.contains('HomeComposer'), isFalse);
    expect(providers.contains('RecommendationService'), isFalse);
    expect(providers.contains('homePersonalizationOrchestratorProvider'), isFalse);
    expect(providers.contains('exploreFeedControllerProvider'), isTrue);
  });

  test('HomeItem no longer carries price-verification state', () {
    final String source = File(
      'lib/core/domain/models/home/home_item.dart',
    ).readAsStringSync();
    for (final String obsolete in <String>[
      'bool get priceVerified',
      'bool get priceUnverified',
      'HomeItem markPriceVerified',
      'HomeItem markPriceUnverified',
      'enum HomePriceVerification',
      'priceFailure',
      'priceVerifiedKey',
      'priceUnverifiedKey',
    ]) {
      expect(source.contains(obsolete), isFalse, reason: obsolete);
    }
  });

  testWidgets('Home renders Explore and Nearby without the old feed', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1480);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final _RecordingRepo repo = _RecordingRepo();
    final GoRouter router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(path: '/', builder: (context, state) => const HomePage()),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          homeRepositoryProvider.overrideWith((ref) => repo),
        ],
        child: MaterialApp.router(
          routerConfig: router,
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
      ),
    );
    await tester.pumpAndSettle();

    // Explore renders from the bundled catalog; Nearby renders its section.
    expect(find.text('Explore'), findsWidgets);
    expect(find.byType(NearbyStaysSection), findsOneWidget);

    // Home does not fetch the old generic Home feed.
    expect(repo.homeFeedCalls, 0);
    expect(tester.takeException(), isNull);
  });
}

class _RecordingRepo implements HomeRepository {
  int homeFeedCalls = 0;

  @override
  Future<ApiResult<List<HomeSection>>> getHomeSections() async {
    homeFeedCalls += 1;
    return const ApiResult<List<HomeSection>>.failure(
      ApiNetworkError(message: 'must not be called by Home'),
    );
  }

  @override
  Future<NearbyStaysResponse?> readCachedNearbyStays() async => null;

  @override
  Future<void> writeCachedNearbyStays(NearbyStaysResponse response) async {}

  @override
  Future<ApiResult<NearbyStaysResponse>> fetchNearbyStays({
    double? latitude,
    double? longitude,
    double? accuracy,
    String? cityId,
    String? city,
    String? country,
    String languageCode = 'en',
    String? currency,
  }) async => const ApiResult<NearbyStaysResponse>.failure(
    ApiNetworkError(message: 'no nearby payload'),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
