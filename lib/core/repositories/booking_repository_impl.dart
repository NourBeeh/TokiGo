import 'package:tokigo/core/domain/models/booking/booking.dart';
import 'package:tokigo/core/network/api_client.dart';
import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/core/repositories/contracts/booking_repository.dart';
import 'package:tokigo/core/storage/secure_token_storage.dart';
import 'package:tokigo/features/booking/domain/booking_record.dart';

/// Flutter side of the Phase 4A booking contract.
///
/// Every method targets the real backend surface (`/bookings/prepare`,
/// `/bookings/revalidate`, `/bookings`, `/bookings/:id`, `/bookings/:id/status`,
/// `/bookings/:id/cancel`). The authoritative price always comes from the
/// server response — never from the caller. Failures are returned as
/// [ApiError]s carrying the backend `{code, message}` body so the controller
/// can classify them via `bookingErrorCodeFrom`.
///
/// AUTH: the backend guards every `/bookings/*` route with JWT and derives the
/// user from the token. This client used to send no `Authorization` header at
/// all, so each call was answered with 401 and the funnel could never prepare a
/// booking. The header is now attached per call from [tokenStorage]; when
/// nobody is signed in it is omitted and the backend's 401 is surfaced as-is
/// (the funnel asks the traveller to sign in rather than inventing identity).
class BookingRepositoryImpl implements BookingRepository {
  final ApiClient client;
  final SecureTokenStorage? tokenStorage;

  BookingRepositoryImpl(this.client, {this.tokenStorage});

  /// `Authorization` header for the current session, or null when signed out.
  Future<Map<String, String>?> _authHeaders() async {
    final token = await tokenStorage?.getAccessToken();
    if (token == null || token.isEmpty) return null;
    return <String, String>{'Authorization': 'Bearer $token'};
  }

  @override
  Future<ApiResult<BookingRecord>> prepareBooking(
    String offerId,
    String providerId,
    String searchId,
  ) async {
    final res = await client.post<Map<String, dynamic>>(
      '/bookings/prepare',
      headers: await _authHeaders(),
      body: {
        'offerId': offerId,
        'providerId': providerId,
        'searchId': searchId,
      },
    );
    return res.when(
      success: (data) => ApiResult.success(_mapToBookingRecord(data)),
      failure: (error) => ApiResult.failure(error),
    );
  }

  @override
  Future<ApiResult<BookingRecord>> revalidateBooking(String bookingId) async {
    final res = await client.post<Map<String, dynamic>>(
      '/bookings/revalidate',
      headers: await _authHeaders(),
      body: {'bookingId': bookingId},
    );
    return res.when(
      success: (data) => ApiResult.success(_mapToBookingRecord(data)),
      failure: (error) => ApiResult.failure(error),
    );
  }

  @override
  Future<ApiResult<BookingRecord>> createBooking(
    String bookingId,
    String idempotencyKey,
    List<dynamic> travelers,
  ) async {
    final res = await client.post<Map<String, dynamic>>(
      '/bookings',
      headers: await _authHeaders(),
      body: {
        'bookingId': bookingId,
        'idempotencyKey': idempotencyKey,
        'travelers': travelers,
      },
    );
    return res.when(
      success: (data) => ApiResult.success(_mapToBookingRecord(data)),
      failure: (error) => ApiResult.failure(error),
    );
  }

  @override
  Future<ApiResult<BookingRecord>> getBooking(String bookingId) async {
    final res = await client.get<Map<String, dynamic>>(
      '/bookings/$bookingId',
      headers: await _authHeaders(),
    );
    return res.when(
      success: (data) => ApiResult.success(_mapToBookingRecord(data)),
      failure: (error) => ApiResult.failure(error),
    );
  }

  @override
  Future<ApiResult<BookingRecord>> getBookingStatus(String bookingId) async {
    final res = await client.get<Map<String, dynamic>>(
      '/bookings/$bookingId/status',
      headers: await _authHeaders(),
    );
    return res.when(
      success: (data) => ApiResult.success(_mapToBookingRecord(data)),
      failure: (error) => ApiResult.failure(error),
    );
  }

  @override
  Future<ApiResult<void>> cancelBooking(String bookingId) async {
    final res = await client.post<Map<String, dynamic>>(
      '/bookings/$bookingId/cancel',
      headers: await _authHeaders(),
      body: const {},
    );
    return res.when(
      success: (_) => const ApiResult<void>.success(null),
      failure: (error) => ApiResult.failure(error),
    );
  }

  BookingRecord _mapToBookingRecord(Map<String, dynamic> data) {
    final createdAt = _parseDate(data['createdAt']) ?? DateTime.now();
    return BookingRecord(
      bookingId: (data['id'] ?? '').toString(),
      userId: (data['userId'] ?? '').toString(),
      searchId: data['searchId']?.toString(),
      offerId: (data['offerId'] ?? '').toString(),
      providerId: (data['providerId'] ?? '').toString(),
      providerName: (data['providerName'] ?? '').toString(),
      type: (data['type'] ?? '').toString(),
      status: _parseStatus(data['status']?.toString()),
      currency: (data['currency'] ?? 'USD').toString(),
      authoritativePrice: _toDouble(data['authoritativePrice']),
      priceBreakdown: _parsePriceBreakdown(data['priceBreakdown']),
      travelers: _parseTravelers(data['travelers']),
      bookingReference: (data['bookingReference'] ?? '').toString(),
      createdAt: createdAt,
      updatedAt: _parseDate(data['updatedAt']) ?? createdAt,
      expiration: _parseDate(data['expiresAt']),
    );
  }

  BookingStatus _parseStatus(String? raw) {
    switch (raw) {
      case 'confirmed':
        return BookingStatus.confirmed;
      case 'cancelled':
        return BookingStatus.cancelled;
      case 'failed':
      case 'expired':
        return BookingStatus.failed;
      case 'prepared':
      case 'revalidated':
      case 'confirming':
        return BookingStatus.pending;
      default:
        return BookingStatus.draft;
    }
  }

  PriceBreakdown _parsePriceBreakdown(dynamic raw) {
    if (raw is! Map) return PriceBreakdown.empty;
    return PriceBreakdown(
      basePrice: _toDouble(raw['basePrice']),
      taxes: _toDouble(raw['taxes']),
      fees: _toDouble(raw['fees']),
      currency: (raw['currency'] ?? 'USD').toString(),
    );
  }

  List<Passenger> _parseTravelers(dynamic raw) {
    if (raw is! List) return const <Passenger>[];
    return raw
        .whereType<Map>()
        .map(
          (t) => Passenger(
            firstName: (t['firstName'] ?? '').toString(),
            lastName: (t['lastName'] ?? '').toString(),
            email: t['email']?.toString(),
            phone: t['phone']?.toString(),
          ),
        )
        .toList(growable: false);
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  DateTime? _parseDate(dynamic value) {
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }
}
