import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tokigo/core/domain/models/search/hotel_search_params.dart';
import 'package:tokigo/core/domain/models/offers/hotel_offer.dart';
import 'package:tokigo/core/events/events_tracker.dart';
import 'package:tokigo/core/network/user_facing_message.dart';
import 'package:tokigo/core/repositories/contracts/hotel_repository.dart';
import 'package:tokigo/core/repositories/impl/hotel_repository_impl.dart';
import 'package:tokigo/core/storage/offline_cache.dart';
import 'package:tokigo/core/storage/offline_cache_serializers.dart';

enum HotelSearchStatus { idle, loading, success, empty, error }

class HotelSearchState {
  final HotelSearchStatus status;
  final List<HotelOffer> results;
  final String? errorMessage;
  final bool fromCache;

  const HotelSearchState({this.status = HotelSearchStatus.idle, this.results = const [], this.errorMessage, this.fromCache = false});
  HotelSearchState copyWith({HotelSearchStatus? status, List<HotelOffer>? results, String? errorMessage, bool? fromCache}) {
    return HotelSearchState(status: status ?? this.status, results: results ?? this.results, errorMessage: errorMessage ?? this.errorMessage, fromCache: fromCache ?? this.fromCache);
  }
}

class HotelSearchController extends StateNotifier<HotelSearchState> {
  HotelSearchController(
    this.repository,
    this._cache, {
    EventsTracker? eventsTracker,
  })  : _events = eventsTracker,
        super(const HotelSearchState());

  final HotelRepository repository;
  final OfflineCache _cache;

  /// Phase 3A — request versioning: a stale response (from an older
  /// superseded search) never overwrites the state of the newest one.
  int _requestVersion = 0;

  /// Phase 1C — optional behavioral tracker. Null keeps the controller
  /// exactly as before (tests/legacy wiring); when present, successful
  /// searches emit a fire-and-forget `hotel_search` event.
  final EventsTracker? _events;

  Future<void> search(HotelSearchParams params) async {
    // Phase 3A — supersede any in-flight search: this call owns the state
    // from here on; the old one's late results are dropped by version.
    final version = ++_requestVersion;

    // Phase 3A — seed the rich params through the repository's extras
    // contract BEFORE the call (the interface's own fields stay stable).
    final repo = repository;
    if (repo is HotelRepositoryImpl) {
      repo.setNextSearchExtras(
        rooms: params.rooms,
        minRating: params.minRating,
        maxPrice: params.maxPrice,
        minPrice: params.minPrice,
        amenities: params.amenities,
      );
    }

    final cacheKey = hotelSearchCacheKey(
      city: params.destination,
      checkIn: params.checkIn,
      checkOut: params.checkOut,
      guests: params.adults,
    );

    // Try to load from cache first
    final cached = await _cache.read(cacheKey);
    if (version != _requestVersion) return; // Superseded mid-flight.
    if (cached != null) {
      final offers = <HotelOffer>[];
      for (final item in (cached['offers'] as List? ?? [])) {
        if (item is Map<String, dynamic>) {
          final offer = offerFromMap(item) as HotelOffer?;
          if (offer != null) offers.add(offer);
        }
      }
      if (offers.isNotEmpty) {
        state = state.copyWith(status: HotelSearchStatus.success, results: offers, fromCache: true);
      }
    }

    state = state.copyWith(status: HotelSearchStatus.loading);
    final result = await repository.search(
      city: params.destination,
      checkIn: params.checkIn,
      checkOut: params.checkOut,
      guests: params.adults,
    );
    if (version != _requestVersion) return; // Superseded mid-flight.
    await result.when<Future<void>>(
      success: (offers) async {
        if (offers.isEmpty) {
          state = state.copyWith(status: HotelSearchStatus.empty, results: [], fromCache: false);
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
          state = state.copyWith(status: HotelSearchStatus.success, results: offers, fromCache: false);
          // Phase 1C — behavioral signal (fire-and-forget, silent on
          // failure; guests are skipped inside the tracker).
          _events?.hotelSearch(
            destination: params.destination,
            minPrice: params.minPrice,
            maxPrice: params.maxPrice,
          );
        }
      },
      failure: (e) async {
        if (state.fromCache && state.results.isNotEmpty) {
          state = state.copyWith(
            status: HotelSearchStatus.success,
            errorMessage: userFacingMessage(e, subject: 'hotel search'),
          );
        } else {
          state = state.copyWith(
            status: HotelSearchStatus.error,
            errorMessage: userFacingMessage(e, subject: 'hotel search'),
            fromCache: false,
          );
        }
      },
    );
  }
}