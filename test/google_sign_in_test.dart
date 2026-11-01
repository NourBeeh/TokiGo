import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/auth/auth_controller.dart';
import 'package:tokigo/core/auth/auth_failure_message.dart';
import 'package:tokigo/core/auth/auth_provider.dart';
import 'package:tokigo/core/auth/auth_repository.dart';
import 'package:tokigo/core/auth/auth_state.dart';
import 'package:tokigo/core/auth/google_auth_config.dart';
import 'package:tokigo/core/auth/google_sign_in_service.dart';
import 'package:tokigo/core/auth/http_auth_repository.dart';
import 'package:tokigo/core/auth/user_model.dart';
import 'package:tokigo/core/network/api_client.dart';
import 'package:tokigo/core/network/api_error.dart';
import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/core/storage/secure_token_storage.dart';
import 'package:tokigo/features/profile/presentation/pages/auth_page.dart';

/// Google sign-in is a three-step chain: platform SDK → `/auth/google` → our
/// own session. These tests pin each link with fakes, because the real platform
/// flow only exists on a device.

class _FakeApiClient implements ApiClient {
  _FakeApiClient(this.onPost);

  final Future<ApiResult<Map<String, dynamic>>> Function(
    String path,
    Object? body,
  )
  onPost;

  final List<({String path, Object? body})> posts = [];

  @override
  String get baseUrl => 'http://test.invalid';

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
    posts.add((path: path, body: body));
    return await onPost(path, body) as ApiResult<T>;
  }

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    Duration? timeout,
    RequestToken? token,
  }) async => throw UnimplementedError();

  @override
  Future<ApiResult<T>> put<T>(
    String path, {
    Object? body,
    Map<String, String>? headers,
    Duration? timeout,
    RequestToken? token,
  }) async => throw UnimplementedError();

  @override
  Future<ApiResult<T>> patch<T>(
    String path, {
    Object? body,
    Map<String, String>? headers,
    Duration? timeout,
    RequestToken? token,
  }) async => throw UnimplementedError();

  @override
  Future<ApiResult<T>> delete<T>(
    String path, {
    Map<String, String>? headers,
    Duration? timeout,
    RequestToken? token,
  }) async => throw UnimplementedError();

  @override
  ApiResult<T> mapError<T>(Object error, {StackTrace? stackTrace}) =>
      ApiResult<T>.failure(
        ApiUnknownError(message: error.toString(), cause: error),
      );
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.onGoogle});

  Future<ApiResult<AuthUser>> Function(String idToken)? onGoogle;
  int googleCalls = 0;

  @override
  Future<ApiResult<AuthUser>> signInWithGoogle(String idToken) async {
    googleCalls++;
    final handler = onGoogle;
    if (handler != null) return handler(idToken);
    return ApiResult<AuthUser>.success(
      const AuthUser(id: 'user-1', email: 'traveler@example.com'),
    );
  }

  @override
  Future<ApiResult<AuthUser?>> currentSession() async =>
      const ApiResult<AuthUser?>.success(null);

  @override
  Future<ApiResult<AuthUser>> login(AuthCredentials credentials) async =>
      throw UnimplementedError();

  @override
  Future<ApiResult<AuthUser>> register(RegistrationData data) async =>
      throw UnimplementedError();

  @override
  Future<ApiResult<AuthUser>> updateProfile(AuthUser user) async =>
      ApiResult<AuthUser>.success(user);

  @override
  Future<ApiResult<void>> logout() async =>
      const ApiResult<void>.success(null);
}

class _FakeGoogleSignInService implements GoogleSignInService {
  _FakeGoogleSignInService({this.token, this.error});

  final String? token;
  final GoogleSignInUnavailableException? error;
  int calls = 0;

  @override
  Future<String?> idToken() async {
    calls++;
    final failure = error;
    if (failure != null) throw failure;
    return token;
  }
}

const String _fakeIdToken = 'header.payload.signature';

void main() {
  group('HttpAuthRepository.signInWithGoogle', () {
    test('posts only the ID token and stores the returned session', () async {
      final storage = InMemorySecureTokenStorage();
      final client = _FakeApiClient(
        (path, body) async => ApiResult<Map<String, dynamic>>.success({
          'user': {
            'id': 'user-7',
            'email': 'traveler@example.com',
            'displayName': 'Nour',
            'role': 'user',
          },
          'accessToken': 'access-1',
          'refreshToken': 'refresh-1',
        }),
      );
      final repository = HttpAuthRepository(
        apiClient: client,
        tokenStorage: storage,
      );

      final result = await repository.signInWithGoogle(_fakeIdToken);

      expect(client.posts.single.path, '/auth/google');
      expect(client.posts.single.body, {'idToken': _fakeIdToken});
      // The client asserts no identity of its own.
      expect(
        (client.posts.single.body! as Map<String, dynamic>).keys,
        ['idToken'],
      );
      expect(result.valueOrNull?.id, 'user-7');
      expect(await storage.getAccessToken(), 'access-1');
      expect(await storage.getRefreshToken(), 'refresh-1');
    });

    test('surfaces a malformed response as a parse failure', () async {
      final repository = HttpAuthRepository(
        apiClient: _FakeApiClient(
          (path, body) async =>
              const ApiResult<Map<String, dynamic>>.success({'user': null}),
        ),
        tokenStorage: InMemorySecureTokenStorage(),
      );

      final result = await repository.signInWithGoogle(_fakeIdToken);

      expect(result.errorOrNull, isA<ApiParseError>());
    });

    test('passes a rejected credential through as a failure', () async {
      final repository = HttpAuthRepository(
        apiClient: _FakeApiClient(
          (path, body) async => const ApiResult<Map<String, dynamic>>.failure(
            ApiUnauthorizedError(message: 'Invalid Google credential.'),
          ),
        ),
        tokenStorage: InMemorySecureTokenStorage(),
      );

      final result = await repository.signInWithGoogle('forged');

      expect(result.errorOrNull, isA<ApiUnauthorizedError>());
    });
  });

  group('AuthController.signInWithGoogle', () {
    test('exchanges the token for a session', () async {
      final repository = _FakeAuthRepository();
      final controller = AuthController(
        repository,
        googleSignInService: _FakeGoogleSignInService(token: _fakeIdToken),
      );
      await pumpEventQueue();

      await controller.signInWithGoogle();

      final state = controller.state;
      expect(state, isA<AuthAuthenticated>());
      expect((state as AuthAuthenticated).user?.email, 'traveler@example.com');
      expect(repository.googleCalls, 1);
    });

    test('a dismissed picker is not an error', () async {
      final repository = _FakeAuthRepository();
      final controller = AuthController(
        repository,
        googleSignInService: _FakeGoogleSignInService(),
      );
      await pumpEventQueue();

      await controller.signInWithGoogle();

      expect(controller.state, isA<AuthUnauthenticated>());
      expect(repository.googleCalls, 0);
    });

    test('a platform failure becomes an auth error without calling the API',
        () async {
      final repository = _FakeAuthRepository();
      final controller = AuthController(
        repository,
        googleSignInService: _FakeGoogleSignInService(
          error: const GoogleSignInUnavailableException(
            GoogleSignInFailure.missingConfiguration,
          ),
        ),
      );
      await pumpEventQueue();

      await controller.signInWithGoogle();

      final state = controller.state;
      expect(state, isA<AuthError>());
      expect((state as AuthError).error, isA<ApiUnknownError>());
      expect(repository.googleCalls, 0);
    });

    test('a rejected backend response keeps the previous session', () async {
      final repository = _FakeAuthRepository(
        onGoogle: (token) async => const ApiResult<AuthUser>.failure(
          ApiClientError(
            message: 'body',
            statusCode: 409,
          ),
        ),
      );
      final controller = AuthController(
        repository,
        googleSignInService: _FakeGoogleSignInService(token: _fakeIdToken),
      );
      await pumpEventQueue();

      await controller.signInWithGoogle();

      final state = controller.state;
      expect(state, isA<AuthError>());
      expect(((state as AuthError).error as ApiError).statusCode, 409);
    });
  });

  group('authFailureMessage', () {
    test('a wrong password is not reported as an expired session', () {
      expect(
        authFailureMessage(
          const ApiUnauthorizedError(message: 'Invalid email or password.'),
        ),
        'Incorrect email or password.',
      );
    });

    test('refines the two misleading Google cases', () {
      expect(
        authFailureMessage(
          const ApiUnauthorizedError(message: 'Invalid Google credential.'),
          action: AuthAction.google,
        ),
        contains('Google'),
      );
      expect(
        authFailureMessage(
          const ApiClientError(message: 'body', statusCode: 409),
          action: AuthAction.google,
        ),
        contains('password'),
      );
      expect(
        authFailureMessage(
          const ApiUnknownError(message: 'platform detail'),
          action: AuthAction.google,
        ),
        contains('Google sign-in is unavailable'),
      );
    });

    test('never prints backend or transport text', () {
      const leaked = ApiServerError(
        message: '{"message":"internal provider stack trace"}',
        statusCode: 500,
      );

      final message = authFailureMessage(leaked, action: AuthAction.google);

      expect(message, isNot(contains('stack trace')));
      expect(message, 'The service is temporarily unavailable. Please try again shortly.');
    });
  });

  testWidgets('the Google control is shown when a client ID is built in', (
    tester,
  ) async {
    // The web client ID is baked in for device runs, so the control renders.
    expect(GoogleAuthConfig.isConfigured, isTrue);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          googleSignInServiceProvider.overrideWithValue(
            _FakeGoogleSignInService(token: _fakeIdToken),
          ),
        ],
        child: const MaterialApp(home: AuthPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Continue with Google'), findsOneWidget);
  });
}
