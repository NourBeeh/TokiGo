import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/auth/auth_provider.dart';
import 'package:tokigo/core/domain/models/offers/hotel_offer.dart';
import 'package:tokigo/core/network/api_error.dart';
import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/core/repositories/contracts/hotel_repository.dart';
import 'package:tokigo/core/storage/offline_cache.dart';
import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/core/widgets/cards/card_favorite.dart';
import 'package:tokigo/core/widgets/search_filter_chips.dart';
import 'package:tokigo/features/home/providers/home_providers.dart';
import 'package:tokigo/features/profile/application/wishlist_controller.dart';
import 'package:tokigo/features/search/application/controllers/hotel_search_controller.dart';
import 'package:tokigo/features/search/application/providers/hotel_car_providers.dart';
import 'package:tokigo/features/search/presentation/pages/hotel_search_page.dart';
import 'package:tokigo/features/search/presentation/widgets/hotel_overlap_card.dart';
import 'package:tokigo/features/search/presentation/widgets/search_scaffold.dart';
import 'package:tokigo/l10n/app_localizations.dart';
import 'package:tokigo/shared/providers/locale_provider.dart';

/// The hotel RESULTS PAGE behaviour that no other suite covers.
///
/// The card's own drawing is pinned by `home_stays_carousel_test.dart`,
/// `home_split_stay_card_test.dart` and `home_stay_rating_test.dart`, and the
/// map toggle by `search_view_toggle_test.dart`. What is pinned here is the
/// page around the card: what a result row actually shows, the heart's effect
/// on the wishlist, the details hand-off, the loading/empty/error states, and
/// the sort and star-class filters.
class _FakeHotelRepository implements HotelRepository {
  _FakeHotelRepository(this.offers, {this.failures = 0});

  List<HotelOffer> offers;

  /// How many of the next searches fail before the fake starts succeeding.
  int failures;

  int calls = 0;

  @override
  Future<ApiResult<List<HotelOffer>>> search({
    required String city,
    required DateTime checkIn,
    required DateTime checkOut,
    int? guests,
  }) async {
    calls++;
    if (failures > 0) {
      failures--;
      return const ApiResult.failure(ApiNetworkError(message: 'offline'));
    }
    return ApiResult.success(offers);
  }

  @override
  Future<ApiResult<HotelOffer>> getById(String id) async =>
      ApiResult.success(offers.first);
}

/// A controller whose state can be seeded directly, so the loading state can
/// be asserted without racing a real async search.
class _SeedableHotelSearchController extends HotelSearchController {
  _SeedableHotelSearchController(HotelRepository repository, OfflineCache cache)
      : super(repository, cache);

  void seed(HotelSearchState value) => state = value;
}

HotelOffer _hotel(
  String id, {
  String title = 'Riverside Grand',
  double price = 186,
  double? rating = 4.8,
  int? reviewCount = 120,
  int? stars,
}) => HotelOffer(
      id: id,
      providerId: 'nuitee',
      providerName: 'Nuitee',
      title: title,
      price: price,
      currency: 'USD',
      city: 'Cairo',
      country: 'EG',
      checkIn: DateTime(2026, 12, 1),
      checkOut: DateTime(2026, 12, 3),
      roomType: 'Deluxe',
      rating: rating,
      reviewCount: reviewCount,
      metadata: <String, dynamic>{if (stars != null) 'stars': stars},
    );

/// Hosts the real page with the real controller over a fake repository, and a
/// two-route router so the details hand-off is observable.
class _Host {
  _Host(this.controller);

  final HotelSearchController controller;
  late final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      authUserProvider.overrideWith((ref) => null),
      geoCountryProvider.overrideWith((ref) async => null),
      currencyProvider.overrideWith(() => CurrencyController()),
      hotelSearchControllerProvider.overrideWith((ref) => controller),
    ],
  );

  Widget get widget => UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: GoRouter(
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
          ),
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
      );
}

Future<void> _pumpPage(WidgetTester tester, _Host host, {bool settle = true}) async {
  tester.view.physicalSize = const Size(720, 3000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(host.container.dispose);

  await tester.pumpWidget(host.widget);
  // A skeleton shimmers forever, so `pumpAndSettle` would never return for the
  // loading state; that test pumps a fixed frame instead.
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

/// Cairo + the default dates, then "Find stays".
Future<void> _runSearch(WidgetTester tester) async {
  await tester.tap(find.byType(SearchFieldInput).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Cairo'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Find stays'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a result row shows the title, the per-night price and the score',
      (WidgetTester tester) async {
    final _Host host = _Host(
      _SeedableHotelSearchController(
        _FakeHotelRepository(<HotelOffer>[_hotel('a')]),
        MemoryOfflineCache(),
      ),
    );
    await _pumpPage(tester, host);
    await _runSearch(tester);

    expect(find.byType(HotelOverlapCard), findsOneWidget);
    expect(find.text('Riverside Grand'), findsOneWidget);
    // 186 over the offer's own two nights is a derived 93 / night.
    expect(find.text('93'), findsOneWidget);
    expect(find.text('/ night'), findsOneWidget);
    // The guest score is real (120 reviews back it), so it is drawn.
    expect(find.text('4.8'), findsOneWidget);
    expect(find.text('1 stay'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the heart saves the stay and the card reflects it',
      (WidgetTester tester) async {
    final _Host host = _Host(
      _SeedableHotelSearchController(
        _FakeHotelRepository(<HotelOffer>[_hotel('a')]),
        MemoryOfflineCache(),
      ),
    );
    await _pumpPage(tester, host);
    await _runSearch(tester);

    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
    expect(host.container.read(wishlistProvider), isEmpty);

    await tester.tap(find.byType(CardFavorite).first);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(host.container.read(wishlistProvider).map((o) => o.id), <String>['a']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a result opens the offer details page',
      (WidgetTester tester) async {
    final _Host host = _Host(
      _SeedableHotelSearchController(
        _FakeHotelRepository(<HotelOffer>[_hotel('a')]),
        MemoryOfflineCache(),
      ),
    );
    await _pumpPage(tester, host);
    await _runSearch(tester);

    await tester.tap(find.text('Riverside Grand'));
    await tester.pumpAndSettle();

    expect(find.text('DETAILS'), findsOneWidget);
  });

  testWidgets('a search that returns nothing shows the empty state',
      (WidgetTester tester) async {
    final _Host host = _Host(
      _SeedableHotelSearchController(
        _FakeHotelRepository(<HotelOffer>[]),
        MemoryOfflineCache(),
      ),
    );
    await _pumpPage(tester, host);
    await _runSearch(tester);

    expect(find.text('No stays found'), findsOneWidget);
    expect(find.byType(HotelOverlapCard), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed search shows the error state and retry recovers',
      (WidgetTester tester) async {
    final _FakeHotelRepository repository = _FakeHotelRepository(
      <HotelOffer>[_hotel('a')],
      failures: 1,
    );
    final _Host host = _Host(
      _SeedableHotelSearchController(repository, MemoryOfflineCache()),
    );
    await _pumpPage(tester, host);
    await _runSearch(tester);

    expect(find.text('Connection error'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byType(HotelOverlapCard), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Connection error'), findsNothing);
    expect(find.byType(HotelOverlapCard), findsOneWidget);
    expect(repository.calls, 2);
  });

  testWidgets('the loading state draws skeletons, not an empty feed',
      (WidgetTester tester) async {
    final _SeedableHotelSearchController controller =
        _SeedableHotelSearchController(
          _FakeHotelRepository(<HotelOffer>[]),
          MemoryOfflineCache(),
        )..seed(const HotelSearchState(status: HotelSearchStatus.loading));
    final _Host host = _Host(controller);
    await _pumpPage(tester, host, settle: false);

    expect(find.byType(HotelOverlapCard), findsWidgets);
    expect(
      tester
          .widgetList<HotelOverlapCard>(find.byType(HotelOverlapCard))
          .every((HotelOverlapCard card) => card.loading),
      isTrue,
    );
    expect(find.text('No stays found'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sorting by price reorders the results', (WidgetTester tester) async {
    final _Host host = _Host(
      _SeedableHotelSearchController(
        _FakeHotelRepository(<HotelOffer>[
          _hotel('expensive', title: 'Grand Plaza', price: 500),
          _hotel('cheap', title: 'City Inn', price: 100),
        ]),
        MemoryOfflineCache(),
      ),
    );
    await _pumpPage(tester, host);
    await _runSearch(tester);

    // "Recommended" keeps the provider's own order.
    double dyOf(String title) => tester.getTopLeft(find.text(title)).dy;
    expect(dyOf('Grand Plaza'), lessThan(dyOf('City Inn')));

    await tester.tap(find.byIcon(Icons.swap_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cheapest'));
    await tester.pumpAndSettle();

    expect(dyOf('City Inn'), lessThan(dyOf('Grand Plaza')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the star-class chips filter the results', (WidgetTester tester) async {
    final _Host host = _Host(
      _SeedableHotelSearchController(
        _FakeHotelRepository(<HotelOffer>[
          _hotel('five', title: 'Grand Five', stars: 5),
          _hotel('three', title: 'Simple Three', stars: 3),
        ]),
        MemoryOfflineCache(),
      ),
    );
    await _pumpPage(tester, host);
    await _runSearch(tester);

    expect(find.text('2 stays'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(SearchFilterChips),
        matching: find.text('5'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 stay'), findsOneWidget);
    expect(find.text('Grand Five'), findsOneWidget);
    expect(find.text('Simple Three'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
