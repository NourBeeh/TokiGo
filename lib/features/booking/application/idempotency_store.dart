import 'package:meta/meta.dart';

class IdempotencyStore {
  static final Map<String, dynamic> _store = {};

  static T? get<T>(String key) => _store[key] as T?;

  static void put(String key, dynamic value) {
    _store[key] = value;
  }

  static bool contains(String key) => _store.containsKey(key);

  /// Test-only reset. The cache is process-wide, so a test that confirms a
  /// booking would otherwise leak its key into the next scenario.
  @visibleForTesting
  static void clear() => _store.clear();
}
