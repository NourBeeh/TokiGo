import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/domain/models/offers/hotel_offer.dart';
import 'package:tokigo/core/domain/models/search/hotel_room_occupancy.dart';
import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/core/repositories/contracts/hotel_repository.dart';
import 'package:tokigo/core/storage/offline_cache.dart';
import 'package:tokigo/core/storage/offline_cache_providers.dart';
import 'package:tokigo/features/home/domain/promotional_stay.dart';
import 'package:tokigo/features/home/presentation/pages/nearby_hotel_details_page.dart';
import 'package:tokigo/features/search/application/providers/hotel_car_providers.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// R9/R10 — a promotional Nearby card opens hotel details, and NO live search
/// runs until the traveller picks dates/occupancy and explicitly asks.
class _FakeHotelRepo implements HotelRepository {
  int searchCalls = 0;
  String? lastCity;
  DateTime? lastCheckIn;
  DateTime? lastCheckOut;
  List<HotelOffer> offers = <HotelOffer>[];

  @override
  Future<ApiResult<List<HotelOffer>>> search({
    required String city,
    required DateTime checkIn,
    required DateTime checkOut,
    int? guests,
  }) async {
    searchCalls += 1;
    lastCity = city;
    lastCheckIn = checkIn;
    lastCheckOut = checkOut;
    return ApiResult<List<HotelOffer>>.success(offers);
  }

  @override
  Future<ApiResult<HotelOffer>> getById(String id) async =>
      ApiResult<HotelOffer>.success(offers.first);
}

void main() {
  final PromotionalStay stay = PromotionalStay(
    hotelId: 'provider-hotel-1',
    hotelName: 'Riverside Grand',
    city: 'Cairo',
    country: 'EG',
    image: null,
    latitude: 30.05,
    longitude: 31.24,
    distanceKm: 2.5,
    rating: 4.6,
    reviewCount: 320,
    promotionalMinimumPrice: 120,
    currency: 'USD',
    searchedFromDate: '2026-11-21',
    searchedToDate: '2026-11-28',
    occupancy: 2,
    nationality: 'EG',
    provider: 'nuitee',
    fetchedAt: DateTime.utc(2026, 11, 21),
    locationConfidence: 'high',
  );

  final HotelOffer liveOffer = HotelOffer(
    id: 'rate-live-1',
    providerId: 'nuitee',
    providerName: 'Nuitee Connect',
    title: 'Riverside Grand',
    price: 135,
    currency: 'USD',
    city: 'Cairo',
    country: 'EG',
    checkIn: DateTime.utc(2026, 11, 28),
    checkOut: DateTime.utc(2026, 11, 30),
    roomType: 'Deluxe',
    metadata: const <String, dynamic>{'providerHotelId': 'provider-hotel-1'},
  );

  testWidgets(
    'details open without a live search; the explicit button searches',
    (WidgetTester tester) async {
      final _FakeHotelRepo repo = _FakeHotelRepo()
        ..offers = <HotelOffer>[liveOffer];

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            hotelRepositoryProvider.overrideWith((ref) => repo),
            offlineCacheProvider.overrideWith((ref) => MemoryOfflineCache()),
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
            home: NearbyHotelDetailsPage(stay: stay),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The promotional discovery price is shown, clearly labelled.
      expect(
        find.textContaining('Promotional discovery price'),
        findsOneWidget,
      );
      expect(find.text('Check availability'), findsOneWidget);
      expect(find.text('Live prices for your dates'), findsNothing);

      // No live provider call happened on open.
      expect(repo.searchCalls, 0);

      await tester.ensureVisible(find.text('Check availability'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Check availability'));
      await tester.pumpAndSettle();

      // The explicit request ran the live search for the hotel's city.
      expect(repo.searchCalls, 1);
      expect(repo.lastCity, 'Cairo');
      expect(repo.lastCheckIn, isNotNull);
      expect(repo.lastCheckOut, isNotNull);
      expect(find.text('Live prices for your dates'), findsOneWidget);
    },
  );

  group('adult distribution across rooms', () {
    test('one room takes the whole party', () {
      expect(
        distributeAdultsAcrossRooms(
          adults: 4,
          rooms: 1,
        ).map((HotelRoomOccupancy o) => o.adults),
        <int>[4],
      );
    });

    test('two rooms split the party evenly', () {
      expect(
        distributeAdultsAcrossRooms(
          adults: 4,
          rooms: 2,
        ).map((HotelRoomOccupancy o) => o.adults),
        <int>[2, 2],
      );
    });

    test('the remainder goes to the first rooms', () {
      expect(
        distributeAdultsAcrossRooms(
          adults: 4,
          rooms: 3,
        ).map((HotelRoomOccupancy o) => o.adults),
        <int>[2, 1, 1],
      );
      expect(
        distributeAdultsAcrossRooms(
          adults: 5,
          rooms: 4,
        ).map((HotelRoomOccupancy o) => o.adults),
        <int>[2, 1, 1, 1],
      );
    });

    test(
      'a party smaller than the room count still gives every room an adult',
      () {
        final List<HotelRoomOccupancy> occupancy = distributeAdultsAcrossRooms(
          adults: 2,
          rooms: 4,
        );
        expect(occupancy, hasLength(4));
        expect(occupancy.map((HotelRoomOccupancy o) => o.adults), <int>[
          1,
          1,
          1,
          1,
        ]);
      },
    );

    test('each room is capped at the provider 20-adult limit', () {
      expect(
        distributeAdultsAcrossRooms(
          adults: 60,
          rooms: 2,
        ).map((HotelRoomOccupancy o) => o.adults),
        <int>[20, 20],
      );
    });

    test('invalid counts fall back to one room with one adult', () {
      expect(
        distributeAdultsAcrossRooms(
          adults: 0,
          rooms: 0,
        ).map((HotelRoomOccupancy o) => o.adults),
        <int>[1],
      );
    });
  });
}
