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
    int? children,
    int? infants,
    List<int>? childAges,
    List<int>? infantAges,
    List<FlightSearchLeg>? legs,
    String? cabinClass,
    bool? directOnly,
  });

  Future<ApiResult<FlightOffer>> getById(String id);
}
