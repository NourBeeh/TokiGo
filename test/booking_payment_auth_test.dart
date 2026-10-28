import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/network/api_client.dart';
import 'package:tokigo/core/network/api_error.dart';
import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/core/repositories/booking_repository_impl.dart';
import 'package:tokigo/core/storage/secure_token_storage.dart';
import 'package:tokigo/features/booking/application/services/checkout_payment_service.dart';

/// Authenticated-call contracts (2026-10-25).
///
/// `/payments/*` (except the signed webhook) and every `/bookings/*` route are
/// JWT-guarded on the backend. These clients used to send no `Authorization`
/// header at all, so the whole funnel answered 401. What is pinned here:
/// * a signed-in session attaches `Bearer <token>` to every call;
/// * a signed-out session attaches NO header (the backend's 401 is the honest
///   answer — we never fabricate a token);
/// * the payment flow still degrades to `PaymentOutcome.unavailable`.
class _RecordedCall {
  _RecordedCall(this.path, this.headers, this.body);

  final String path;
  final Map<String, String>? headers;
  final Object? body;
}

class _FakeClient implements ApiClient {
  _FakeClient(this._responder);

  final ApiResult<Map<String, dynamic>> Function(String path) _responder;
  final List<_RecordedCall> calls = <_RecordedCall>[];

  @override
  String get baseUrl => 'http://test.local';

  @override
  Duration get defaultTimeout => const Duration(seconds: 5);

  @override
  Map<String, String> get defaultHeaders => const <String, String>{};

  @override
  Future<ApiResult<T>> post<T>(
    String path, {
    Object? body,
    Map<String, String>? headers,
    Duration? timeout,
    RequestToken? token,
  }) async {
    calls.add(_RecordedCall(path, headers, body));
    return _responder(path) as ApiResult<T>;
  }

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    Duration? timeout,
    RequestToken? token,
  }) async {
    calls.add(_RecordedCall(path, headers, null));
    return _responder(path) as ApiResult<T>;
  }

  @override
  Future<ApiResult<T>> put<T>(
    String path, {
    Object? body,
    Map<String, String>? headers,
    Duration? timeout,
    RequestToken? token,
  }) async => throw UnimplementedError('put');

  @override
  Future<ApiResult<T>> patch<T>(
    String path, {
    Object? body,
    Map<String, String>? headers,
    Duration? timeout,
    RequestToken? token,
  }) async => throw UnimplementedError('patch');

  @override
  Future<ApiResult<T>> delete<T>(
    String path, {
    Map<String, String>? headers,
    Duration? timeout,
    RequestToken? token,
  }) async => throw UnimplementedError('delete');

  @override
  ApiResult<T> mapError<T>(Object error, {StackTrace? stackTrace}) =>
      ApiResult<T>.failure(ApiUnknownError(message: '$error'));
}

ApiResult<Map<String, dynamic>> _paymentResponder(String path) {
  if (path == '/payments/intent') {
    return ApiResult<Map<String, dynamic>>.success(<String, dynamic>{
      'status': 'OK',
      'intent': <String, dynamic>{'paymentId': 'pay-1'},
    });
  }
  if (path == '/payments/confirm') {
    return ApiResult<Map<String, dynamic>>.success(<String, dynamic>{
      'intent': <String, dynamic>{'status': 'SUCCEEDED'},
    });
  }
  return ApiResult<Map<String, dynamic>>.failure(
    ApiClientError(message: 'unexpected $path'),
  );
}

ApiResult<Map<String, dynamic>> _bookingResponder(String path) {
  return ApiResult<Map<String, dynamic>>.success(<String, dynamic>{
    'id': 'bk-1',
    'offerId': 'r-1',
    'providerId': 'nuitee',
    'providerName': 'Nuitee Connect',
    'type': 'hotel',
    'status': 'prepared',
    'currency': 'USD',
    'authoritativePrice': 305.94,
  });
}

void main() {
  group('CheckoutPaymentService — bearer token', () {
    test('attaches the stored access token to intent and confirm', () async {
      final storage = InMemorySecureTokenStorage();
      await storage.saveAccessToken('jwt-abc');
      final client = _FakeClient(_paymentResponder);
      final service = CheckoutPaymentService(client, tokenStorage: storage);

      final result = await service.pay(
        bookingId: 'bk-1',
        amount: 1250.5,
        currency: 'EGP',
        market: 'EG',
        idempotencyKey: 'key-1',
        method: 'card',
      );

      expect(result.outcome, PaymentOutcome.succeeded);
      expect(client.calls.map((c) => c.path), <String>[
        '/payments/intent',
        '/payments/confirm',
      ]);
      for (final call in client.calls) {
        expect(call.headers, <String, String>{
          'Authorization': 'Bearer jwt-abc',
        });
      }
    });

    test('sends no Authorization header when signed out', () async {
      final client = _FakeClient(_paymentResponder);
      final service = CheckoutPaymentService(
        client,
        tokenStorage: InMemorySecureTokenStorage(),
      );

      await service.pay(
        bookingId: 'bk-1',
        amount: 10,
        currency: 'EGP',
        market: 'EG',
        idempotencyKey: 'key-2',
        method: 'wallet',
      );

      expect(client.calls, isNotEmpty);
      for (final call in client.calls) {
        expect(call.headers, isNull);
      }
    });

    test('a rejected intent still degrades to unavailable', () async {
      final storage = InMemorySecureTokenStorage();
      await storage.saveAccessToken('jwt-abc');
      final client = _FakeClient(
        (_) => ApiResult<Map<String, dynamic>>.failure(
          ApiUnauthorizedError(message: 'Unauthorized'),
        ),
      );
      final service = CheckoutPaymentService(client, tokenStorage: storage);

      final result = await service.pay(
        bookingId: 'bk-1',
        amount: 10,
        currency: 'EGP',
        market: 'EG',
        idempotencyKey: 'key-3',
        method: 'card',
      );

      expect(result.outcome, PaymentOutcome.unavailable);
    });
  });

  group('BookingRepositoryImpl — bearer token', () {
    test(
      'prepareBooking carries the token and reads the server price',
      () async {
        final storage = InMemorySecureTokenStorage();
        await storage.saveAccessToken('jwt-xyz');
        final client = _FakeClient(_bookingResponder);
        final repo = BookingRepositoryImpl(client, tokenStorage: storage);

        final result = await repo.prepareBooking('r-1', 'nuitee', 's-1');

        final record = result.when(
          success: (record) => record,
          failure: (error) => throw StateError('unexpected failure: $error'),
        );
        expect(record.bookingId, 'bk-1');
        expect(record.authoritativePrice, 305.94);
        expect(client.calls.single.path, '/bookings/prepare');
        expect(client.calls.single.headers, <String, String>{
          'Authorization': 'Bearer jwt-xyz',
        });
      },
    );

    test('every booking call is authenticated, none is anonymous', () async {
      final storage = InMemorySecureTokenStorage();
      await storage.saveAccessToken('jwt-xyz');
      final client = _FakeClient(_bookingResponder);
      final repo = BookingRepositoryImpl(client, tokenStorage: storage);

      await repo.revalidateBooking('bk-1');
      await repo.createBooking('bk-1', 'idem-1', <dynamic>[]);
      await repo.getBooking('bk-1');
      await repo.getBookingStatus('bk-1');
      await repo.cancelBooking('bk-1');

      expect(client.calls, hasLength(5));
      for (final call in client.calls) {
        expect(call.headers?['Authorization'], 'Bearer jwt-xyz');
      }
    });

    test('signed out attaches no header (backend answers 401)', () async {
      final client = _FakeClient(_bookingResponder);
      final repo = BookingRepositoryImpl(client);

      await repo.prepareBooking('r-1', 'nuitee', 's-1');

      expect(client.calls.single.headers, isNull);
    });
  });
}
