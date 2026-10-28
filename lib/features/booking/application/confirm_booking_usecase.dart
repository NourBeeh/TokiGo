import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/core/repositories/contracts/booking_repository.dart';
import 'package:tokigo/features/booking/domain/booking_record.dart';
import 'package:tokigo/features/booking/application/idempotency_store.dart';

/// Confirms a persisted prepared booking. The idempotency key makes a retried
/// confirm safe — a successful result is cached client-side and the backend
/// also refuses to double-book on a reused key.
class ConfirmBookingUseCase {
  final BookingRepository repository;

  ConfirmBookingUseCase(this.repository);

  Future<ApiResult<BookingRecord>> call({
    required String bookingId,
    required String idempotencyKey,
    required List<dynamic> travelers,
  }) async {
    if (IdempotencyStore.contains(idempotencyKey)) {
      final cached = IdempotencyStore.get<BookingRecord>(idempotencyKey);
      if (cached != null) {
        return ApiResult.success(cached);
      }
    }

    final res = await repository.createBooking(
      bookingId,
      idempotencyKey,
      travelers,
    );

    return res.when(
      success: (record) {
        IdempotencyStore.put(idempotencyKey, record);
        return ApiResult.success(record);
      },
      failure: (error) => ApiResult.failure(error),
    );
  }
}
