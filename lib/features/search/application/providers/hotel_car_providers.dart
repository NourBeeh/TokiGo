import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tokigo/core/events/events_tracker.dart';
import 'package:tokigo/core/repositories/impl/hotel_repository_impl.dart';
import 'package:tokigo/core/repositories/impl/car_repository_impl.dart';
import 'package:tokigo/core/network/http_api_client.dart';
import 'package:tokigo/core/storage/offline_cache_providers.dart';
import 'package:tokigo/core/storage/secure_token_storage_provider.dart';
import 'package:tokigo/features/home/providers/home_providers.dart'
    show apiClientProvider, eventsTrackerProvider;
import 'package:tokigo/features/search/application/controllers/hotel_search_controller.dart';
import 'package:tokigo/features/search/application/controllers/car_search_controller.dart';

final httpClientProvider = Provider((ref) => HttpApiClient());

final hotelRepositoryProvider = Provider((ref) {
  final client = ref.watch(httpClientProvider);
  return HotelRepositoryImpl(client);
});

final carRepositoryProvider = Provider((ref) {
  final client = ref.watch(httpClientProvider);
  return CarRepositoryImpl(client);
});

final hotelSearchControllerProvider = StateNotifierProvider<HotelSearchController, HotelSearchState>((ref) {
  final repo = ref.watch(hotelRepositoryProvider);
  final cache = ref.watch(offlineCacheProvider);
  // Phase 1C — successful hotel searches emit behavioral events.
  final events = ref.watch(eventsTrackerProvider);
  return HotelSearchController(repo, cache, eventsTracker: events);
});

final carSearchControllerProvider = StateNotifierProvider<CarSearchController, CarSearchState>((ref) {
  final repo = ref.watch(carRepositoryProvider);
  final cache = ref.watch(offlineCacheProvider);
  return CarSearchController(repo, cache);
});
