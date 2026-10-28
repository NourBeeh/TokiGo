import 'dart:async';
import 'dart:typed_data';

import 'package:hive/hive.dart';

import 'offline_cache.dart';
import 'storage_bootstrap.dart';

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

  /// A **lazy** box on the device: Hive reads values on demand instead of
  /// parsing the whole file into memory when the box opens.
  ///
  /// This is Hive's own recommendation for large boxes, and the difference is
  /// measurable on a low-RAM device: opening a 460KB box eagerly cost ~800ms of
  /// main-isolate work at launch; a lazy open only reads the file index. Tests
  /// pass an already-open `Box<Map>`, which shares the same interface.
  final BoxBase<Map> _box;

  static const String defaultBoxName = 'tokigo_offline';

  /// Initializes Hive (assigns its on-disk home) and opens the box used by the
  /// offline cache. [homeDir] overrides the app's documents directory (tests,
  /// desktop tooling); when omitted the shared [StorageBootstrap] resolves it.
  ///
  /// Safe to call repeatedly: `openBox` returns the already-open box instance.
  ///
  /// Startup: callers on the launch path must NOT await this — see
  /// `DeferredOfflineCache` and `main.dart`.
  static Future<HiveOfflineCache> open({
    String? homeDir,
    required String boxName,
  }) async {
    if (homeDir != null) {
      Hive.init(homeDir);
    } else {
      await StorageBootstrap.ensureReady();
    }
    final box = await Hive.openLazyBox<Map>(boxName);
    return HiveOfflineCache(box);
  }

  @override
  Future<void> clear() async {
    try {
      for (final key in _box.keys.toList()) {
        await _box.delete(key);
      }
    } catch (_) {
      // A broken cache is not a reason to break the caller.
    }
  }

  @override
  Future<bool> contains(String key) async {
    try {
      return await _rawGet(key) != null;
    } catch (_) {
      return false;
    }
  }

  /// Reads a raw entry from either box flavour: the device uses a [LazyBox]
  /// (value read on demand, async), tests may pass an eager [Box] (in memory,
  /// sync). `BoxBase` itself declares no `get`.
  Future<Map?> _rawGet(dynamic key) {
    final box = _box;
    if (box is LazyBox<Map>) return box.get(key);
    return Future<Map?>.value((box as Box<Map>).get(key));
  }

  @override
  Future<void> delete(String key) async {
    try {
      await _box.delete(key);
    } catch (_) {
      // Best-effort.
    }
  }

  @override
  Future<Map<String, dynamic>?> read(String key) async {
    try {
      return convertHiveValue(await _rawGet(key));
    } catch (_) {
      // HiveError for an entry written by an older/incompatible schema, a
      // corrupted box after an abnormal process kill, etc. A cache miss is
      // always recoverable; an exception escaping into a search controller is
      // not (it left the results page stuck between loading and error).
      return null;
    }
  }

  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    try {
      await _box.put(key, value);
    } catch (_) {
      // Best-effort: a failed cache write never blocks the feature.
    }
  }

  @override
  Future<List<String>> keys() async {
    try {
      return _box.keys.map((k) => k.toString()).toList();
    } catch (_) {
      return const <String>[];
    }
  }

  @override
  Future<void> compact() async {
    try {
      await _box.compact();
    } catch (_) {
      // Best-effort: a failed compaction only costs disk space.
    }
  }

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
    // Typed byte lists are DATA here (the Home hotel-image cache stores
    // encoded image bytes). `Uint8List is List<int>`, so converting it with
    // `map()` below would silently turn it into a plain List<dynamic> and
    // invalidate the cache entry on every read — the Hive image cache looked
    // "broken" while it was actually discarding what it had just stored.
    if (value is Uint8List) return value;
    if (value is TypedData) return value;
    if (value is Map) return convertHiveValue(value);
    if (value is List) return value.map(_convertValue).toList();
    return value;
  }
}
