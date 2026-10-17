import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tokigo/core/domain/models/search/flight_search_params.dart';
import 'package:tokigo/core/domain/models/offers/flight_offer.dart';
import 'package:tokigo/core/network/user_facing_message.dart';
import 'package:tokigo/core/usecases/search_flights_usecase.dart';
import 'package:tokigo/core/storage/offline_cache.dart';
import 'package:tokigo/core/storage/offline_cache_serializers.dart';

enum SearchStatus { idle, loading, success, empty, error }

class FlightSearchState {
  final SearchStatus status;
  final List<FlightOffer> results;
  final String? errorMessage;
  final bool isRefreshing;
  final bool fromCache;

  const FlightSearchState({
    this.status = SearchStatus.idle,
    this.results = const [],
    this.errorMessage,
    this.isRefreshing = false,
    this.fromCache = false,
  });

  FlightSearchState copyWith({
    SearchStatus? status,
    List<FlightOffer>? results,
    String? errorMessage,
    bool? isRefreshing,
    bool? fromCache,
  }) {
    return FlightSearchState(
      status: status ?? this.status,
      results: results ?? this.results,
      errorMessage: errorMessage ?? this.errorMessage,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      fromCache: fromCache ?? this.fromCache,
    );
  }
}

class FlightSearchController extends StateNotifier<FlightSearchState> {
  final SearchFlightsUseCase usecase;
  final OfflineCache _cache;

  /// Phase 3A — request versioning: a stale response from a superseded
  /// search never overwrites the newest state.
  int _requestVersion = 0;

  FlightSearchController(this.usecase, this._cache) : super(const FlightSearchState());

  Future<void> search(FlightSearchParams params) async {
    final version = ++_requestVersion;

    final cacheKey = flightSearchCacheKey(
      origin: params.origin,
      destination: params.destination,
      departure: params.departureDate,
      returnDate: params.returnDate,
      passengers: params.adults,
    );

    // Try to load from cache first (for instant UI)
    final cached = await _cache.read(cacheKey);
    if (version != _requestVersion) return; // Superseded mid-flight.
    if (cached != null) {
      final offers = <FlightOffer>[];
      for (final item in (cached['offers'] as List? ?? [])) {
        if (item is Map<String, dynamic>) {
          final offer = offerFromMap(item) as FlightOffer?;
          if (offer != null) offers.add(offer);
        }
      }
      if (offers.isNotEmpty) {
        state = state.copyWith(status: SearchStatus.success, results: offers, fromCache: true);
      }
    }

    state = state.copyWith(status: SearchStatus.loading, isRefreshing: true);
    final result = await usecase.call(
      origin: params.origin,
      destination: params.destination,
      departure: params.departureDate,
      returnDate: params.returnDate,
      passengers: params.adults,
    );
    if (version != _requestVersion) return; // Superseded mid-flight.
    await result.when<Future<void>>(
      success: (offers) async {
        if (offers.isEmpty) {
          state = state.copyWith(status: SearchStatus.empty, results: [], isRefreshing: false, fromCache: false);
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
          state = state.copyWith(status: SearchStatus.success, results: offers, isRefreshing: false, fromCache: false);
        }
      },
      failure: (error) async {
        // On network failure, show cached results if available
        if (state.fromCache && state.results.isNotEmpty) {
          state = state.copyWith(
            status: SearchStatus.success,
            errorMessage: userFacingMessage(error, subject: 'flight search'),
            isRefreshing: false,
          );
        } else {
          state = state.copyWith(
            status: SearchStatus.error,
            errorMessage: userFacingMessage(error, subject: 'flight search'),
            isRefreshing: false,
            fromCache: false,
          );
        }
      },
    );
  }
}
