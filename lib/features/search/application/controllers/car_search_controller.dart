import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tokigo/core/domain/models/search/car_search_params.dart';
import 'package:tokigo/core/domain/models/offers/car_offer.dart';
import 'package:tokigo/core/network/user_facing_message.dart';
import 'package:tokigo/core/repositories/contracts/car_repository.dart';
import 'package:tokigo/core/storage/offline_cache.dart';
import 'package:tokigo/core/storage/offline_cache_serializers.dart';

enum CarSearchStatus { idle, loading, success, empty, error }

class CarSearchState {
  final CarSearchStatus status;
  final List<CarOffer> results;
  final String? errorMessage;
  final bool fromCache;

  const CarSearchState({
    this.status = CarSearchStatus.idle,
    this.results = const [],
    this.errorMessage,
    this.fromCache = false,
  });
  CarSearchState copyWith({
    CarSearchStatus? status,
    List<CarOffer>? results,
    String? errorMessage,
    bool? fromCache,
  }) {
    return CarSearchState(
      status: status ?? this.status,
      results: results ?? this.results,
      errorMessage: errorMessage ?? this.errorMessage,
      fromCache: fromCache ?? this.fromCache,
    );
  }
}

class CarSearchController extends StateNotifier<CarSearchState> {
  final CarRepository repository;
  final OfflineCache _cache;

  /// Phase 3A — request versioning (stale-response guard, same as the
  /// flight/hotel controllers).
  int _requestVersion = 0;

  CarSearchController(this.repository, this._cache)
    : super(const CarSearchState());

  /// Public read of the latest result set (used by orchestrators that must
  /// not touch the protected `state`).
  List<CarOffer> get results => state.results;

  Future<void> search(CarSearchParams params) async {
    final version = ++_requestVersion;

    final cacheKey = carSearchCacheKey(
      pickupLocation: params.pickupLocation,
      pickupTime: params.pickupDateTime,
      dropoffTime: params.dropoffDateTime,
    );

    // Try to load from cache first
    final cached = await _cache.read(cacheKey);
    if (version != _requestVersion) return; // Superseded mid-flight.
    if (cached != null) {
      final offers = <CarOffer>[];
      for (final item in (cached['offers'] as List? ?? [])) {
        if (item is Map<String, dynamic>) {
          final offer = offerFromMap(item) as CarOffer?;
          if (offer != null) offers.add(offer);
        }
      }
      if (offers.isNotEmpty) {
        state = state.copyWith(
          status: CarSearchStatus.success,
          results: offers,
          fromCache: true,
        );
      }
    }

    state = state.copyWith(status: CarSearchStatus.loading);
    final result = await repository.search(
      pickupLocation: params.pickupLocation,
      pickupTime: params.pickupDateTime,
      dropoffTime: params.dropoffDateTime,
    );
    if (version != _requestVersion) return; // Superseded mid-flight.
    await result.when<Future<void>>(
      success: (offers) async {
        if (offers.isEmpty) {
          state = state.copyWith(
            status: CarSearchStatus.empty,
            results: [],
            fromCache: false,
          );
        } else {
          // Write to cache (best-effort)
          try {
            await _cache.write(cacheKey, {
              'offers': offers.map(offerToMap).toList(),
              'timestamp': DateTime.now().toIso8601String(),
            });
          } catch (_) {
            // Ignore cache write failures
          }
          state = state.copyWith(
            status: CarSearchStatus.success,
            results: offers,
            fromCache: false,
          );
        }
      },
      failure: (e) async {
        if (state.fromCache && state.results.isNotEmpty) {
          state = state.copyWith(
            status: CarSearchStatus.success,
            errorMessage: userFacingMessage(e, subject: 'car search'),
          );
        } else {
          state = state.copyWith(
            status: CarSearchStatus.error,
            errorMessage: userFacingMessage(e, subject: 'car search'),
            fromCache: false,
          );
        }
      },
    );
  }
}
