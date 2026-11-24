import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/geo/user_location.dart';
import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/network/api_error.dart';
import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/core/repositories/contracts/home_repository.dart';
import 'package:tokigo/features/home/domain/promotional_stay.dart';
import 'package:tokigo/features/home/presentation/nearby_stays_controller.dart';
import 'package:tokigo/features/home/presentation/widgets/nearby_stays_section.dart';

PromotionalStay _stay({
  String id = 'h1',
  double price = 120,
  double distanceKm = 2.5,
  double? rating = 4.6,
  int? reviewCount = 320,
  String currency = 'USD',
}) {
  return PromotionalStay(
    hotelId: id,
    hotelName: 'Hotel $id',
    city: 'Cairo',
    country: 'EG',
    image: 'https://example.com/$id.jpg',
    latitude: 30.05,
    longitude: 31.24,
    distanceKm: distanceKm,
    rating: rating,
    reviewCount: reviewCount,
    promotionalMinimumPrice: price,
    currency: currency,
    searchedFromDate: '2026-11-21',
    searchedToDate: '2026-11-28',
    occupancy: 2,
    nationality: 'EG',
    provider: 'nuitee',
    fetchedAt: DateTime.utc(2026, 11, 21),
    locationConfidence: 'high',
  );
}

NearbyStaysResponse _response(
  List<PromotionalStay> stays, {
  bool locationRequired = false,
  String? reason,
}) {
  return NearbyStaysResponse(
    stays: stays,
    radiusKm: 10,
    locationConfidence: locationRequired ? null : 'high',
    locationSource: locationRequired ? null : 'gps',
    locationRequired: locationRequired,
    reason: reason,
    currency: 'USD',
    occupancy: 2,
    nationality: 'EG',
    rankingVersion: 'nearby-ranking-v1',
    partialFailure: false,
    fetchedAt: DateTime.utc(2026, 11, 21),
  );
}

class _FakeRepo implements HomeRepository {
  _FakeRepo({this.cached, this.fetch});

  NearbyStaysResponse? cached;
  ApiResult<NearbyStaysResponse>? fetch;
  Completer<ApiResult<NearbyStaysResponse>>? fetchGate;
  int writeCalls = 0;
  NearbyStaysResponse? written;
  int fetchCalls = 0;
  double? lastLatitude;
  double? lastLongitude;
  double? lastAccuracy;
  String? lastCurrency;

  @override
  Future<NearbyStaysResponse?> readCachedNearbyStays() async => cached;

  @override
  Future<void> writeCachedNearbyStays(NearbyStaysResponse response) async {
    writeCalls += 1;
    written = response;
  }

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
  }) async {
    fetchCalls += 1;
    lastLatitude = latitude;
    lastLongitude = longitude;
    lastAccuracy = accuracy;
    lastCurrency = currency;
    if (fetchGate != null) return fetchGate!.future;
    return fetch ??
        const ApiResult<NearbyStaysResponse>.failure(
          ApiNetworkError(message: 'offline'),
        );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('PromotionalStay parses only a complete, valid record', () {
    final PromotionalStay? valid = PromotionalStay.tryParse(<String, dynamic>{
      'hotelId': 'h1',
      'hotelName': 'Hotel',
      'city': 'Cairo',
      'country': 'EG',
      'latitude': 30.05,
      'longitude': 31.24,
      'distanceKm': 2.5,
      'rating': 4.6,
      'reviewCount': 320,
      'promotionalMinimumPrice': 120,
      'currency': 'USD',
      'provider': 'nuitee',
      'fetchedAt': '2026-11-21T00:00:00.000Z',
      'locationConfidence': 'high',
    });
    expect(valid, isNotNull);
    expect(valid!.promotionalMinimumPrice, 120);
    expect(valid.hasRealReviews, isTrue);

    expect(
      PromotionalStay.tryParse(<String, dynamic>{
        'hotelId': 'h1',
        'hotelName': 'Hotel',
        'latitude': 200, // invalid coordinate
        'longitude': 31.24,
        'distanceKm': 1,
        'promotionalMinimumPrice': 10,
        'currency': 'USD',
      }),
      isNull,
    );
    expect(
      PromotionalStay.tryParse(<String, dynamic>{
        'hotelId': 'h1',
        'hotelName': 'Hotel',
        'latitude': 30,
        'longitude': 31,
        'distanceKm': 1,
        'promotionalMinimumPrice': 0, // never a fabricated price
        'currency': 'USD',
      }),
      isNull,
    );
    expect(
      PromotionalStay.tryParse(<String, dynamic>{
        'hotelId': 'h1',
        'hotelName': 'Hotel',
        'latitude': 30,
        'longitude': 31,
        'distanceKm': 1,
        'promotionalMinimumPrice': 10,
        'currency': '',
      }),
      isNull,
    );
  });

  test('the promotional model never carries booking offer ids', () {
    final Map<String, dynamic> map = _stay().toMap();
    expect(map.containsKey('offerId'), isFalse);
    expect(map.containsKey('rateId'), isFalse);
    expect(map.containsKey('prebookId'), isFalse);
    expect(map.containsKey('priceVerified'), isFalse);
  });

  test('promotionalStayToHomeItem marks the card promotional and keeps facts',
      () {
    final HomeItem item = promotionalStayToHomeItem(_stay());
    expect(item.metadata['promotional'], isTrue);
    expect(item.metadata['distanceToCenter'], 2.5);
    expect(item.metadata['latitude'], 30.05);
    expect(item.price, 120);
    expect(item.rating, 4.6);
    expect(item.reviewCount, 320);
  });

  test('cached promotional cards are published immediately, then refreshed',
      () async {
    final _FakeRepo repo = _FakeRepo(cached: _response(<PromotionalStay>[_stay()]));
    final Completer<ApiResult<NearbyStaysResponse>> gate =
        Completer<ApiResult<NearbyStaysResponse>>();
    repo.fetchGate = gate;
    final NearbyStaysController controller = NearbyStaysController(
      repo,
      location: () async => null,
    );
    // Let the cache read publish before the (gated) fetch settles.
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.status, NearbyStaysStatus.success);
    expect(controller.state.stays, hasLength(1));
    expect(controller.state.isRefreshing, isTrue);

    // A successful refresh replaces the cached content.
    gate.complete(
      ApiResult<NearbyStaysResponse>.success(
        _response(<PromotionalStay>[_stay(id: 'h2', price: 90)]),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.stays.first.hotelId, 'h2');
    expect(repo.writeCalls, 1);
    expect(repo.written!.stays.first.hotelId, 'h2');
    controller.dispose();
  });

  test('a failed refresh preserves the cached promotional content', () async {
    final _FakeRepo repo = _FakeRepo(
      cached: _response(<PromotionalStay>[_stay()]),
      fetch: const ApiResult<NearbyStaysResponse>.failure(
        ApiNetworkError(message: 'offline'),
      ),
    );
    final NearbyStaysController controller = NearbyStaysController(repo);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.stays, hasLength(1));
    expect(controller.state.status, NearbyStaysStatus.success);
    expect(controller.state.isRefreshing, isFalse);
    controller.dispose();
  });

  test('no usable location yields locationRequired, never a nationwide list',
      () async {
    final _FakeRepo repo = _FakeRepo(
      fetch: ApiResult<NearbyStaysResponse>.success(
        _response(const <PromotionalStay>[], locationRequired: true, reason: 'no_location'),
      ),
    );
    final NearbyStaysController controller = NearbyStaysController(repo);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.status, NearbyStaysStatus.locationRequired);
    expect(controller.state.stays, isEmpty);
    controller.dispose();
  });

  test('location, accuracy and currency are sent with the request', () async {
    final _FakeRepo repo = _FakeRepo();
    final NearbyStaysController controller = NearbyStaysController(
      repo,
      location: () async => const UserLocation(
        latitude: 30.05,
        longitude: 31.24,
        accuracy: 2500,
      ),
      currencyCode: () => 'EGP',
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(repo.lastLatitude, 30.05);
    expect(repo.lastLongitude, 31.24);
    expect(repo.lastAccuracy, 2500);
    expect(repo.lastCurrency, 'EGP');
    controller.dispose();
  });
}
