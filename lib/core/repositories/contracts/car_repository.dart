import '../../domain/models/offers/car_offer.dart';
import '../../../core/network/api_result.dart';

abstract interface class CarRepository {
  Future<ApiResult<List<CarOffer>>> search({
    required String pickupLocation,
    required DateTime pickupTime,
    required DateTime dropoffTime,
  });

  Future<ApiResult<CarOffer>> getById(String id);
}
