import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/domain/models/home/home_section.dart';
import 'package:tokigo/core/geo/city_detection_service.dart';
import 'package:tokigo/core/geo/city_selection.dart';
import 'package:tokigo/core/geo/geo_client.dart';
import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/core/repositories/contracts/home_repository.dart';
import 'package:tokigo/core/storage/offline_cache.dart';
import 'package:tokigo/core/storage/offline_cache_providers.dart';
import 'package:tokigo/features/home/domain/promotional_stay.dart';
import 'package:tokigo/features/home/presentation/nearby_stays_controller.dart';

/// The IP fallback only matters if it reaches the request intact:
/// `/geo/locate` → selection controller → Nearby Stays controller → `cityId`.
/// A break anywhere in that chain silently degrades the whole feature to
/// "no location", so it is pinned end to end here.
void main() {
  test(
    'an IP-detected city reaches the Nearby Stays request as its canonical id',
    () async {
      final container = ProviderContainer(
        overrides: <Override>[
          offlineCacheProvider.overrideWithValue(MemoryOfflineCache()),
        ],
      );
      addTearDown(container.dispose);

      // Let the persisted selection finish restoring (nothing stored here).
      container.read(citySelectionProvider);
      await _settle();

      final CityDetectionService detection = CityDetectionService(
        locate: () async => const GeoLocatedCity(
          cityId: 'cairo',
          city: 'Cairo',
          countryCode: 'EG',
          currency: 'EGP',
          latitude: 30.0444,
          longitude: 31.2357,
          source: 'ip',
        ),
        currentAutomatic: () =>
            container.read(citySelectionProvider).automatic?.city,
        onResolved: (city, source) => container
            .read(citySelectionProvider.notifier)
            .setAutomatic(city, source: source),
      );

      final resolved = await detection.detectIfNeeded(force: true);
      expect(resolved?.id, 'cairo');
      expect(resolved?.name, 'Cairo');
      expect(container.read(hasManualCityProvider), isFalse);
      expect(
        container.read(citySelectionProvider).automatic?.source,
        CitySelectionSource.ip,
      );

      final _RecordingRepository repo = _RecordingRepository();
      // Same wiring as `nearbyStaysControllerProvider`: no manual city and no
      // GPS fix, so the automatic (IP) city is the one that must be sent.
      final NearbyStaysController controller = NearbyStaysController(
        repo,
        location: () async => null,
        manualCity: () => container.read(citySelectionProvider).manual?.city,
        automaticCity: () =>
            container.read(citySelectionProvider).automatic?.city,
      );
      addTearDown(controller.dispose);

      await repo.firstFetch.future.timeout(const Duration(seconds: 2));

      expect(repo.cityId, 'cairo');
      expect(repo.city, 'Cairo');
      expect(repo.country, 'EG');
      expect(repo.latitude, isNull);
      expect(repo.longitude, isNull);
    },
  );
}

Future<void> _settle() async {
  for (int i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

NearbyStaysResponse _empty() => NearbyStaysResponse(
  stays: const <PromotionalStay>[],
  radiusKm: 0,
  locationConfidence: null,
  locationSource: null,
  locationRequired: false,
  currency: 'EGP',
  occupancy: 2,
  nationality: 'EG',
  rankingVersion: 'test',
  partialFailure: false,
  fetchedAt: DateTime.utc(2026, 1, 1),
);

class _RecordingRepository implements HomeRepository {
  final Completer<void> firstFetch = Completer<void>();

  double? latitude;
  double? longitude;
  double? accuracy;
  String? cityId;
  String? city;
  String? country;
  String? currency;

  @override
  Future<ApiResult<List<HomeSection>>> getHomeSections() async =>
      const ApiResult<List<HomeSection>>.success(<HomeSection>[]);

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
  }) async {
    this.latitude = latitude;
    this.longitude = longitude;
    this.accuracy = accuracy;
    this.cityId = cityId;
    this.city = city;
    this.country = country;
    this.currency = currency;
    if (!firstFetch.isCompleted) firstFetch.complete();
    return ApiResult<NearbyStaysResponse>.success(_empty());
  }
}
