class IdempotencyStore {
  static final Map<String, dynamic> _store = {};

  static T? get<T>(String key) => _store[key] as T?;

  static void put(String key, dynamic value) {
    _store[key] = value;
  }

  static bool contains(String key) => _store.containsKey(key);
}
