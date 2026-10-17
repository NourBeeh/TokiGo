import 'package:flutter_test/flutter_test.dart';
import 'package:tokigo/core/network/api_error.dart';
import 'package:tokigo/core/network/api_result.dart';

void main() {
  test('ApiResult.success holds the value and isSuccess is true', () {
    final result = ApiResult.success(42);
    expect(result.isSuccess, isTrue);
    expect(result.valueOrNull, 42);
    expect(result.errorOrNull, isNull);
  });

  test('ApiResult.failure holds the error and isFailure is true', () {
    final result = ApiResult<int>.failure(const ApiNetworkError(message: 'boom'));
    expect(result.isFailure, isTrue);
    expect(result.valueOrNull, isNull);
    expect(result.errorOrNull, isA<ApiNetworkError>());
  });

  test('when dispatches to the correct branch', () {
    final success = ApiResult.success('ok');
    final failure = ApiResult<String>.failure(const ApiTimeoutError());

    expect(success.when(success: (v) => v, failure: (_) => 'err'), 'ok');
    expect(failure.when(success: (v) => v, failure: (e) => e.message), isNull);
  });
}