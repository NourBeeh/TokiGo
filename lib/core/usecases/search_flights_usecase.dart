import 'package:flutter/foundation.dart';
import '../repositories/contracts/flight_repository.dart';
import '../domain/models/offers/flight_offer.dart';
import '../domain/models/search/flight_search_params.dart';
import '../network/api_result.dart';

@immutable
class SearchFlightsUseCase {
  const SearchFlightsUseCase(this.repository);

  final FlightRepository repository;

  Future<ApiResult<List<FlightOffer>>> call({
    required String origin,
    required String destination,
    required DateTime departure,
    DateTime? returnDate,
    int? passengers,
    List<FlightSearchLeg>? legs,
  }) {
    return repository.search(
      origin: origin,
      destination: destination,
      departure: departure,
      returnDate: returnDate,
      passengers: passengers,
      legs: legs,
    );
  }
}
