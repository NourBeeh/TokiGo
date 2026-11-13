import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/auth/auth_provider.dart';
import 'package:tokigo/core/domain/models/offers/hotel_offer.dart';
import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/core/repositories/contracts/hotel_repository.dart';
import 'package:tokigo/core/storage/offline_cache.dart';
import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/features/home/providers/home_providers.dart';
import 'package:tokigo/features/search/application/controllers/hotel_search_controller.dart';
import 'package:tokigo/features/search/application/providers/hotel_car_providers.dart';
import 'package:tokigo/features/search/presentation/pages/hotel_search_page.dart';
import 'package:tokigo/features/search/presentation/widgets/compact_search_summary.dart';
import 'package:tokigo/features/search/presentation/widgets/hotel_map_view.dart';
import 'package:tokigo/features/search/presentation/widgets/hotel_overlap_card.dart';
import 'package:tokigo/features/search/presentation/widgets/search_scaffold.dart';
import 'package:tokigo/features/search/presentation/widgets/search_view_toggle.dart';
import 'package:tokigo/l10n/app_localizations.dart';
import 'package:tokigo/shared/providers/locale_provider.dart';

/// The list/map view control (owner decision, 2026-11).
///
/// * the map mode is represented by a GLOBE glyph;
/// * the first press opens the map, the second closes it, reliably;
/// * the control announces the action and its selected state to screen
///   readers;
/// * on the hotel page it lives in the results toolbar (not the header) and
///   opens the REAL tile-backed map.
class _FakeHotelRepository implements HotelRepository {
  _FakeHotelRepository(this.offers);

  final List<HotelOffer> offers;

  @override
  Future<ApiResult<List<HotelOffer>>> search({
    required String city,
    required DateTime checkIn,
    required DateTime checkOut,
    int? guests,
  }) async => ApiResult.success(offers);

  @override
  Future<ApiResult<HotelOffer>> getById(String id) async =>
      ApiResult.success(offers.first);
}

HotelOffer _hotel(String id, {double? lat, double? lng}) => HotelOffer(
      id: id,
      providerId: 'nuitee',
      providerName: 'Nuitee',
      title: 'Riverside Grand',
      price: 186,
      currency: 'USD',
      city: 'Cairo',
      country: 'EG',
      checkIn: DateTime(2026, 12, 1),
      checkOut: DateTime(2026, 12, 3),
      roomType: 'Deluxe',
      metadata: <String, dynamic>{
        if (lat != null) 'latitude': lat,
        if (lng != null) 'longitude': lng,
      },
    );

void main() {
  Widget host() => ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const Scaffold(body: Center(child: SearchViewToggle())),
        ),
      );

  /// The ONE semantics annotation the control publishes.
  Semantics semantics(WidgetTester tester) => tester.widget<Semantics>(
        find
            .descendant(
              of: find.byType(SearchViewToggle),
              matching: find.byType(Semantics),
            )
            .first,
      );

  testWidgets('a globe control toggles the map open and closed', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    // List mode: the control shows the list glyph and is not selected; its
    // label names the action a press performs.
    expect(find.byIcon(Icons.view_list_rounded), findsOneWidget);
    expect(find.byIcon(Icons.public_rounded), findsNothing);
    expect(semantics(tester).properties.selected, isFalse);
    expect(semantics(tester).properties.label, 'Map');

    // First press opens the map panel.
    await tester.tap(find.byType(SearchViewToggle));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.public_rounded), findsOneWidget);
    expect(semantics(tester).properties.selected, isTrue);
    expect(semantics(tester).properties.label, 'List');

    // Second press closes it again.
    await tester.tap(find.byType(SearchViewToggle));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.view_list_rounded), findsOneWidget);
    expect(semantics(tester).properties.selected, isFalse);
    expect(semantics(tester).properties.label, 'Map');
  });

  testWidgets(
    'the hotel page hosts the toggle in the results toolbar and opens the map',
    (tester) async {
      tester.view.physicalSize = const Size(720, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final HotelSearchController controller = HotelSearchController(
        _FakeHotelRepository(<HotelOffer>[_hotel('a', lat: 30.0, lng: 31.0)]),
        MemoryOfflineCache(),
      );

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          authUserProvider.overrideWith((ref) => null),
          geoCountryProvider.overrideWith((ref) async => null),
          currencyProvider.overrideWith(() => CurrencyController()),
          hotelSearchControllerProvider.overrideWith((ref) => controller),
        ],
      );
      addTearDown(container.dispose);

      final GoRouter router = GoRouter(
        initialLocation: '/hotels',
        routes: <RouteBase>[
          GoRoute(
            path: '/hotels',
            builder: (BuildContext context, GoRouterState state) =>
                const HotelSearchPage(),
          ),
          GoRoute(
            path: '/offer-details',
            builder: (BuildContext context, GoRouterState state) =>
                const Scaffold(body: Text('DETAILS')),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.light(),
            locale: const Locale('en'),
            supportedLocales: const <Locale>[Locale('en')],
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

      // Pick Cairo and run the search.
      await tester.tap(find.byType(SearchFieldInput).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cairo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Find stays'));
      await tester.pumpAndSettle();

      // The results toolbar hosts exactly one toggle, below the summary card.
      expect(find.byType(SearchViewToggle), findsOneWidget);
      expect(find.byType(HotelOverlapCard), findsOneWidget);
      expect(find.byType(HotelMapView), findsNothing);
      expect(
        tester.getRect(find.byType(SearchViewToggle)).top,
        greaterThanOrEqualTo(
          tester.getRect(find.byType(CompactSearchSummary)).bottom - 1,
        ),
      );

      // First press opens the REAL map with the geolocated result.
      await tester.tap(find.byType(SearchViewToggle));
      await tester.pumpAndSettle();
      expect(find.byType(HotelMapView), findsOneWidget);
      expect(find.byType(HotelOverlapCard), findsNothing);
      expect(find.byIcon(Icons.location_on_outlined), findsOneWidget);

      // Second press returns to the list with the results preserved.
      await tester.tap(find.byType(SearchViewToggle));
      await tester.pumpAndSettle();
      expect(find.byType(HotelMapView), findsNothing);
      expect(find.byType(HotelOverlapCard), findsOneWidget);
    },
  );
}
