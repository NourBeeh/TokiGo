import 'package:flutter_test/flutter_test.dart';
import 'package:tokigo/core/providers/contracts/provider_result.dart';

void main() {
  test('ProviderResult success', () {
    const result = ProviderResult.success(42, providerId: 'p1');
    expect(result.isSuccess, true);
    expect(result.data, 42);
  });

  test('ProviderResult failure', () {
    final result = ProviderResult<int>.failure(Exception('err'));
    expect(result.isFailure, true);
  });
}