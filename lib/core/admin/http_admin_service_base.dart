import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/core/network/api_error.dart';
import 'package:tokigo/core/storage/secure_token_storage.dart';

/// Shared plumbing for admin HTTP services: bearer-token headers and
/// failure-to-exception translation so the UI can surface a SnackBar.
mixin AdminHttpMixin {
  SecureTokenStorage get tokenStorage;

  Future<Map<String, String>> authHeaders() async {
    try {
      final token = await tokenStorage.getAccessToken();
      if (token == null || token.isEmpty) return const <String, String>{};
      return <String, String>{'Authorization': 'Bearer $token'};
    } catch (_) {
      return const <String, String>{};
    }
  }

  /// Throws a readable exception on failure — admin mutations surface a
  /// toast, unlike the read paths which use ApiResult fallbacks.
  Never throwOnFailure<T>(ApiResult<T> result) {
    final failure = result.when(
      success: (_) => null,
      failure: (error) => error,
    );
    if (failure == null) {
      throw StateError('throwOnFailure called with a successful result');
    }
    throw AdminApiException(describeApiError(failure));
  }
}

/// Human-readable rendering of any [ApiError] without importing UI layers.
String describeApiError(ApiError error) {
  if (error is ApiUnauthorizedError) {
    return 'Unauthorized — admin sign-in required.';
  }
  if (error.statusCode == 403) return 'Admin access required.';
  if (error is ApiServerError) return 'Server error (${error.statusCode ?? 500}).';
  final message = error.message;
  if (message != null && message.isNotEmpty) return message;
  return 'Request failed.';
}

class AdminApiException implements Exception {
  AdminApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
