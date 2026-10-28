import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'api_client.dart';
import 'api_error.dart';
import 'api_result.dart';
import 'network_status.dart';

/// Lightweight wrapper that allows aborting a single in-flight request.
///
/// It holds the request object plus the subscription used to read the
/// response body. Calling [abort] cancels the subscription, attempts to
/// detach+destroy the underlying socket (when available) and completes
/// an internal abort future used to unblock any readers.
class CancelableRequest {
  final HttpClientRequest request;
  HttpClientResponse? response;
  StreamSubscription<String>? subscription;
  final void Function()? onAbort;
  final Completer<void> _abortCompleter = Completer<void>();
  bool _aborted = false;

  CancelableRequest(this.request, {this.onAbort});

  bool get isAborted => _aborted;
  Future<void> get abortFuture => _abortCompleter.future;

  void setResponse(HttpClientResponse resp) => response = resp;

  void setSubscription(StreamSubscription<String> sub) => subscription = sub;

  void abort() {
    if (_aborted) return;
    _aborted = true;
    try {
      subscription?.cancel();
    } catch (_) {}
    try {
      final detached = response?.detachSocket();
      if (detached != null) {
        // detachSocket may return a Future<Socket> in some SDK versions. Try
        // to treat it as a Future first; if that fails, attempt a direct
        // destroy on the resulting object.
        try {
          (detached as dynamic)
              .then((s) {
                try {
                  s.destroy();
                } catch (_) {}
              })
              .catchError((_) {});
        } catch (_) {
          try {
            (detached as dynamic).destroy();
          } catch (_) {}
        }
      }
    } catch (_) {}
    try {
      onAbort?.call();
    } catch (_) {}
    if (!_abortCompleter.isCompleted) _abortCompleter.complete();
  }
}

class HttpApiClient implements ApiClient {
  /// Compile-time override (e.g. `--dart-define=API_BASE_URL=http://x:3000`).
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
  );

  final HttpClient _client;

  /// An explicit base URL, for tests and tools. Null (the default) uses
  /// [_configuredBaseUrl] or the local backend.
  final String? baseUrlOverride;
  final void Function()? _onAbortCallback;

  /// Optional test hooks (inject a custom [HttpClient], override [baseUrl]
  /// and receive an [onAbort] callback). These are intentionally optional so
  /// production callers can continue to use the default no-arg constructor.
  HttpApiClient({
    HttpClient? client,
    this.baseUrlOverride,
    void Function()? onAbort,
  }) : _client = client ?? HttpClient(),
       _onAbortCallback = onAbort;

  /// The port the backend listens on (see `backend/src/main.ts`).
  static const int _devPort = 3000;

  @override
  String get baseUrl {
    final String? override = baseUrlOverride;
    String resolved;
    if (override != null) {
      resolved = override;
    } else if (_configuredBaseUrl.isNotEmpty) {
      resolved = _configuredBaseUrl;
    } else {
      resolved = 'http://localhost:$_devPort';
    }
    // Release builds must never send tokens/data over plaintext HTTP.
    assert(
      !kReleaseMode || resolved.startsWith('https://'),
      'HTTPS is required for API_BASE_URL in release builds.',
    );
    if (kReleaseMode && resolved.startsWith('http://')) {
      throw StateError('HTTPS is required for API_BASE_URL in release builds.');
    }
    return resolved;
  }

  @override
  Duration get defaultTimeout => const Duration(seconds: 30);

  @override
  Map<String, String> get defaultHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    Duration? timeout,
    RequestToken? token,
  }) async {
    return _request<T>(
      'GET',
      path,
      queryParameters: queryParameters,
      headers: headers,
      timeout: timeout,
      token: token,
    );
  }

  @override
  Future<ApiResult<T>> post<T>(
    String path, {
    Object? body,
    Map<String, String>? headers,
    Duration? timeout,
    RequestToken? token,
  }) async {
    return _request<T>(
      'POST',
      path,
      body: body,
      headers: headers,
      timeout: timeout,
      token: token,
    );
  }

  @override
  Future<ApiResult<T>> put<T>(
    String path, {
    Object? body,
    Map<String, String>? headers,
    Duration? timeout,
    RequestToken? token,
  }) async {
    return _request<T>(
      'PUT',
      path,
      body: body,
      headers: headers,
      timeout: timeout,
      token: token,
    );
  }

  @override
  Future<ApiResult<T>> patch<T>(
    String path, {
    Object? body,
    Map<String, String>? headers,
    Duration? timeout,
    RequestToken? token,
  }) async {
    return _request<T>(
      'PATCH',
      path,
      body: body,
      headers: headers,
      timeout: timeout,
      token: token,
    );
  }

  @override
  Future<ApiResult<T>> delete<T>(
    String path, {
    Map<String, String>? headers,
    Duration? timeout,
    RequestToken? token,
  }) async {
    return _request<T>(
      'DELETE',
      path,
      headers: headers,
      timeout: timeout,
      token: token,
    );
  }

  @override
  ApiResult<T> mapError<T>(Object error, {StackTrace? stackTrace}) {
    // A transport failure means the backend could not be reached — the app
    // shows that, and serves the last saved data instead.
    NetworkStatus.instance.reportOffline();
    return ApiResult.failure(
      ApiNetworkError(message: error.toString(), cause: error),
    );
  }

  Future<ApiResult<T>> _request<T>(
    String method,
    String path, {
    Map<String, String>? queryParameters,
    Object? body,
    Map<String, String>? headers,
    Duration? timeout,
    RequestToken? token,
  }) async {
    try {
      if (token?.isCancelled == true) {
        return ApiResult.failure(
          const ApiRequestCancelledError(
            message: 'Request cancelled by caller',
          ),
        );
      }

      final uri = Uri.parse(baseUrl).resolve(path);
      final finalUri = queryParameters != null
          ? uri.replace(
              queryParameters: {...uri.queryParameters, ...queryParameters},
            )
          : uri;

      final request = await _client.openUrl(method, finalUri);

      // Wrap the raw request so it can be aborted if needed.
      final cancelable = CancelableRequest(request, onAbort: _onAbortCallback);
      token?.attachAbortHandler(cancelable.abort);

      final mergedHeaders = {...defaultHeaders, ...?headers};
      mergedHeaders.forEach((k, v) => request.headers.set(k, v));

      if (body != null) {
        final encoded = jsonEncode(body);
        request.add(utf8.encode(encoded));
      }

      late HttpClientResponse response;
      try {
        response = await request.close().timeout(timeout ?? defaultTimeout);
      } on TimeoutException catch (e) {
        return ApiResult.failure(
          ApiTimeoutError(message: 'Request timed out', cause: e),
        );
      }

      // Record the response so abort can detach the socket if requested.
      cancelable.setResponse(response);

      if (token?.isCancelled == true || cancelable.isAborted) {
        // If cancellation was requested while waiting for headers, honor it.
        return ApiResult.failure(
          const ApiRequestCancelledError(
            message: 'Request cancelled by caller',
          ),
        );
      }

      // Read the body using a subscription so it can be cancelled mid-stream.
      final buffer = StringBuffer();
      final bodyCompleter = Completer<String>();
      final sub = response
          .transform(utf8.decoder)
          .listen(
            (chunk) => buffer.write(chunk),
            onError: (e, st) => bodyCompleter.completeError(e, st),
            onDone: () => bodyCompleter.complete(buffer.toString()),
            cancelOnError: true,
          );
      cancelable.setSubscription(sub);

      // Wait for either the body to be read or an abort to occur.
      await Future.any([bodyCompleter.future, cancelable.abortFuture]);

      if (token?.isCancelled == true || cancelable.isAborted) {
        // Ensure the subscription is cancelled and return a cancelled error.
        try {
          await sub.cancel();
        } catch (_) {}
        return ApiResult.failure(
          const ApiRequestCancelledError(
            message: 'Request cancelled by caller',
          ),
        );
      }

      final responseBody = await bodyCompleter.future;

      if (token?.isCancelled == true) {
        return ApiResult.failure(
          const ApiRequestCancelledError(
            message: 'Request cancelled by caller',
          ),
        );
      }

      // Any completed HTTP response confirms the backend is reachable,
      // including successful responses and authorization/client errors.
      NetworkStatus.instance.reportOnline();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        dynamic data;
        try {
          data = jsonDecode(responseBody);
        } catch (_) {
          return ApiResult.failure(
            ApiParseError(
              message: 'Invalid JSON response',
              cause: responseBody,
            ),
          );
        }
        if (token?.isCancelled == true) {
          return ApiResult.failure(
            const ApiRequestCancelledError(
              message: 'Request cancelled by caller',
            ),
          );
        }
        return ApiResult.success(data as T);
      } else {
        final code = response.statusCode;
        if (code == 401 || code == 403) {
          return ApiResult.failure(
            ApiUnauthorizedError(message: responseBody, statusCode: code),
          );
        }
        if (code == 429) {
          return ApiResult.failure(
            ApiServerError(message: responseBody, statusCode: code),
          );
        }
        if (code >= 500) {
          return ApiResult.failure(
            ApiServerError(message: responseBody, statusCode: code),
          );
        }
        return ApiResult.failure(
          ApiClientError(message: responseBody, statusCode: code),
        );
      }
    } catch (e, st) {
      if (e is SocketException || e is HttpException) {
        NetworkStatus.instance.reportOffline();
        return ApiResult.failure(
          ApiNetworkError(message: e.toString(), cause: e),
        );
      }
      return mapError(e, stackTrace: st);
    }
  }
}
