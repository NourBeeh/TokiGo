/// Base type for every failure produced by the [ApiClient].
///
/// This is the network-layer contract. It deliberately carries no HTTP-client
/// dependencies; concrete clients translate their own errors into these types.
sealed class ApiError {
  const ApiError({this.message, this.statusCode, this.cause});

  /// Human-readable (possibly already localised) message.
  final String? message;

  /// HTTP status code when available.
  final int? statusCode;

  /// Original exception/stack details for diagnostics (never surfaced raw to UI).
  final Object? cause;

  @override
  String toString() {
    final code = statusCode == null ? '' : ' ($statusCode)';
    final msg = message == null ? '' : ': $message';
    return '$runtimeType$code$msg';
  }
}

/// The request never reached the server (connectivity / DNS / socket).
class ApiNetworkError extends ApiError {
  const ApiNetworkError({super.message, super.cause});
}

/// The request timed out before a response was received.
class ApiTimeoutError extends ApiError {
  const ApiTimeoutError({super.message, super.cause});
}

/// The server responded with 4xx.
class ApiClientError extends ApiError {
  const ApiClientError({super.message, super.statusCode, super.cause});
}

/// The server responded with 5xx.
class ApiServerError extends ApiError {
  const ApiServerError({super.message, super.statusCode, super.cause});
}

/// The response could not be decoded into the expected shape.
class ApiParseError extends ApiError {
  const ApiParseError({super.message, super.cause});
}

/// Authentication/authorisation failed (401 / 403).
class ApiUnauthorizedError extends ApiError {
  const ApiUnauthorizedError({super.message, super.statusCode, super.cause});
}

/// Any other, unclassified failure.
class ApiUnknownError extends ApiError {
  const ApiUnknownError({super.message, super.cause});
}

/// The request was cancelled by the caller before completion.
class ApiRequestCancelledError extends ApiError {
  const ApiRequestCancelledError({super.message, super.cause});
}
