import 'api_error.dart';

/// Unified outcome of a network call.
///
/// Use [ApiResult.map] / [when] to consume results without switching on types
/// manually. Success is generic over the payload [T]; failure always carries an
/// [ApiError].
sealed class ApiResult<T> {
  const ApiResult();

  /// Convenience constructors.
  const factory ApiResult.success(T value) = _ApiSuccess<T>;
  const factory ApiResult.failure(ApiError error) = _ApiFailure<T>;

  bool get isSuccess => switch (this) {
    _ApiSuccess<T>() => true,
    _ApiFailure<T>() => false,
  };

  bool get isFailure => !isSuccess;

  /// Resolves either branch, safely unwrapping the payload or error.
  R when<R>({
    required R Function(T value) success,
    required R Function(ApiError error) failure,
  }) => switch (this) {
    _ApiSuccess<T>(:final value) => success(value),
    _ApiFailure<T>(:final error) => failure(error),
  };

  /// The success payload or `null` if this is a failure.
  T? get valueOrNull => switch (this) {
    _ApiSuccess<T>(:final value) => value,
    _ApiFailure<T>() => null,
  };

  /// The error or `null` if this is a success.
  ApiError? get errorOrNull => switch (this) {
    _ApiSuccess<T>() => null,
    _ApiFailure<T>(:final error) => error,
  };
}

class _ApiSuccess<T> extends ApiResult<T> {
  const _ApiSuccess(this.value);
  final T value;

  @override
  String toString() => 'ApiResult.success($value)';
}

class _ApiFailure<T> extends ApiResult<T> {
  const _ApiFailure(this.error);
  final ApiError error;

  @override
  String toString() => 'ApiResult.failure($error)';
}
