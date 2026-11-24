import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tokigo/core/geo/city_catalog.dart';
import 'package:tokigo/core/geo/user_location.dart';
import 'package:tokigo/core/repositories/contracts/home_repository.dart';
import 'package:tokigo/features/home/domain/promotional_stay.dart';

/// Nearby Stays UI state (R5).
enum NearbyStaysStatus {
  /// No cache and no result yet.
  loading,

  /// Promotional cards are on screen (cached or fresh).
  success,

  /// A usable center exists but no promotional hotels were found.
  empty,

  /// No usable location: the UI must ask for an area, never show a
  /// nationwide list.
  locationRequired,

  /// Nothing cached and the network failed.
  error,
}

@immutable
class NearbyStaysState {
  const NearbyStaysState({
    this.status = NearbyStaysStatus.loading,
    this.stays = const <PromotionalStay>[],
    this.radiusKm,
    this.locationConfidence,
    this.locationSource,
    this.reason,
    this.partialFailure = false,
    this.isRefreshing = false,
    this.fetchedAt,
  });

  final NearbyStaysStatus status;
  final List<PromotionalStay> stays;
  final double? radiusKm;
  final String? locationConfidence;
  final String? locationSource;
  final String? reason;
  final bool partialFailure;
  final bool isRefreshing;
  final DateTime? fetchedAt;

  NearbyStaysState copyWith({
    NearbyStaysStatus? status,
    List<PromotionalStay>? stays,
    double? radiusKm,
    String? locationConfidence,
    String? locationSource,
    String? reason,
    bool clearReason = false,
    bool? partialFailure,
    bool? isRefreshing,
    DateTime? fetchedAt,
  }) {
    return NearbyStaysState(
      status: status ?? this.status,
      stays: stays ?? this.stays,
      radiusKm: radiusKm ?? this.radiusKm,
      locationConfidence: locationConfidence ?? this.locationConfidence,
      locationSource: locationSource ?? this.locationSource,
      // `reason` is nullable, so passing null cannot mean "clear it" on its
      // own; callers that want it gone say so explicitly.
      reason: clearReason ? null : (reason ?? this.reason),
      partialFailure: partialFailure ?? this.partialFailure,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      fetchedAt: fetchedAt ?? this.fetchedAt,
    );
  }
}

/// Owns the promotional Nearby Stays cache and refresh (R5).
///
/// Contract:
///  * the Hive payload is published IMMEDIATELY, before any network call;
///  * a successful refresh replaces it;
///  * a failed refresh preserves it (offline included);
///  * promotional prices are never labelled live, and no stale-price warning
///    is ever shown.
class NearbyStaysController extends StateNotifier<NearbyStaysState> {
  NearbyStaysController(
    this.repository, {
    Future<UserLocation?> Function()? location,
    CityOption? Function()? manualCity,
    CityOption? Function()? automaticCity,
    String Function()? languageCode,
    String? Function()? currencyCode,
  })  : _location = location,
        _manualCity = manualCity,
        _automaticCity = automaticCity,
        _languageCode = languageCode,
        _currencyCode = currencyCode,
        super(const NearbyStaysState()) {
    _start();
  }

  final HomeRepository repository;
  final Future<UserLocation?> Function()? _location;
  final CityOption? Function()? _manualCity;
  final CityOption? Function()? _automaticCity;
  final String Function()? _languageCode;
  final String? Function()? _currencyCode;

  bool _started = false;

  /// Monotonic id of the newest refresh. An older response that settles after
  /// a newer one must not overwrite the newer state.
  int _requestId = 0;

  Future<void> _start() async {
    if (_started) return;
    _started = true;
    // 1. Cached promotional cards render immediately — no skeleton wait.
    try {
      final NearbyStaysResponse? cached = await repository.readCachedNearbyStays();
      if (cached != null && cached.stays.isNotEmpty) {
        state = state.copyWith(
          status: NearbyStaysStatus.success,
          stays: cached.stays,
          radiusKm: cached.radiusKm,
          locationConfidence: cached.locationConfidence,
          locationSource: cached.locationSource,
          partialFailure: cached.partialFailure,
          fetchedAt: cached.fetchedAt,
          isRefreshing: true,
        );
      }
    } catch (_) {
      // Storage failure must never block Home.
    }
    // 2. Background refresh; the cache stays on screen no matter what.
    await refresh();
  }

  /// Fetches fresh promotional stays. Never throws; never clears cached cards.
  Future<void> refresh() async {
    final int requestId = ++_requestId;
    if (state.status == NearbyStaysStatus.loading) {
      state = state.copyWith(isRefreshing: true);
    }
    try {
      // Precedence:
      //  1. an explicit manual city (canonical id) — never asks for GPS;
      //  2. a live GPS fix when no manual city exists;
      //  3. the last automatic (IP / cached) city;
      //  4. nothing — the backend answers `locationRequired`.
      final CityOption? manual = _manualCity?.call();
      final CityOption? automatic = _automaticCity?.call();
      UserLocation? location;
      if (manual == null) {
        try {
          location = await _location?.call();
        } catch (_) {
          // A platform GPS failure means "no fix", not "no request": the
          // automatic (IP) city below must still be used.
          location = null;
        }
      }

      CityOption? selected;
      if (manual != null) {
        selected = manual;
      } else if (location == null && automatic != null) {
        selected = automatic;
      }

      final String language = _languageCode?.call() ?? 'en';
      final String? currency = _currencyCode?.call();

      final result = await repository.fetchNearbyStays(
        latitude: location?.latitude,
        longitude: location?.longitude,
        accuracy: location?.accuracy,
        cityId: selected?.id,
        city: selected?.name,
        country: selected?.countryCode,
        languageCode: language == 'ar' ? 'ar' : 'en',
        currency: (currency != null && currency.length == 3) ? currency : null,
      );

      result.when(
        success: (NearbyStaysResponse response) async {
          if (requestId != _requestId) return;
          if (response.stays.isNotEmpty) {
            state = state.copyWith(
              status: NearbyStaysStatus.success,
              stays: response.stays,
              radiusKm: response.radiusKm,
              locationConfidence: response.locationConfidence,
              locationSource: response.locationSource,
              clearReason: true,
              partialFailure: response.partialFailure,
              isRefreshing: false,
              fetchedAt: response.fetchedAt,
            );
            await repository.writeCachedNearbyStays(response);
            return;
          }
          // Empty result: keep whatever is already on screen.
          if (state.stays.isEmpty) {
            state = state.copyWith(
              status: response.locationRequired
                  ? NearbyStaysStatus.locationRequired
                  : NearbyStaysStatus.empty,
              radiusKm: response.radiusKm,
              locationConfidence: response.locationConfidence,
              locationSource: response.locationSource,
              reason: response.reason,
              clearReason: response.reason == null,
              partialFailure: response.partialFailure,
              isRefreshing: false,
              fetchedAt: response.fetchedAt,
            );
          } else {
            state = state.copyWith(isRefreshing: false);
          }
        },
        failure: (Object _) {
          if (requestId != _requestId) return;
          // Preserve cached promotional content. Only an empty screen becomes
          // an error state — and even then no stale-price warning is shown.
          if (state.stays.isEmpty) {
            state = state.copyWith(status: NearbyStaysStatus.error, isRefreshing: false);
          } else {
            state = state.copyWith(isRefreshing: false);
          }
        },
      );
    } catch (_) {
      if (requestId != _requestId) return;
      // A broken repository/storage implementation must never crash Home.
      if (state.stays.isEmpty) {
        state = state.copyWith(status: NearbyStaysStatus.error, isRefreshing: false);
      } else {
        state = state.copyWith(isRefreshing: false);
      }
    }
  }
}
