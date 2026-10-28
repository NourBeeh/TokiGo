import 'package:tokigo/core/domain/models/offers/car_offer.dart';
import 'package:tokigo/core/repositories/contracts/car_repository.dart';
import 'package:tokigo/core/network/http_api_client.dart';
import 'package:tokigo/core/network/api_result.dart';

class CarRepositoryImpl implements CarRepository {
  final HttpApiClient client;
  CarRepositoryImpl(this.client);
  @override
  Future<ApiResult<List<CarOffer>>> search({
    required String pickupLocation,
    required DateTime pickupTime,
    required DateTime dropoffTime,
  }) async {
    return const ApiResult.success([]);
  }

  @override
  Future<ApiResult<CarOffer>> getById(String id) async => ApiResult.success(
    CarOffer(
      id: id,
      providerId: 'p',
      providerName: 'n',
      title: 't',
      price: 0,
      currency: 'USD',
      pickupLocation: 'a',
      dropoffLocation: 'b',
      pickupTime: DateTime.now(),
      dropoffTime: DateTime.now(),
      carType: 'sedan',
    ),
  );
}
