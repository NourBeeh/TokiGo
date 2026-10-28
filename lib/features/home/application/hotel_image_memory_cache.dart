import 'package:flutter/foundation.dart';

import 'package:tokigo/features/home/application/hotel_image_cache.dart';

/// Phase H3+ (user bug 2026-09-08 — "images reload on every scroll"):
/// a synchronous in-memory layer in FRONT of the Hive-backed
/// [HotelImageCache].
///
/// Why: the ListView destroys off-screen cards (no keep-alive state), so a
/// re-mounted card re-reads Hive asynchronously — the user sees the shimmer
/// placeholder flash on EVERY scroll-back even though the bytes are on
/// disk. This layer keeps the decoded-source bytes in memory (bounded, same
/// LRU/TTL discipline as the disk layer) so a re-mounted card renders its
/// photo in the SAME frame — zero placeholder flash within a session.
///
/// Disk stays the cold-start truth; this is a session-scoped fast path.
/// Bounded: same 30-entry cap as the disk cache (~30 decoded-source
/// entries; the ENGINE's own ImageCache holds the actual decoded bitmaps).
class HotelImageMemoryCache {
  HotelImageMemoryCache({this.maxEntries = HotelImageCache.maxEntries});

  /// Entry cap — matches the disk layer (LRU eviction above it).
  final int maxEntries;

  final _entries = <String, _MemEntry>{};
  DateTime Function() _now = () => DateTime.now();

  @visibleForTesting
  void setClockForTests(DateTime Function() now) => _now = now;

  /// Synchronous read: `null` means "not warm — go to the disk layer".
  Uint8List? read(String url) {
    final entry = _entries[url];
    if (entry == null) return null;
    if (_now().difference(entry.cachedAt) > HotelImageCache.ttl) {
      _entries.remove(url);
      return null;
    }
    // LRU touch.
    _entries.remove(url);
    _entries[url] = entry;
    return entry.bytes;
  }

  /// Records bytes seen this session (called on every disk/network hit so
  /// the next synchronous read is instant).
  void write(String url, Uint8List bytes) {
    _entries.remove(url);
    _entries[url] = _MemEntry(bytes: bytes, cachedAt: _now());
    _evictIfNeeded();
  }

  void clear() => _entries.clear();

  int get length => _entries.length;

  void _evictIfNeeded() {
    if (_entries.length <= maxEntries) return;
    // Oldest-inserted first (LinkedHashMap order == insertion/LRU order
    // because every read re-inserts at the tail).
    final excess = _entries.length - maxEntries;
    final victims = _entries.keys.take(excess).toList();
    for (final key in victims) {
      _entries.remove(key);
    }
  }
}

class _MemEntry {
  _MemEntry({required this.bytes, required this.cachedAt});

  final Uint8List bytes;
  final DateTime cachedAt;
}
