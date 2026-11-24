import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/domain/models/home/home_section.dart';
import 'package:tokigo/core/geo/city_catalog.dart';
import 'package:tokigo/core/geo/user_location.dart';
import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/core/repositories/contracts/home_repository.dart';
import 'package:tokigo/features/home/domain/promotional_stay.dart';
import 'package:tokigo/features/home/presentation/nearby_stays_controller.dart';

const CityOption _london = CityOption(
  id: 'london',
  name: 'London',
  countryCode: 'GB',
  currency: 'GBP',
  latitude: 51.5072,
  longitude: -0.1276,
);

const CityOption _cairo = CityOption(
  id: 'cairo',
  name: 'Cairo',
  countryCode: 'EG',
  currency: 'EGP',
  latitude: 30.0444,
  longitude: 31.2357,
);

NearbyStaysResponse _empty() => NearbyStaysResponse(
  stays: const <PromotionalStay>[],
  radiusKm: 0,
  locationConfidence: null,
  locationSource: null,
  locationRequired: true,
  currency: 'GBP',
  occupancy: 2,
  nationality: 'GB',
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

void main() {
  group('Nearby Stays center precedence', () {
    test('a manual city wins and GPS is never requested', () async {
      final repo = _RecordingRepository();
      bool locationRequested = false;
      final controller = NearbyStaysController(
        repo,
        location: () async {
          locationRequested = true;
          return const UserLocation(latitude: 1, longitude: 2);
        },
        manualCity: () => _london,
        automaticCity: () => _cairo,
        currencyCode: () => 'GBP',
      );
      addTearDown(controller.dispose);

      await repo.firstFetch.future;

      expect(locationRequested, isFalse);
      expect(repo.cityId, 'london');
      expect(repo.city, 'London');
      expect(repo.country, 'GB');
      expect(repo.latitude, isNull);
      expect(repo.longitude, isNull);
      expect(repo.currency, 'GBP');
    });

    test('without a manual city, a live GPS fix is sent', () async {
      final repo = _RecordingRepository();
      final controller = NearbyStaysController(
        repo,
        location: () async =>
            const UserLocation(latitude: 51.5, longitude: -0.12, accuracy: 20),
        manualCity: () => null,
        automaticCity: () => _cairo,
        currencyCode: () => 'GBP',
      );
      addTearDown(controller.dispose);

      await repo.firstFetch.future;

      expect(repo.latitude, 51.5);
      expect(repo.longitude, -0.12);
      expect(repo.accuracy, 20);
      expect(repo.cityId, isNull);
    });

    test('without GPS the last automatic city is used', () async {
      final repo = _RecordingRepository();
      final controller = NearbyStaysController(
        repo,
        location: () async => null,
        manualCity: () => null,
        automaticCity: () => _cairo,
        currencyCode: () => 'EGP',
      );
      addTearDown(controller.dispose);

      await repo.firstFetch.future;

      expect(repo.cityId, 'cairo');
      expect(repo.latitude, isNull);
      expect(repo.currency, 'EGP');
    });

    test('with no city and no GPS the request stays centerless', () async {
      final repo = _RecordingRepository();
      final controller = NearbyStaysController(
        repo,
        location: () async => null,
        manualCity: () => null,
        automaticCity: () => null,
        currencyCode: () => 'USD',
      );
      addTearDown(controller.dispose);

      await repo.firstFetch.future;

      expect(repo.cityId, isNull);
      expect(repo.city, isNull);
      expect(repo.latitude, isNull);
      expect(repo.longitude, isNull);
    });
  });

  group('Nearby Stays robustness', () {
    test('a throwing GPS provider falls back to the automatic city', () async {
      final repo = _RecordingRepository();
      final controller = NearbyStaysController(
        repo,
        location: () async => throw StateError('gps exploded'),
        manualCity: () => null,
        automaticCity: () => _cairo,
        currencyCode: () => 'EGP',
      );
      addTearDown(controller.dispose);

      await repo.firstFetch.future.timeout(const Duration(seconds: 2));

      expect(repo.cityId, 'cairo');
      expect(repo.latitude, isNull);
      expect(repo.longitude, isNull);
    });

    test('a later refresh clears the stale location reason', () async {
      final repo = _SequencedRepository(<NearbyStaysResponse>[
        _response(locationRequired: true, reason: 'no_location'),
        _response(reason: null),
      ]);
      final controller = NearbyStaysController(
        repo,
        location: () async => null,
        manualCity: () => null,
        automaticCity: () => _cairo,
      );
      addTearDown(controller.dispose);

      await _settle();
      expect(controller.state.status, NearbyStaysStatus.locationRequired);
      expect(controller.state.reason, 'no_location');

      await controller.refresh();
      expect(controller.state.status, NearbyStaysStatus.empty);
      expect(controller.state.reason, isNull);
    });

    test('an older response cannot overwrite a newer one', () async {
      final repo = _ControlledRepository();
      final controller = NearbyStaysController(
        repo,
        location: () async => null,
        manualCity: () => null,
        automaticCity: () => _cairo,
      );
      addTearDown(controller.dispose);

      await _settle();
      expect(repo.pending, hasLength(1));

      final Future<void> second = controller.refresh();
      await _settle();
      expect(repo.pending, hasLength(2));

      repo.pending[1].complete(
        ApiResult<NearbyStaysResponse>.success(_response(radiusKm: 10)),
      );
      await second;
      expect(controller.state.radiusKm, 10);

      // The older request resolves last; it must not win.
      repo.pending[0].complete(
        ApiResult<NearbyStaysResponse>.success(_response(radiusKm: 99)),
      );
      await _settle();
      expect(controller.state.radiusKm, 10);
    });

    test('copyWith clears the reason only when asked', () {
      const NearbyStaysState state = NearbyStaysState(
        status: NearbyStaysStatus.locationRequired,
        reason: 'no_location',
      );

      expect(state.copyWith(reason: null).reason, 'no_location');
      expect(
        state
            .copyWith(status: NearbyStaysStatus.success, clearReason: true)
            .reason,
        isNull,
      );
    });
  });
}

NearbyStaysResponse _response({
  double radiusKm = 0,
  bool locationRequired = false,
  String? reason,
}) {
  return NearbyStaysResponse(
    stays: const <PromotionalStay>[],
    radiusKm: radiusKm,
    locationConfidence: null,
    locationSource: null,
    locationRequired: locationRequired,
    currency: 'EGP',
    occupancy: 2,
    nationality: 'EG',
    rankingVersion: 'test',
    partialFailure: false,
    fetchedAt: DateTime.utc(2026, 1, 1),
    reason: reason,
  );
}

Future<void> _settle() async {
  for (int i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _ControlledRepository implements HomeRepository {
  final List<Completer<ApiResult<NearbyStaysResponse>>> pending =
      <Completer<ApiResult<NearbyStaysResponse>>>[];

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
  }) {
    final Completer<ApiResult<NearbyStaysResponse>> completer =
        Completer<ApiResult<NearbyStaysResponse>>();
    pending.add(completer);
    return completer.future;
  }
}

class _SequencedRepository implements HomeRepository {
  _SequencedRepository(this._responses);

  final List<NearbyStaysResponse> _responses;
  int calls = 0;

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
    final int index = calls < _responses.length ? calls : _responses.length - 1;
    calls += 1;
    return ApiResult<NearbyStaysResponse>.success(_responses[index]);
  }
}
