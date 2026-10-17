import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tokigo/core/usecases/search_flights_usecase.dart';
import 'package:tokigo/features/search/application/controllers/flight_search_controller.dart';
import 'package:tokigo/core/repositories/impl/flight_repository_impl.dart';
import 'package:tokigo/core/network/http_api_client.dart';
import 'package:tokigo/core/storage/offline_cache_providers.dart';

final flightApiClientProvider = Provider((ref) => HttpApiClient());

final flightRepositoryProvider = Provider((ref) {
  final client = ref.watch(flightApiClientProvider);
  return FlightRepositoryImpl(client);
});

final searchFlightsUseCaseProvider = Provider((ref) {
  final repo = ref.watch(flightRepositoryProvider);
  return SearchFlightsUseCase(repo);
});

final flightSearchControllerProvider = StateNotifierProvider<FlightSearchController, FlightSearchState>((ref) {
  final usecase = ref.watch(searchFlightsUseCaseProvider);
  final cache = ref.watch(offlineCacheProvider);
  return FlightSearchController(usecase, cache);
});
