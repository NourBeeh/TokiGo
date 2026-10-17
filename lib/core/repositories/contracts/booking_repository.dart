import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/features/booking/domain/booking_record.dart';

abstract class BookingRepository {
  Future<ApiResult<BookingRecord>> prepareBooking(String offerId, String providerId, String searchId);
  Future<ApiResult<BookingRecord>> revalidateBooking(String bookingId);
  Future<ApiResult<BookingRecord>> createBooking(String offerId, String providerId, String idempotencyKey, List<dynamic> travelers);
  Future<ApiResult<BookingRecord>> getBooking(String bookingId);
  Future<ApiResult<void>> cancelBooking(String bookingId);
  Future<ApiResult<BookingRecord>> getBookingStatus(String bookingId);
}
