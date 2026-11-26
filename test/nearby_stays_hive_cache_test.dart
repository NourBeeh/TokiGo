import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/network/api_client.dart';
import 'package:tokigo/core/repositories/impl/home_repository_impl.dart';
import 'package:tokigo/core/storage/offline_cache.dart';
import 'package:tokigo/features/home/domain/promotional_stay.dart';

class _NoApiClient implements ApiClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

NearbyStaysResponse _response({DateTime? fetchedAt}) {
  final PromotionalStay stay = PromotionalStay(
    hotelId: 'h1',
    hotelName: 'Hotel 1',
    city: 'Cairo',
    country: 'EG',
    latitude: 30.05,
    longitude: 31.24,
    distanceKm: 2.5,
    promotionalMinimumPrice: 120,
    currency: 'USD',
    searchedFromDate: '2026-11-27',
    searchedToDate: '2026-12-04',
    occupancy: 2,
    nationality: 'EG',
    provider: 'nuitee',
    fetchedAt: fetchedAt ?? DateTime.now().toUtc(),
    locationConfidence: 'high',
  );
  return NearbyStaysResponse(
    stays: <PromotionalStay>[stay],
    radiusKm: 10,
    locationConfidence: 'high',
    locationSource: 'gps',
    locationRequired: false,
    currency: 'USD',
    occupancy: 2,
    nationality: 'EG',
    rankingVersion: 'nearby-ranking-v1',
    partialFailure: false,
    fetchedAt: fetchedAt ?? DateTime.now().toUtc(),
  );
}

void main() {
  const String scope = 'city:cairo|en|USD';

  test('a fresh scoped entry round-trips through the shared cache', () async {
    final MemoryOfflineCache cache = MemoryOfflineCache();
    final HomeRepositoryImpl repo = HomeRepositoryImpl(
      _NoApiClient(),
      offlineCache: cache,
    );
    final NearbyStaysResponse response = _response();

    await repo.writeCachedNearbyStays(response, scope: scope);
    final NearbyStaysResponse? cached = await repo.readCachedNearbyStays(
      scope: scope,
    );

    expect(cached, isNotNull);
    expect(cached!.stays.single.hotelId, 'h1');
    expect(await cache.contains('home:promotional-stays:v2:$scope'), isTrue);
  });

  test('an entry from another area is never shown as nearby', () async {
    final MemoryOfflineCache cache = MemoryOfflineCache();
    final HomeRepositoryImpl repo = HomeRepositoryImpl(
      _NoApiClient(),
      offlineCache: cache,
    );

    await repo.writeCachedNearbyStays(_response(), scope: scope);
    final NearbyStaysResponse? other = await repo.readCachedNearbyStays(
      scope: 'city:london|en|USD',
    );

    expect(other, isNull);
    expect(await cache.contains('home:promotional-stays:v2:$scope'), isTrue);
  });

  test('a day-old entry is discarded instead of shown as current', () async {
    final MemoryOfflineCache cache = MemoryOfflineCache();
    final HomeRepositoryImpl repo = HomeRepositoryImpl(
      _NoApiClient(),
      offlineCache: cache,
    );
    final DateTime old = DateTime.now().toUtc().subtract(
      HomeRepositoryImpl.promotionalStaysCacheTtl + const Duration(hours: 1),
    );

    await repo.writeCachedNearbyStays(_response(fetchedAt: old), scope: scope);
    final NearbyStaysResponse? cached = await repo.readCachedNearbyStays(
      scope: scope,
    );

    expect(cached, isNull);
    expect(await cache.contains('home:promotional-stays:v2:$scope'), isFalse);
  });

  test('the legacy unscoped payload is dropped on first read', () async {
    final MemoryOfflineCache cache = MemoryOfflineCache();
    final HomeRepositoryImpl repo = HomeRepositoryImpl(
      _NoApiClient(),
      offlineCache: cache,
    );
    await cache.write(
      HomeRepositoryImpl.legacyPromotionalStaysCacheKey,
      _response().toMap(),
    );

    expect(await repo.readCachedNearbyStays(scope: scope), isNull);
    expect(
      await cache.contains(HomeRepositoryImpl.legacyPromotionalStaysCacheKey),
      isFalse,
    );
  });
}
