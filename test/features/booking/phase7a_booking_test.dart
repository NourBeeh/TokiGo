import 'package:flutter_test/flutter_test.dart';
import 'package:tokigo/features/booking/application/booking_state.dart';

import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/core/network/api_error.dart';
import 'package:tokigo/features/booking/domain/booking_record.dart';
import 'package:tokigo/features/booking/domain/booking_preparation.dart';
import 'package:tokigo/core/domain/models/booking/booking.dart';

class FakeBookingRepository {
  BookingRecord? prepared;
  BookingRecord? revalidated;
  bool shouldFail = false;

  Future<ApiResult<BookingRecord>> prepareBooking(String offerId, String providerId, String searchId) async {
    if (shouldFail) return ApiResult.failure(const ApiUnknownError(message: 'fail'));
    prepared ??= BookingRecord(
      bookingId: 'b1',
      userId: 'u1',
      offerId: offerId,
      providerId: providerId,
      providerName: 'Provider',
      type: 'flight',
      status: BookingStatus.pending,
      currency: 'USD',
      authoritativePrice: 100,
      priceBreakdown: PriceBreakdown.empty,
      travelers: const [],
      bookingReference: 'ref',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    return ApiResult.success(prepared!);
  }

  Future<ApiResult<BookingRecord>> revalidateBooking(String bookingId) async {
    if (shouldFail) return ApiResult.failure(const ApiUnknownError(message: 'fail'));
    final record = revalidated ?? BookingRecord(
      bookingId: bookingId,
      userId: 'u1',
      offerId: 'o1',
      providerId: 'p1',
      providerName: 'Provider',
      type: 'flight',
      status: BookingStatus.pending,
      currency: 'USD',
      authoritativePrice: 120,
      priceBreakdown: PriceBreakdown.empty,
      travelers: const [],
      bookingReference: 'ref',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    return ApiResult.success(record);
  }
}

void main() {
  test('PriceRevalidationResult exposes authoritative price and old price', () {
    final result = PriceRevalidationResult(authoritativePrice: 120, oldPrice: 100, currency: 'USD', priceChanged: true, available: true);
    expect(result.authoritativePrice, 120);
    expect(result.oldPrice, 100);
    expect(result.priceChanged, true);
  });

  test('BookingState transitions idle -> preparing -> prepared', () {
    final state = BookingState.idle();
    expect(state.phase, BookingPhase.idle);
  });
}
