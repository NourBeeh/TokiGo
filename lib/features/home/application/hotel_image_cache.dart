import 'dart:typed_data';

import 'package:tokigo/core/storage/offline_cache.dart';

/// H3 — Hive-backed hotel image cache (LRU + TTL).
///
/// Stores encoded image BYTES (not decoded bitmaps) under `hotel_image|<url>`
/// inside the EXISTING shared OfflineCache box — no new Hive box, no new
/// packages, and the same AES-256 Hive foundation as the rest of the app.
///
/// Eviction policy (applied on every write):
/// - **TTL:** entries older than [ttl] are dropped (a hotel refreshing its
///   photos surfaces within a week).
/// - **LRU:** when the cache holds more than [maxEntries], the least
///   recently used (by [ImageCacheEntry.lastUsedAt]) entries are evicted
///   until back under the cap — a stable, deterministic ordering.
///
/// Failure policy: every method is best-effort and never throws — a broken
/// cache must degrade to a plain network fetch, never break the Home UI.
class HotelImageCache {
  HotelImageCache(this._cache, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  static const String _keyPrefix = 'hotel_image|';

  /// Maximum cached images (≈ the Home rail's realistic worst case plus
  /// headroom; ~30 × 100-300KB ≈ 3-9MB of encoded bytes on disk).
  static const int maxEntries = 30;

  /// Entries older than this are considered stale and evicted/ignored.
  static const Duration ttl = Duration(days: 7);

  final OfflineCache _cache;
  final DateTime Function() _now;

  /// Reads a cached image for [url] (also refreshes its LRU timestamp).
  /// Returns null on miss, stale entry, malformed entry, or storage error.
  Future<Uint8List?> read(String url) async {
    try {
      final raw = await _cache.read(_keyFor(url));
      if (raw == null) return null;
      final entry = ImageCacheEntry.fromMap(raw);
      if (entry == null) return null;
      final age = _now().difference(entry.cachedAt);
      if (age > ttl) {
        // Stale — evict lazily and report a miss (caller re-fetches).
        await _cache.delete(_keyFor(url));
        return null;
      }
      // LRU touch: rewrite the entry with a fresh lastUsedAt.
      await _cache.write(
        _keyFor(url),
        entry.touched(_now()).toMap(),
      );
      return entry.bytes;
    } catch (_) {
      return null; // Best-effort — degrade to network fetch.
    }
  }

  /// Stores [bytes] for [url] and enforces TTL + LRU eviction.
  Future<void> write(String url, Uint8List bytes) async {
    try {
      final now = _now();
      await _cache.write(
        _keyFor(url),
        ImageCacheEntry(
          bytes: bytes,
          cachedAt: now,
          lastUsedAt: now,
        ).toMap(),
      );
      await _evict();
    } catch (_) {
      // Best-effort — a failed write never breaks the UI.
    }
  }

  /// Drops every cached image (best-effort; used by tests).
  Future<void> clear() async {
    try {
      final keys = await _cache.keys();
      for (final key in keys) {
        if (key.startsWith(_keyPrefix)) {
          await _cache.delete(key);
        }
      }
    } catch (_) {
      // Best-effort.
    }
  }

  static String _keyFor(String url) => '$_keyPrefix$url';

  /// Enforces TTL (drop everything older than [ttl]) then LRU (drop the
  /// least-recently-used until at most [maxEntries] remain).
  Future<void> _evict() async {
    final keys = await _cache.keys();
    final imageKeys = keys.where((k) => k.startsWith(_keyPrefix)).toList();
    if (imageKeys.isEmpty) return;

    // Read all entries (best-effort; malformed ones are treated as stale).
    final entries = <_EvictionCandidate>[];
    for (final key in imageKeys) {
      final raw = await _cache.read(key);
      final entry = raw == null ? null : ImageCacheEntry.fromMap(raw);
      if (entry == null) {
        await _cache.delete(key); // Malformed — remove.
        continue;
      }
      entries.add(_EvictionCandidate(key, entry.cachedAt, entry.lastUsedAt));
    }

    // TTL pass.
    final now = _now();
    final alive = <_EvictionCandidate>[];
    for (final candidate in entries) {
      final isStale = now.difference(candidate.cachedAt) > ttl;
      if (isStale) {
        await _cache.delete(candidate.key);
      } else {
        alive.add(candidate);
      }
    }

    // LRU pass: least-recently-used first until under the cap.
    if (alive.length <= maxEntries) return;
    alive.sort(
      (a, b) => a.lastUsedAt.compareTo(b.lastUsedAt),
    );
    final overflow = alive.length - maxEntries;
    for (var i = 0; i < overflow; i++) {
      await _cache.delete(alive[i].key);
    }
  }
}

/// One cached image with its bookkeeping timestamps.
///
/// Stored as a plain map inside the shared OfflineCache box; `bytes` is a
/// `Uint8List` (encoded PNG/JPEG/WebP — Hive's default adapter persists
/// typed lists natively).
class ImageCacheEntry {
  const ImageCacheEntry({
    required this.bytes,
    required this.cachedAt,
    required this.lastUsedAt,
  });

  final Uint8List bytes;
  final DateTime cachedAt;
  final DateTime lastUsedAt;

  ImageCacheEntry touched(DateTime at) => ImageCacheEntry(
        bytes: bytes,
        cachedAt: cachedAt,
        lastUsedAt: at,
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        'bytes': bytes,
        'cachedAt': cachedAt.toIso8601String(),
        'lastUsedAt': lastUsedAt.toIso8601String(),
      };

  /// Tolerant reader: any malformed field → null (never crash the Home).
  static ImageCacheEntry? fromMap(Map<String, dynamic> map) {
    final rawBytes = map['bytes'];
    final cachedAt = DateTime.tryParse(map['cachedAt']?.toString() ?? '');
    final lastUsedAt = DateTime.tryParse(map['lastUsedAt']?.toString() ?? '');
    if (rawBytes is! Uint8List || cachedAt == null || lastUsedAt == null) {
      return null;
    }
    return ImageCacheEntry(
      bytes: rawBytes,
      cachedAt: cachedAt,
      lastUsedAt: lastUsedAt,
    );
  }
}

class _EvictionCandidate {
  const _EvictionCandidate(this.key, this.cachedAt, this.lastUsedAt);

  final String key;
  final DateTime cachedAt;
  final DateTime lastUsedAt;
}
