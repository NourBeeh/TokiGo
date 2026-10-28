import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tokigo/core/repositories/contracts/car_repository.dart';
import 'package:tokigo/core/repositories/contracts/hotel_repository.dart';
import 'package:tokigo/core/repositories/impl/hotel_repository_impl.dart';
import 'package:tokigo/core/repositories/impl/car_repository_impl.dart';
import 'package:tokigo/core/network/http_api_client.dart';
import 'package:tokigo/core/storage/offline_cache_providers.dart';
import 'package:tokigo/features/home/providers/home_providers.dart'
    show eventsTrackerProvider;
import 'package:tokigo/features/search/application/controllers/hotel_search_controller.dart';
import 'package:tokigo/features/search/application/controllers/car_search_controller.dart';

final httpClientProvider = Provider((ref) => HttpApiClient());

/// Typed against the repository contract, not the HTTP implementation, so a
/// test/audit can substitute a real-shaped fake without a network.
final hotelRepositoryProvider = Provider<HotelRepository>((ref) {
  final client = ref.watch(httpClientProvider);
  return HotelRepositoryImpl(client);
});

final carRepositoryProvider = Provider<CarRepository>((ref) {
  final client = ref.watch(httpClientProvider);
  return CarRepositoryImpl(client);
});

final hotelSearchControllerProvider =
    StateNotifierProvider<HotelSearchController, HotelSearchState>((ref) {
      final repo = ref.watch(hotelRepositoryProvider);
      final cache = ref.watch(offlineCacheProvider);
      // Phase 1C — successful hotel searches emit behavioral events.
      final events = ref.watch(eventsTrackerProvider);
      return HotelSearchController(repo, cache, eventsTracker: events);
    });

final carSearchControllerProvider =
    StateNotifierProvider<CarSearchController, CarSearchState>((ref) {
      final repo = ref.watch(carRepositoryProvider);
      final cache = ref.watch(offlineCacheProvider);
      return CarSearchController(repo, cache);
    });
