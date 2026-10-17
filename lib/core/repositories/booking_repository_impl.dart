import 'package:tokigo/core/domain/models/booking/booking.dart';
import 'package:tokigo/core/network/api_client.dart';
import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/core/repositories/contracts/booking_repository.dart';
import 'package:tokigo/features/booking/domain/booking_record.dart';

class BookingRepositoryImpl implements BookingRepository {
  final ApiClient client;

  BookingRepositoryImpl(this.client);

  @override
  Future<ApiResult<BookingRecord>> prepareBooking(String offerId, String providerId, String searchId) async {
    // Note: Backend contract may differ; map to BookingRecord minimally.
    final res = await client.post<Map<String, dynamic>>('/bookings/prepare', body: {
      'offerId': offerId,
      'providerId': providerId,
      'searchId': searchId,
    });
    return res.when(
      success: (data) => ApiResult.success(_mapToBookingRecord(data, 'prepared')),
      failure: (error) => ApiResult.failure(error),
    );
  }

  @override
  Future<ApiResult<BookingRecord>> revalidateBooking(String bookingId) async {
    final res = await client.post<Map<String, dynamic>>('/bookings/revalidate', body: {
      'bookingId': bookingId,
    });
    return res.when(
      success: (data) => ApiResult.success(_mapToBookingRecord(data, 'revalidated')),
      failure: (error) => ApiResult.failure(error),
    );
  }

  @override
  Future<ApiResult<BookingRecord>> createBooking(String offerId, String providerId, String idempotencyKey, List<dynamic> travelers) async {
    final res = await client.post<Map<String, dynamic>>('/bookings', body: {
      'offerId': offerId,
      'providerId': providerId,
      'idempotencyKey': idempotencyKey,
      'travelers': travelers,
    });
    return res.when(
      success: (data) => ApiResult.success(_mapToBookingRecord(data, 'confirmed')),
      failure: (error) => ApiResult.failure(error),
    );
  }

  @override
  Future<ApiResult<BookingRecord>> getBooking(String bookingId) {
    throw UnimplementedError('getBooking not implemented in Phase 7A');
  }

  @override
  Future<ApiResult<void>> cancelBooking(String bookingId) {
    throw UnimplementedError('cancelBooking not implemented in Phase 7A');
  }

  @override
  Future<ApiResult<BookingRecord>> getBookingStatus(String bookingId) {
    throw UnimplementedError('getBookingStatus not implemented in Phase 7A');
  }

  BookingRecord _mapToBookingRecord(Map<String, dynamic> data, String status) {
    return BookingRecord(
      bookingId: data['id'] ?? '',
      userId: data['userId'] ?? '',
      searchId: data['searchId'],
      offerId: data['offerId'] ?? '',
      providerId: data['providerId'] ?? '',
      providerName: data['providerName'] ?? '',
      type: data['type'] ?? '',
      status: _parseStatus(status),
      currency: data['currency'] ?? 'USD',
      authoritativePrice: (data['authoritativePrice'] ?? 0).toDouble(),
      priceBreakdown: PriceBreakdown.empty,
      travelers: const [],
      bookingReference: data['bookingReference'] ?? '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  BookingStatus _parseStatus(String s) {
    switch (s) {
      case 'prepared':
        return BookingStatus.pending;
      case 'revalidated':
        return BookingStatus.pending;
      case 'confirmed':
        return BookingStatus.confirmed;
      default:
        return BookingStatus.draft;
    }
  }
}
