import '../../domain/models/offers/flight_offer.dart';
import '../../domain/models/search/flight_search_params.dart';
import '../../../core/network/api_result.dart';

abstract interface class FlightRepository {
  Future<ApiResult<List<FlightOffer>>> search({
    required String origin,
    required String destination,
    required DateTime departure,
    DateTime? returnDate,
    int? passengers,
    List<FlightSearchLeg>? legs,
  });

  Future<ApiResult<FlightOffer>> getById(String id);
}
