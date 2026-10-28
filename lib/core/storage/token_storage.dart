/// Secure persistence contract for tokens and lightweight preferences.
///
/// Phase 1 declares the interface only. A concrete implementation (e.g.
/// keychain / shared_preferences / secure storage) lands in a later phase; no
/// Package is added unless it becomes strictly necessary.
abstract interface class TokenStorage {
  /// Persists [value] under [key].
  Future<void> write(String key, String value);

  /// Reads [key] or returns `null` when absent.
  Future<String?> read(String key);

  /// Removes [key]. Missing keys are a no-op.
  Future<void> delete(String key);

  /// Whether [key] currently has a value.
  Future<bool> contains(String key);

  /// Removes every stored value for this session.
  Future<void> clear();
}

/// Non-persisting in-memory store used until a real implementation lands.
class MemoryTokenStorage implements TokenStorage {
  final Map<String, String> _store = <String, String>{};

  @override
  Future<void> clear() async => _store.clear();

  @override
  Future<bool> contains(String key) async => _store.containsKey(key);

  @override
  Future<void> delete(String key) async => _store.remove(key);

  @override
  Future<String?> read(String key) async => _store[key];

  @override
  Future<void> write(String key, String value) async => _store[key] = value;
}
