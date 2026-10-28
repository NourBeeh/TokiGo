import '../../domain/models/offers/travel_package_offer.dart';
import '../../../core/network/api_result.dart';

abstract interface class PackageRepository {
  Future<ApiResult<List<TravelPackageOffer>>> search({
    String? destination,
    int? minDays,
    int? maxDays,
  });

  Future<ApiResult<TravelPackageOffer>> getById(String id);
}
