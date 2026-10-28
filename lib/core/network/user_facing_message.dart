import 'api_error.dart';

/// Maps a failure to a message that is safe to display to the user.
///
/// The network layer carries raw transport and backend text in
/// [ApiError.message] — `ApiResult`/`HttpApiClient` store the whole HTTP
/// response body there and socket failures carry host/port — so publishing
/// `error.toString()` would put API response details, provider/internal
/// errors, network topology and secrets on screen. Instead every [ApiError]
/// subtype maps to a fixed, safe phrase and anything else falls back to a
/// generic message.
///
/// This is the same boundary used by `AiController`. Reuses the existing
/// [ApiError] hierarchy — no new error type is introduced. The switch is
/// exhaustive over the sealed class, so adding a new [ApiError] subtype fails
/// the build instead of silently leaking again.
String userFacingMessage(Object error, {String subject = 'request'}) {
  if (error is ApiError) {
    return switch (error) {
      ApiTimeoutError() => 'The $subject took too long. Please try again.',
      ApiNetworkError() => 'No connection. Check your internet and try again.',
      ApiUnauthorizedError() =>
        'Your session has expired. Please sign in and try again.',
      ApiParseError() =>
        'The $subject returned an unexpected reply. Please try again.',
      ApiServerError() =>
        'The service is temporarily unavailable. Please try again shortly.',
      ApiClientError() =>
        'That request could not be handled. Please try again.',
      ApiRequestCancelledError() => 'Request cancelled.',
      ApiUnknownError() => _genericMessage,
    };
  }
  return _genericMessage;
}

const String _genericMessage = 'Something went wrong. Please try again.';
