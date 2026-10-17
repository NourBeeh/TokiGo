import 'package:flutter_test/flutter_test.dart';
import 'package:tokigo/features/booking/application/idempotency_store.dart';

void main() {
  test('idempotency first and repeat', () {
    const key = 'test-key';
    IdempotencyStore.put(key, 'result');
    expect(IdempotencyStore.contains(key), true);
    expect(IdempotencyStore.get<String>(key), 'result');
  });
}
