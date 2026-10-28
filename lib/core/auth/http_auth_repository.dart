import '../network/api_client.dart';
import '../network/api_error.dart';
import '../network/api_result.dart';
import '../storage/secure_token_storage.dart';
import 'auth_repository.dart';
import 'user_model.dart';

/// Real HTTP [AuthRepository] backed by the NestJS auth endpoints.
///
/// - login/register → `POST /auth/login|register`, persists the returned
///   access/refresh tokens via [SecureTokenStorage].
/// - currentSession → restores the stored access token and validates it with
///   `GET /auth/me`; a missing/expired token resolves to `null` (guest).
/// - logout → clears tokens locally (client-side revocation only in this
///   phase; server-side session invalidation is deferred).
class HttpAuthRepository implements AuthRepository {
  HttpAuthRepository({required this._apiClient, required this._tokenStorage});

  final ApiClient _apiClient;
  final SecureTokenStorage _tokenStorage;

  static const String _loginPath = '/auth/login';
  static const String _registerPath = '/auth/register';
  static const String _mePath = '/auth/me';

  @override
  Future<ApiResult<AuthUser>> login(AuthCredentials credentials) async {
    return _authenticate(_loginPath, <String, dynamic>{
      'email': credentials.email,
      'password': credentials.password,
    });
  }

  @override
  Future<ApiResult<AuthUser>> register(RegistrationData data) async {
    return _authenticate(_registerPath, <String, dynamic>{
      'email': data.email,
      'password': data.password,
      if (data.displayName != null && data.displayName!.trim().isNotEmpty)
        'displayName': data.displayName,
    });
  }

  @override
  Future<ApiResult<void>> logout() async {
    try {
      await _tokenStorage.clearAll();
      return const ApiResult.success(null);
    } catch (_) {
      // Clearing must never fail the logout flow; state is reset regardless.
      return const ApiResult.success(null);
    }
  }

  @override
  Future<ApiResult<AuthUser?>> currentSession() async {
    final token = await _safeReadAccessToken();
    if (token == null || token.isEmpty) {
      return const ApiResult.success(null);
    }

    final result = await _apiClient.get<Map<String, dynamic>>(
      _mePath,
      headers: <String, String>{'Authorization': 'Bearer $token'},
    );

    return result.when(
      success: (data) {
        final user = _userFromMePayload(data);
        if (user == null) {
          return const ApiResult.success(null);
        }
        return ApiResult.success(user);
      },
      failure: (error) {
        // An expired/invalid token means "not signed in", not an app error.
        if (error is ApiUnauthorizedError) {
          _clearTokensBestEffort();
          return const ApiResult.success(null);
        }
        // Network/transport failures keep tokens; caller decides fallback.
        return ApiResult.failure(error);
      },
    );
  }

  Future<ApiResult<AuthUser>> _authenticate(
    String path,
    Map<String, dynamic> body,
  ) async {
    final result = await _apiClient.post<Map<String, dynamic>>(
      path,
      body: body,
    );

    return result.when(
      success: (data) async {
        final accessToken = data['accessToken']?.toString();
        final refreshToken = data['refreshToken']?.toString();
        final userMap = data['user'];
        final AuthUser? user;
        if (userMap is Map) {
          user = AuthUser.fromJson(
            Map<String, dynamic>.from(
              userMap.map((k, v) => MapEntry(k.toString(), v)),
            ),
          );
        } else {
          user = null;
        }

        if (accessToken == null ||
            accessToken.isEmpty ||
            user == null ||
            user.id.isEmpty) {
          return const ApiResult.failure(
            ApiParseError(message: 'Malformed auth response'),
          );
        }

        try {
          await _tokenStorage.saveAccessToken(accessToken);
          if (refreshToken != null && refreshToken.isNotEmpty) {
            await _tokenStorage.saveRefreshToken(refreshToken);
          }
        } catch (_) {
          // Storage failures surface as an error rather than silent data loss.
          return const ApiResult.failure(
            ApiUnknownError(message: 'Could not persist the session.'),
          );
        }

        return ApiResult.success(user);
      },
      failure: (error) => ApiResult.failure(error),
    );
  }

  AuthUser? _userFromMePayload(Map<String, dynamic> data) {
    final raw = data['user'];
    if (raw is! Map) return null;
    final user = AuthUser.fromJson(
      Map<String, dynamic>.from(raw.map((k, v) => MapEntry(k.toString(), v))),
    );
    return user.id.isEmpty ? null : user;
  }

  Future<String?> _safeReadAccessToken() async {
    try {
      return await _tokenStorage.getAccessToken();
    } catch (_) {
      return null;
    }
  }

  void _clearTokensBestEffort() {
    _tokenStorage.clearAll().catchError((_) {});
  }
}
