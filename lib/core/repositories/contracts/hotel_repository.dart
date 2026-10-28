import '../../domain/models/offers/hotel_offer.dart';
import '../../../core/network/api_result.dart';

abstract interface class HotelRepository {
  Future<ApiResult<List<HotelOffer>>> search({
    required String city,
    required DateTime checkIn,
    required DateTime checkOut,
    int? guests,
  });

  Future<ApiResult<HotelOffer>> getById(String id);
}
