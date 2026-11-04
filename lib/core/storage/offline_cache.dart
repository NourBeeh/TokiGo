/// Persistence contract for the Phase 16 offline support foundation.
///
/// Stores immutable JSON-safe maps under string keys so any domain object can
/// be cached by serializing it to a plain map at the repository boundary. A
/// real on-disk implementation (Hive) lives in `hive_offline_cache.dart`; the
/// in-memory implementation below is used by tests and as a no-op fallback.
abstract interface class OfflineCache {
  /// Persists [value] under [key], replacing any previous entry.
  Future<void> write(String key, Map<String, dynamic> value);

  /// Reads [key] or returns `null` when absent.
  Future<Map<String, dynamic>?> read(String key);

  /// Removes [key]. Missing keys are a no-op.
  Future<void> delete(String key);

  /// Whether [key] currently has a value.
  Future<bool> contains(String key);

  /// Removes every stored value for this cache.
  Future<void> clear();

  /// All currently stored keys (Phase 1B — local behavior signals are read by
  /// scanning key prefixes; never for writing). Order is unspecified.
  Future<List<String>> keys();

  /// Reclaims space left behind by deleted entries.
  ///
  /// Hive appends to its box file and only removes dead frames on compaction,
  /// so a box that once held large values keeps paying their disk size at every
  /// launch. Stores that do not need it (in-memory) make this a no-op.
  Future<void> compact();
}

/// Non-persisting in-memory store used by tests before a real store lands.
class MemoryOfflineCache implements OfflineCache {
  final Map<String, Map<String, dynamic>> _store =
      <String, Map<String, dynamic>>{};

  @override
  Future<void> clear() async => _store.clear();

  @override
  Future<bool> contains(String key) async => _store.containsKey(key);

  @override
  Future<void> delete(String key) async => _store.remove(key);

  @override
  Future<Map<String, dynamic>?> read(String key) async => _store[key];

  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    _store[key] = value;
  }

  @override
  Future<List<String>> keys() async => _store.keys.toList();

  @override
  Future<void> compact() async {
    // Nothing to reclaim: the store lives in memory.
  }
}

/// Sensible default 5-minute TTL for the offline Home snapshot. The value is
/// configurable at startup so the same app can be hardened (shorter) or tuned
/// (longer) without a code change. Reads the `HOME_CACHE_TTL_SECONDS` env var
/// on first use; a non-numeric or negative value falls back to [kDefaultTtl].
class HomeCacheConfig {
  static const int kDefaultTtlSeconds = 300; // 5 minutes
  static Duration? _cachedTtl;
  static int get ttlSeconds =>
      _cachedTtl?.inSeconds ?? _resolveTtlSeconds();
  static Duration get ttl => Duration(seconds: ttlSeconds);

  static int _resolveTtlSeconds() {
    final env = String.fromEnvironment('HOME_CACHE_TTL_SECONDS');
    try {
      final value = int.parse(env);
      return value > 0 ? value : kDefaultTtlSeconds;
    } catch (_) {
      return kDefaultTtlSeconds;
    }
  }
}
