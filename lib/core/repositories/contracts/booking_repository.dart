import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/features/booking/domain/booking_record.dart';

abstract class BookingRepository {
  /// Prepare a booking: backend capability-checks the provider and revalidates
  /// the offer to obtain an authoritative price (never the client's snapshot).
  Future<ApiResult<BookingRecord>> prepareBooking(
    String offerId,
    String providerId,
    String searchId,
  );

  /// Revalidate a prepared booking against the live provider offer.
  Future<ApiResult<BookingRecord>> revalidateBooking(String bookingId);

  /// Confirm (create) a booking. [bookingId] identifies the persisted prepared
  /// booking; [idempotencyKey] makes retries safe (the backend refuses to
  /// double-book on a reused key).
  Future<ApiResult<BookingRecord>> createBooking(
    String bookingId,
    String idempotencyKey,
    List<dynamic> travelers,
  );

  Future<ApiResult<BookingRecord>> getBooking(String bookingId);

  Future<ApiResult<void>> cancelBooking(String bookingId);

  Future<ApiResult<BookingRecord>> getBookingStatus(String bookingId);
}
