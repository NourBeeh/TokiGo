import 'api_error.dart';
import 'api_result.dart';

/// Common envelope for every server response.
///
/// `data` holds the decoded payload; `meta` can carry pagination, timestamps or
/// other non-domain metadata. This convention keeps a consistent contract for
/// all future endpoints.
class ApiResponse<T> {
  const ApiResponse({required this.data, this.meta});

  final T data;
  final Map<String, dynamic>? meta;
}

/// A generic network client contract.
///
/// Phase 1 defines the abstraction only — no concrete HTTP client or Provider
/// is wired yet. Implementations translate platform errors into [ApiError] and
/// always return an [ApiResult].
/// Token used to allow callers to cancel an in-flight request.
///
/// Usage: create a token before issuing a request, pass it down to the
/// ApiClient.post/get/... implementation and call [cancel] when the caller
/// wants to discard the result and optionally abort handling.
class RequestToken {
  bool _cancelled = false;
  void Function()? _abortHandler;

  /// Attach a per-request abort handler. Implementations call this to register
  /// a function that will be invoked when [cancel] is called.
  void attachAbortHandler(void Function()? handler) {
    _abortHandler = handler;
    // If the token was already cancelled, invoke the handler immediately so
    // implementations can react (e.g. abort an in-flight request).
    if (_cancelled) {
      try {
        _abortHandler?.call();
      } catch (_) {}
    }
  }

  /// Cancel the token and invoke any attached abort handler.
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    try {
      _abortHandler?.call();
    } catch (_) {}
  }

  bool get isCancelled => _cancelled;
}

abstract interface class ApiClient {
  /// Base URL all relative paths are resolved against.
  String get baseUrl;

  /// Default timeout applied when [timeout] is not supplied.
  Duration get defaultTimeout;

  /// Headers merged into every request (e.g. auth or content-type).
  Map<String, String> get defaultHeaders;

  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    Duration? timeout,
    RequestToken? token,
  });

  Future<ApiResult<T>> post<T>(
    String path, {
    Object? body,
    Map<String, String>? headers,
    Duration? timeout,
    RequestToken? token,
  });

  Future<ApiResult<T>> put<T>(
    String path, {
    Object? body,
    Map<String, String>? headers,
    Duration? timeout,
    RequestToken? token,
  });

  Future<ApiResult<T>> patch<T>(
    String path, {
    Object? body,
    Map<String, String>? headers,
    Duration? timeout,
    RequestToken? token,
  });

  Future<ApiResult<T>> delete<T>(
    String path, {
    Map<String, String>? headers,
    Duration? timeout,
    RequestToken? token,
  });

  /// Translates an arbitrary thrown error into the closest [ApiError].
  ApiResult<T> mapError<T>(Object error, {StackTrace? stackTrace});
}
