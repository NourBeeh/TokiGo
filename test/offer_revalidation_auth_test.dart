import 'dart:async';
import 'dart:io' show File;

import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/auth/token_session.dart';
import 'package:tokigo/core/network/api_client.dart';
import 'package:tokigo/core/network/api_error.dart';
import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/core/storage/secure_token_storage.dart';
import 'package:tokigo/features/booking/application/services/offer_revalidation_service.dart';

/// P0-S3 Flutter side — hotel offer revalidation must be authenticated.
///
/// The backend refuses an anonymous Nuitee hotel revalidation because that path
/// calls `prebookHotel` (a real provider hold). These tests pin:
///  * the Bearer header is attached from the app's single secure token store;
///  * no token  -> no request at all (never an anonymous prebook);
///  * 401       -> one `/auth/refresh` then one retry;
///  * renewal failure / 403 -> error outcome, no anonymous retry;
///  * read-only providers keep working for signed-out travellers;
///  * no token is ever logged.

class _Call {
  const _Call(this.path, this.body);
  final String path;
  final Object? body;
}

typedef _Responder =
    Future<ApiResult<Map<String, dynamic>>> Function(
      String path,
      Map<String, String>? headers,
      Object? body,
    );

class _RecordingClient implements ApiClient {
  _RecordingClient({_Responder? responder}) : this._(responder);

  _RecordingClient._(this._responder);

  final _Responder? _responder;

  final List<_Call> calls = <_Call>[];
  final List<Map<String, String>?> headersSeen = <Map<String, String>?>[];

  @override
  String get baseUrl => 'http://test.local';

  @override
  Duration get defaultTimeout => const Duration(seconds: 5);

  @override
  Map<String, String> get defaultHeaders => const <String, String>{};

  @override
  ApiResult<T> mapError<T>(Object error, {StackTrace? stackTrace}) =>
      ApiResult.failure(ApiNetworkError(message: error.toString()));

  @override
  Future<ApiResult<T>> post<T>(
    String path, {
    Object? body,
    Map<String, String>? headers,
    Duration? timeout,
    RequestToken? token,
  }) async {
    calls.add(_Call(path, body));
    headersSeen.add(headers);
    final responded = await _responder?.call(path, headers, body);
    return (responded ??
            ApiResult<Map<String, dynamic>>.failure(
              ApiUnknownError(message: 'no responder for $path'),
            ))
        as ApiResult<T>;
  }

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    Duration? timeout,
    RequestToken? token,
  }) async => throw UnimplementedError('get');

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
}

ApiResult<Map<String, dynamic>> _ok() => ApiResult.success(<String, dynamic>{
  'status': 'OK',
  'offerId': 'offer-1',
  'price': 100,
  'currency': 'USD',
});

OfferRevalidationService _service(
  _RecordingClient client,
  SecureTokenStorage storage,
) => OfferRevalidationService(
  client,
  session: TokenSession(apiClient: client, storage: storage),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('authenticated Nuitee hotel revalidation', () {
    test('attaches the session Bearer token', () async {
      final storage = InMemorySecureTokenStorage();
      await storage.saveAccessToken('access-1');
      final client = _RecordingClient(responder: (_, _, _) async => _ok());

      final outcome = await _service(client, storage).revalidate(
        offerId: 'offer-1',
        providerId: 'nuitee',
        offerType: 'hotel',
      );

      expect(outcome.status, RevalidationStatus.ok);
      expect(client.calls.single.path, '/offers/revalidate');
      expect(client.headersSeen.single?['Authorization'], 'Bearer access-1');
    });

    test('sends no request at all when there is no access token', () async {
      final storage = InMemorySecureTokenStorage();
      final client = _RecordingClient(
        responder: (_, _, _) async => fail('anonymous call must not happen'),
      );

      final outcome = await _service(client, storage).revalidate(
        offerId: 'offer-1',
        providerId: 'nuitee',
        offerType: 'hotel',
      );

      expect(outcome.status, RevalidationStatus.error);
      expect(outcome.reason, contains('Sign-in required'));
      expect(client.calls, isEmpty);
    });

    test('renews an expired access token and retries exactly once', () async {
      final storage = InMemorySecureTokenStorage();
      await storage.saveAccessToken('stale-access');
      await storage.saveRefreshToken('stale-refresh');

      var revalidateCalls = 0;
      final client = _RecordingClient(
        responder: (path, headers, body) async {
          if (path == '/auth/refresh') {
            expect(
              (body as Map<String, dynamic>)['refreshToken'],
              'stale-refresh',
            );
            return ApiResult.success(<String, dynamic>{
              'accessToken': 'fresh-access',
              'refreshToken': 'fresh-refresh',
            });
          }
          revalidateCalls += 1;
          if (revalidateCalls == 1) {
            expect(headers?['Authorization'], 'Bearer stale-access');
            return ApiResult.failure(
              const ApiUnauthorizedError(statusCode: 401),
            );
          }
          expect(headers?['Authorization'], 'Bearer fresh-access');
          return _ok();
        },
      );

      final outcome = await _service(client, storage).revalidate(
        offerId: 'offer-1',
        providerId: 'nuitee',
        offerType: 'hotel',
      );

      expect(outcome.status, RevalidationStatus.ok);
      expect(revalidateCalls, 2);
      expect(client.calls.first.path, '/offers/revalidate');
      expect(client.calls[1].path, '/auth/refresh');
      expect(client.calls.last.path, '/offers/revalidate');
      // The rotated pair is persisted back into the SAME store.
      expect(await storage.getAccessToken(), 'fresh-access');
      expect(await storage.getRefreshToken(), 'fresh-refresh');
    });

    test(
      'a failed renewal clears the session and never retries anonymously',
      () async {
        final storage = InMemorySecureTokenStorage();
        await storage.saveAccessToken('stale-access');
        await storage.saveRefreshToken('stale-refresh');

        var revalidateCalls = 0;
        final client = _RecordingClient(
          responder: (path, headers, body) async {
            if (path == '/auth/refresh') {
              return ApiResult.failure(
                const ApiUnauthorizedError(statusCode: 401),
              );
            }
            revalidateCalls += 1;
            return ApiResult.failure(
              const ApiUnauthorizedError(statusCode: 401),
            );
          },
        );

        final outcome = await _service(client, storage).revalidate(
          offerId: 'offer-1',
          providerId: 'nuitee',
          offerType: 'hotel',
        );

        expect(outcome.status, RevalidationStatus.error);
        expect(outcome.reason, contains('Session expired'));
        expect(revalidateCalls, 1);
        expect(await storage.getAccessToken(), isNull);
        expect(await storage.getRefreshToken(), isNull);
      },
    );

    test('401 with no stored refresh token is terminal', () async {
      final storage = InMemorySecureTokenStorage();
      await storage.saveAccessToken('stale-access');

      var revalidateCalls = 0;
      final client = _RecordingClient(
        responder: (path, headers, body) async {
          revalidateCalls += 1;
          return ApiResult.failure(const ApiUnauthorizedError(statusCode: 401));
        },
      );

      final outcome = await _service(client, storage).revalidate(
        offerId: 'offer-1',
        providerId: 'nuitee',
        offerType: 'hotel',
      );

      expect(outcome.status, RevalidationStatus.error);
      expect(revalidateCalls, 1);
      expect(client.calls.where((c) => c.path == '/auth/refresh'), isEmpty);
    });

    test(
      '403 is surfaced as-is — a new token cannot change authorization',
      () async {
        final storage = InMemorySecureTokenStorage();
        await storage.saveAccessToken('access-1');

        final client = _RecordingClient(
          responder: (path, headers, body) async =>
              ApiResult.failure(const ApiUnauthorizedError(statusCode: 403)),
        );

        final outcome = await _service(client, storage).revalidate(
          offerId: 'offer-1',
          providerId: 'nuitee',
          offerType: 'hotel',
        );

        expect(outcome.status, RevalidationStatus.error);
        expect(client.calls.single.path, '/offers/revalidate');
        expect(client.calls.where((c) => c.path == '/auth/refresh'), isEmpty);
      },
    );

    test(
      'a transport failure is a failure, not an anonymous success',
      () async {
        final storage = InMemorySecureTokenStorage();
        await storage.saveAccessToken('access-1');

        final client = _RecordingClient(
          responder: (_, _, _) async => throw Exception('socket'),
        );

        final outcome = await _service(client, storage).revalidate(
          offerId: 'offer-1',
          providerId: 'nuitee',
          offerType: 'hotel',
        );

        expect(outcome.status, RevalidationStatus.error);
        expect(client.calls.single.path, '/offers/revalidate');
      },
    );
  });

  group('flight revalidation regression', () {
    test(
      'a signed-out traveller still gets the read-only flight check',
      () async {
        final storage = InMemorySecureTokenStorage();
        final client = _RecordingClient(
          responder: (_, _, _) async => ApiResult.success(<String, dynamic>{
            'status': 'OK',
            'offerId': 'offer-1',
            'price': 800,
            'currency': 'USD',
          }),
        );

        final outcome = await _service(client, storage).revalidate(
          offerId: 'offer-1',
          providerId: 'nuitee-flight',
          offerType: 'flight',
        );

        expect(outcome.status, RevalidationStatus.ok);
        expect(outcome.price, 800);
        expect(client.headersSeen.single, isNull);
      },
    );

    test('Duffel flight revalidation is unchanged', () async {
      final storage = InMemorySecureTokenStorage();
      final client = _RecordingClient(
        responder: (_, _, _) async => ApiResult.success(<String, dynamic>{
          'status': 'OK',
          'offerId': 'offer-1',
          'price': 800,
          'currency': 'USD',
        }),
      );

      final outcome = await _service(client, storage).revalidate(
        offerId: 'offer-1',
        providerId: 'duffel-flight',
        offerType: 'flight',
      );

      expect(outcome.status, RevalidationStatus.ok);
      expect(client.calls.single.path, '/offers/revalidate');
    });
  });

  group('token hygiene', () {
    test('the token appears only in the Authorization header', () async {
      final storage = InMemorySecureTokenStorage();
      await storage.saveAccessToken('super-secret-access-value');
      Object? capturedBody;
      final client = _RecordingClient(
        responder: (path, headers, body) async {
          capturedBody = body;
          return _ok();
        },
      );

      await _service(client, storage).revalidate(
        offerId: 'offer-1',
        providerId: 'nuitee',
        offerType: 'hotel',
      );

      expect(
        client.headersSeen.single?['Authorization'],
        'Bearer super-secret-access-value',
      );
      expect(
        capturedBody.toString(),
        isNot(contains('super-secret-access-value')),
      );
    });

    test('no token is written to a log', () {
      final sources = <String>[
        File('lib/core/auth/token_session.dart').readAsStringSync(),
        File(
          'lib/features/booking/application/services/offer_revalidation_service.dart',
        ).readAsStringSync(),
      ];

      for (final source in sources) {
        expect(
          source.contains('print('),
          isFalse,
          reason: 'print() in $source',
        );
        expect(source.contains('debugPrint('), isFalse);
        expect(source.contains('developer.log'), isFalse);
        expect(source.contains('log('), isFalse);
      }
    });
  });

  group('refresh concurrency and retry bounds', () {
    test('concurrent 401s share exactly one refresh operation', () async {
      final storage = InMemorySecureTokenStorage();
      await storage.saveAccessToken('stale-access');
      await storage.saveRefreshToken('stale-refresh');

      var revalidateCalls = 0;
      var refreshCalls = 0;
      final Completer<ApiResult<Map<String, dynamic>>> refreshGate =
          Completer<ApiResult<Map<String, dynamic>>>();
      final client = _RecordingClient(
        responder: (path, headers, body) async {
          if (path == '/auth/refresh') {
            refreshCalls++;
            return refreshGate.future;
          }
          revalidateCalls++;
          // Each operation's first request is rejected; its retry succeeds.
          if (revalidateCalls <= 2) {
            return ApiResult.failure(
              const ApiUnauthorizedError(statusCode: 401),
            );
          }
          return _ok();
        },
      );

      // Two operations sharing ONE TokenSession: the in-flight refresh must
      // be reused, not started twice.
      final session = TokenSession(apiClient: client, storage: storage);
      final first = OfferRevalidationService(client, session: session);
      final second = OfferRevalidationService(client, session: session);

      final Future<RevalidationOutcome> a = first.revalidate(
        offerId: 'offer-1',
        providerId: 'nuitee',
        offerType: 'hotel',
      );
      final Future<RevalidationOutcome> b = second.revalidate(
        offerId: 'offer-2',
        providerId: 'nuitee',
        offerType: 'hotel',
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(refreshCalls, 1);
      expect(revalidateCalls, 2);

      refreshGate.complete(
        ApiResult.success(<String, dynamic>{
          'accessToken': 'fresh-access',
          'refreshToken': 'fresh-refresh',
        }),
      );

      final List<RevalidationOutcome> results = await Future.wait([a, b]);
      expect(results.every((r) => r.status == RevalidationStatus.ok), isTrue);
      expect(refreshCalls, 1);
      expect(revalidateCalls, 4);
      expect(await storage.getAccessToken(), 'fresh-access');
      expect(await storage.getRefreshToken(), 'fresh-refresh');
    });

    test(
      'a refresh transport failure preserves tokens for a later request',
      () async {
        final storage = InMemorySecureTokenStorage();
        await storage.saveAccessToken('stale-access');
        await storage.saveRefreshToken('stale-refresh');

        var revalidateCalls = 0;
        var refreshCalls = 0;
        final client = _RecordingClient(
          responder: (path, headers, body) async {
            if (path == '/auth/refresh') {
              refreshCalls++;
              if (refreshCalls == 1) throw Exception('socket');
              return ApiResult.success(<String, dynamic>{
                'accessToken': 'fresh-access',
                'refreshToken': 'fresh-refresh',
              });
            }
            revalidateCalls++;
            if (revalidateCalls <= 2) {
              return ApiResult.failure(
                const ApiUnauthorizedError(statusCode: 401),
              );
            }
            return _ok();
          },
        );
        final service = _service(client, storage);

        final first = await service.revalidate(
          offerId: 'offer-1',
          providerId: 'nuitee',
          offerType: 'hotel',
        );

        expect(first.status, RevalidationStatus.error);
        expect(first.reason, contains('could not reach'));
        expect(refreshCalls, 1);
        // No retry after a transport failure — and no anonymous fallback.
        expect(revalidateCalls, 1);
        // The stored tokens survive so a later request can retry.
        expect(await storage.getAccessToken(), 'stale-access');
        expect(await storage.getRefreshToken(), 'stale-refresh');

        final second = await service.revalidate(
          offerId: 'offer-1',
          providerId: 'nuitee',
          offerType: 'hotel',
        );

        expect(second.status, RevalidationStatus.ok);
        expect(refreshCalls, 2);
        expect(await storage.getAccessToken(), 'fresh-access');
        expect(await storage.getRefreshToken(), 'fresh-refresh');
      },
    );

    test('a malformed refresh response clears the session', () async {
      final storage = InMemorySecureTokenStorage();
      await storage.saveAccessToken('stale-access');
      await storage.saveRefreshToken('stale-refresh');

      final client = _RecordingClient(
        responder: (path, headers, body) async {
          if (path == '/auth/refresh') {
            // The backend's own rejected-refresh shape: HTTP 200 + error.
            return ApiResult.success(<String, dynamic>{
              'error': 'Invalid refresh token',
            });
          }
          return ApiResult.failure(const ApiUnauthorizedError(statusCode: 401));
        },
      );

      final outcome = await _service(client, storage).revalidate(
        offerId: 'offer-1',
        providerId: 'nuitee',
        offerType: 'hotel',
      );

      expect(outcome.status, RevalidationStatus.error);
      expect(outcome.reason, contains('Session expired'));
      expect(await storage.getAccessToken(), isNull);
      expect(await storage.getRefreshToken(), isNull);
    });

    test('never retries refresh or revalidation indefinitely', () async {
      final storage = InMemorySecureTokenStorage();
      await storage.saveAccessToken('stale-access');
      await storage.saveRefreshToken('stale-refresh');

      var revalidateCalls = 0;
      var refreshCalls = 0;
      final client = _RecordingClient(
        responder: (path, headers, body) async {
          if (path == '/auth/refresh') {
            refreshCalls++;
            return ApiResult.success(<String, dynamic>{
              'accessToken': 'fresh-access',
              'refreshToken': 'fresh-refresh',
            });
          }
          revalidateCalls++;
          // Every revalidation is rejected, forever.
          return ApiResult.failure(const ApiUnauthorizedError(statusCode: 401));
        },
      );

      final outcome = await _service(client, storage).revalidate(
        offerId: 'offer-1',
        providerId: 'nuitee',
        offerType: 'hotel',
      );

      expect(outcome.status, RevalidationStatus.error);
      // One refresh, one retry — then stop.
      expect(refreshCalls, 1);
      expect(revalidateCalls, 2);
    });

    test('a failed refresh never produces an anonymous retry', () async {
      final storage = InMemorySecureTokenStorage();
      await storage.saveAccessToken('stale-access');
      await storage.saveRefreshToken('stale-refresh');

      var revalidateCalls = 0;
      final client = _RecordingClient(
        responder: (path, headers, body) async {
          if (path == '/auth/refresh') {
            throw Exception('socket');
          }
          revalidateCalls++;
          return ApiResult.failure(const ApiUnauthorizedError(statusCode: 401));
        },
      );

      final outcome = await _service(client, storage).revalidate(
        offerId: 'offer-1',
        providerId: 'nuitee',
        offerType: 'hotel',
      );

      expect(outcome.status, RevalidationStatus.error);
      // One authenticated attempt, one refresh, then stop — never a second
      // (anonymous) revalidation.
      expect(revalidateCalls, 1);
      expect(client.calls.where((c) => c.path == '/auth/refresh'), isNotEmpty);
    });
  });
}
