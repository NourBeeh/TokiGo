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

/// The shared price/terms-change decision surface.
///
/// Kept separate from [BookingRepository] so existing booking repositories and
/// test doubles remain valid; the real implementation implements both.
abstract class PriceChangeDecisionRepository {
  /// Record the customer's explicit decision on a revalidated price/terms
  /// change. The expected values bind the decision to exactly what was shown.
  Future<ApiResult<BookingRecord>> decidePriceChange(
    String bookingId, {
    required String decision,
    double? expectedPrice,
    String? expectedCurrency,
    String? expectedTermsVersion,
  });
}
