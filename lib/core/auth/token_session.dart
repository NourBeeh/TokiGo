import '../network/api_client.dart';
import '../network/api_result.dart';
import '../storage/secure_token_storage.dart';

/// Why a refresh attempt failed.
///
/// The distinction matters to the caller: a transport failure keeps the
/// stored tokens so a later request can retry, while a rejected or malformed
/// response means the session is dead and must be cleared.
enum TokenRefreshFailure {
  /// No refresh token was stored (or the store could not be read).
  noRefreshToken,

  /// The request never reached the server (connectivity / DNS / socket).
  /// Stored tokens are preserved on purpose.
  transport,

  /// The server answered with an authentication failure (401/403).
  rejected,

  /// The server answered but the body was not a usable access+refresh pair.
  malformed,

  /// The rotated pair could not be persisted.
  storage,
}

/// Result of one refresh attempt.
///
/// [accessToken] is non-null exactly when [failure] is null. The type exists
/// so a caller can tell "the network dropped, try again later" apart from
/// "the session is dead, sign in again" instead of collapsing both into
/// `null`.
class TokenRefreshOutcome {
  const TokenRefreshOutcome.success(this.accessToken) : failure = null;
  const TokenRefreshOutcome.failed(this.failure) : accessToken = null;

  /// The NEW access token on success; `null` on failure.
  final String? accessToken;

  /// The failure reason; `null` on success.
  final TokenRefreshFailure? failure;

  bool get isSuccess => failure == null;
}

/// Read access to the current session, plus renewal of an expired access token.
///
/// This is a thin helper, NOT a second authentication mechanism:
///
///  * tokens are read from and written to the app's ONE [SecureTokenStorage] —
///    the same store `HttpAuthRepository`, `BookingRepositoryImpl`,
///    `ProfileRepository` and the admin services already use;
///  * renewal calls the backend's existing `POST /auth/refresh` endpoint and
///    persists the rotated pair back into that same store.
///
/// It exists so a non-repository caller (offer revalidation) can attach a
/// Bearer header and survive an expired access token without duplicating token
/// storage or inventing a parallel auth flow.
///
/// Concurrency: concurrent callers share ONE in-flight refresh. The first
/// caller starts the request; every other caller awaits the same future, so a
/// burst of 401s produces exactly one `/auth/refresh` call. Once it settles
/// the slot is released and a later, independent request may refresh again.
///
/// Tokens are never logged: they are returned only so the caller can place
/// them in an `Authorization` header.
class TokenSession {
  TokenSession({
    required ApiClient apiClient,
    required SecureTokenStorage storage,
  }) : this._(apiClient, storage);

  TokenSession._(this._apiClient, this._storage);

  final ApiClient _apiClient;
  final SecureTokenStorage _storage;

  static const String _refreshPath = '/auth/refresh';

  /// The single refresh attempt currently running, if any. Concurrent callers
  /// await this instead of starting their own request.
  Future<TokenRefreshOutcome>? _inFlight;

  /// `Authorization` header for the current session, or `null` when signed out.
  Future<Map<String, String>?> authHeaders() async {
    final token = await _accessToken();
    if (token == null || token.isEmpty) return null;
    return <String, String>{'Authorization': 'Bearer $token'};
  }

  /// Whether an access token is currently stored.
  Future<bool> hasSession() async {
    final token = await _accessToken();
    return token != null && token.isNotEmpty;
  }

  /// Renews an expired access token through `POST /auth/refresh`.
  ///
  /// Concurrent calls share one underlying request. The outcome distinguishes
  /// a transport failure (tokens preserved, a later call may retry) from a
  /// rejected or malformed response (the session is dead and the store is
  /// cleared) — see [TokenRefreshFailure].
  Future<TokenRefreshOutcome> refresh() {
    final Future<TokenRefreshOutcome>? pending = _inFlight;
    if (pending != null) return pending;

    final Future<TokenRefreshOutcome> future = _refresh();
    _inFlight = future;
    // Release the slot when this attempt settles so a later, independent
    // request can start a fresh one. `identical` guards against clearing a
    // newer attempt (defensive: only one is ever stored).
    future.whenComplete(() {
      if (identical(_inFlight, future)) _inFlight = null;
    });
    return future;
  }

  Future<TokenRefreshOutcome> _refresh() async {
    String? refreshToken;
    try {
      refreshToken = await _storage.getRefreshToken();
    } catch (_) {
      return const TokenRefreshOutcome.failed(
        TokenRefreshFailure.noRefreshToken,
      );
    }
    if (refreshToken == null || refreshToken.isEmpty) {
      await _clear();
      return const TokenRefreshOutcome.failed(
        TokenRefreshFailure.noRefreshToken,
      );
    }

    final ApiResult<Map<String, dynamic>> result;
    try {
      result = await _apiClient.post<Map<String, dynamic>>(
        _refreshPath,
        body: <String, dynamic>{'refreshToken': refreshToken},
      );
    } catch (_) {
      // Transport failure: keep the stored tokens so a later call can retry.
      return const TokenRefreshOutcome.failed(TokenRefreshFailure.transport);
    }

    if (result.isFailure) {
      await _clear();
      return const TokenRefreshOutcome.failed(TokenRefreshFailure.rejected);
    }

    final data = result.valueOrNull;
    final access = data?['accessToken']?.toString();
    final rotated = data?['refreshToken']?.toString();
    // The backend rotates BOTH tokens. A response without the new refresh
    // token would leave the app on a dead refresh token, so it is treated as
    // malformed and the invalid session is cleared.
    if (access == null ||
        access.isEmpty ||
        rotated == null ||
        rotated.isEmpty) {
      await _clear();
      return const TokenRefreshOutcome.failed(TokenRefreshFailure.malformed);
    }

    // Persist the rotated pair. The store has no transaction, so if either
    // write fails the PREVIOUS pair is restored — a valid session is never
    // replaced by a half-updated one. If the restore also fails the session
    // is cleared rather than left inconsistent.
    final String? previousAccess = await _accessToken();
    try {
      await _storage.saveAccessToken(access);
      await _storage.saveRefreshToken(rotated);
    } catch (_) {
      try {
        if (previousAccess == null || previousAccess.isEmpty) {
          await _storage.deleteAccessToken();
        } else {
          await _storage.saveAccessToken(previousAccess);
        }
        await _storage.saveRefreshToken(refreshToken);
      } catch (_) {
        await _clear();
      }
      return const TokenRefreshOutcome.failed(TokenRefreshFailure.storage);
    }
    return TokenRefreshOutcome.success(access);
  }

  Future<String?> _accessToken() async {
    try {
      return await _storage.getAccessToken();
    } catch (_) {
      return null;
    }
  }

  Future<void> _clear() async {
    try {
      await _storage.clearAll();
    } catch (_) {
      // Best effort: a token the backend rejects cannot be used again.
    }
  }
}
