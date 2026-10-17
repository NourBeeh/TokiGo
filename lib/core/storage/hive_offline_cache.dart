import 'dart:async';

import 'package:hive/hive.dart';

import 'offline_cache.dart';

/// Hive-backed [OfflineCache] for the Phase 16 offline support foundation.
///
/// Hive is a pure-Dart key-value store with AES-256 encryption and no native
/// dependencies, so it works identically on mobile, desktop and web. Values
/// are stored as `Map` entries (boxes are `Box<Map>`), which keeps the domain
/// serializers in `offline_cache_serializers.dart` the single source of shape
/// knowledge.
///
/// IMPORTANT: Hive's binary serialization does NOT preserve generic type
/// arguments — a `Map<String, dynamic>` written to disk is read back as
/// `Map<dynamic, dynamic>`, so a strictly typed box (`Box<Map<String,
/// dynamic>>`) explodes with a type-cast error the first time an entry is
/// loaded from disk. The box is therefore deliberately typed `Box<Map>` and
/// [read] deep-converts every entry back to a proper
/// `Map<String, dynamic>` tree via [convertHiveValue].
class HiveOfflineCache implements OfflineCache {
  HiveOfflineCache(this._box);

  final Box<Map> _box;

  static const String defaultBoxName = 'tokigo_offline';

  /// Initializes Hive (assigns its on-disk home) and opens the box used by the
  /// offline cache. [homeDir] defaults to a per-app folder in the process
  /// working directory, which the platform layer can override later.
  ///
  /// Safe to call repeatedly: `openBox` returns the already-open box instance.
  static Future<HiveOfflineCache> open({
    String? homeDir,
    required String boxName,
  }) async {
    Hive.init(homeDir ?? _defaultHomeDir);
    final box = await Hive.openBox<Map>(boxName);
    return HiveOfflineCache(box);
  }

  static const String _defaultHomeDir = 'tokigo_offline_data';

  @override
  Future<void> clear() async {
    for (final key in _box.toMap().keys.toList()) {
      _box.delete(key);
    }
  }

  @override
  Future<bool> contains(String key) async => _box.get(key) != null;

  @override
  Future<void> delete(String key) async {
    _box.delete(key);
  }

  @override
  Future<Map<String, dynamic>?> read(String key) async =>
      convertHiveValue(_box.get(key));

  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    _box.put(key, value);
  }

  @override
  Future<List<String>> keys() async =>
      _box.toMap().keys.map((k) => k.toString()).toList();

  /// Deep-converts a raw (possibly Hive-deserialized) value into a
  /// `Map<String, dynamic>` tree. Returns null for non-map input.
  ///
  /// Recurses through nested maps and lists, converting keys with
  /// `toString()` so entries that survived a disk round-trip as
  /// `Map<dynamic, dynamic>` become safe to consume by typed callers.
  static Map<String, dynamic>? convertHiveValue(Object? raw) {
    if (raw is! Map) return null;
    return raw.map((k, v) => MapEntry(k.toString(), _convertValue(v)));
  }

  static Object? _convertValue(Object? value) {
    if (value is Map) return convertHiveValue(value);
    if (value is List) return value.map(_convertValue).toList();
    return value;
  }
}
