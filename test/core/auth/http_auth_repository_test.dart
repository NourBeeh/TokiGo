import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/auth/auth_repository.dart';
import 'package:tokigo/core/auth/http_auth_repository.dart';
import 'package:tokigo/core/network/api_client.dart';
import 'package:tokigo/core/network/api_error.dart';
import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/core/storage/secure_token_storage.dart';

/// Records requests and replays scripted [ApiResult]s — no real sockets.
class _FakeApiClient implements ApiClient {
  _FakeApiClient();

  final List<({String method, String path, Map<String, String>? headers, Object? body})>
      calls = <({String method, String path, Map<String, String>? headers, Object? body})>[];

  ApiResult<Map<String, dynamic>> Function(String path, Map<String, String>? headers, Object? body)?
      handler;

  @override
  String get baseUrl => 'http://fake.local';

  @override
  Duration get defaultTimeout => const Duration(seconds: 5);

  @override
  Map<String, String> get defaultHeaders => {'Content-Type': 'application/json'};

  @override
  Future<ApiResult<T>> get<T>(String path,
      {Map<String, String>? queryParameters, Map<String, String>? headers, Duration? timeout, RequestToken? token}) async {
    calls.add((method: 'GET', path: path, headers: headers, body: null));
    return handler!(path, headers, null) as ApiResult<T>;
  }

  @override
  Future<ApiResult<T>> post<T>(String path,
      {Object? body, Map<String, String>? headers, Duration? timeout, RequestToken? token}) async {
    calls.add((method: 'POST', path: path, headers: headers, body: body));
    return handler!(path, headers, body) as ApiResult<T>;
  }

  @override
  Future<ApiResult<T>> put<T>(String path,
      {Object? body, Map<String, String>? headers, Duration? timeout, RequestToken? token}) async {
    throw UnimplementedError();
  }

  @override
  Future<ApiResult<T>> patch<T>(String path,
      {Object? body, Map<String, String>? headers, Duration? timeout, RequestToken? token}) async {
    throw UnimplementedError();
  }

  @override
  Future<ApiResult<T>> delete<T>(String path,
      {Map<String, String>? headers, Duration? timeout, RequestToken? token}) async {
    throw UnimplementedError();
  }

  @override
  ApiResult<T> mapError<T>(Object error, {StackTrace? stackTrace}) =>
      ApiResult.failure(ApiNetworkError(message: error.toString(), cause: error));
}

void main() {
  late _FakeApiClient client;
  late InMemorySecureTokenStorage storage;
  late HttpAuthRepository repository;

  setUp(() {
    client = _FakeApiClient();
    storage = InMemorySecureTokenStorage();
    repository = HttpAuthRepository(apiClient: client, tokenStorage: storage);
  });

  group('HttpAuthRepository.login', () {
    test('stores tokens and returns the user on success', () async {
      client.handler = (_, __, ___) => ApiResult.success(<String, dynamic>{
            'user': {'id': 'u1', 'email': 'a@b.c', 'displayName': 'Nour'},
            'accessToken': 'access-xyz',
            'refreshToken': 'refresh-abc',
          });

      final result = await repository.login(
        const AuthCredentials(email: 'a@b.c', password: 'secret-pass'),
      );

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!.id, 'u1');
      expect(await storage.getAccessToken(), 'access-xyz');
      expect(await storage.getRefreshToken(), 'refresh-abc');

      final call = client.calls.single;
      expect(call.path, '/auth/login');
      expect(call.body, {'email': 'a@b.c', 'password': 'secret-pass'});
    });

    test('maps a 401 failure through without storing tokens', () async {
      client.handler = (_, __, ___) =>
          const ApiResult.failure(ApiUnauthorizedError(message: 'no', statusCode: 401));

      final result = await repository.login(
        const AuthCredentials(email: 'a@b.c', password: 'wrong'),
      );

      expect(result.isFailure, isTrue);
      expect(await storage.getAccessToken(), isNull);
    });

    test('rejects a malformed success payload as a parse error', () async {
      client.handler = (_, __, ___) => ApiResult.success(<String, dynamic>{
            'accessToken': 'access',
            // missing user + refreshToken
          });

      final result = await repository.login(
        const AuthCredentials(email: 'a@b.c', password: 'secret-pass'),
      );

      expect(result.isFailure, isTrue);
      expect(result.errorOrNull, isA<ApiParseError>());
      expect(await storage.getAccessToken(), isNull);
    });
  });

  group('HttpAuthRepository.register', () {
    test('posts to /auth/register and persists the session', () async {
      client.handler = (_, __, ___) => ApiResult.success(<String, dynamic>{
            'user': {'id': 'u2', 'email': 'new@b.c'},
            'accessToken': 'a2',
            'refreshToken': 'r2',
          });

      final result = await repository.register(
        const RegistrationData(email: 'new@b.c', password: 'long-enough', displayName: 'Ali'),
      );

      expect(result.isSuccess, isTrue);
      final call = client.calls.single;
      expect(call.path, '/auth/register');
      expect(
        call.body,
        {'email': 'new@b.c', 'password': 'long-enough', 'displayName': 'Ali'},
      );
      expect(await storage.getAccessToken(), 'a2');
    });
  });

  group('HttpAuthRepository.currentSession', () {
    test('returns guest (null) when no token is stored', () async {
      final result = await repository.currentSession();

      expect(result.valueOrNull, isNull);
      expect(client.calls, isEmpty);
    });

    test('validates the stored token against /auth/me and returns the user',
        () async {
      await storage.saveAccessToken('stored-token');
      client.handler = (path, headers, ___) {
        expect(path, '/auth/me');
        expect(headers!['Authorization'], 'Bearer stored-token');
        return ApiResult.success(<String, dynamic>{
          'user': {'id': 'u1', 'email': 'a@b.c'},
        });
      };

      final result = await repository.currentSession();

      expect(result.valueOrNull!.email, 'a@b.c');
    });

    test('clears tokens and reports guest when /auth/me rejects with 401',
        () async {
      await storage.saveAccessToken('expired-token');
      await storage.saveRefreshToken('stale');
      client.handler = (_, __, ___) =>
          const ApiResult.failure(ApiUnauthorizedError(message: 'expired', statusCode: 401));

      final result = await repository.currentSession();

      expect(result.valueOrNull, isNull);
      expect(await storage.getAccessToken(), isNull);
      expect(await storage.getRefreshToken(), isNull);
    });

    test('keeps tokens on transport failures so a retry can recover', () async {
      await storage.saveAccessToken('still-valid-maybe');
      client.handler = (_, __, ___) =>
          const ApiResult.failure(ApiNetworkError(message: 'offline'));

      final result = await repository.currentSession();

      expect(result.isFailure, isTrue);
      expect(await storage.getAccessToken(), 'still-valid-maybe');
    });
  });

  group('HttpAuthRepository.logout', () {
    test('clears both tokens and succeeds even if storage throws', () async {
      await storage.saveAccessToken('a');
      await storage.saveRefreshToken('r');

      final result = await repository.logout();

      expect(result.isSuccess, isTrue);
      expect(await storage.getAccessToken(), isNull);
      expect(await storage.getRefreshToken(), isNull);
    });
  });
}
