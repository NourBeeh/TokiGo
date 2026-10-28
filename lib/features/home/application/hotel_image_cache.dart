import 'dart:async';
import 'dart:typed_data';

import 'package:tokigo/core/storage/deferred_offline_cache.dart';
import 'package:tokigo/core/storage/offline_cache.dart';

import 'hotel_image_blob_store.dart';

/// H3 — hotel image cache: metadata in the offline cache, bytes on disk.
///
/// **Why not bytes in Hive?** Hive parses its box file at launch. A dozen hotel
/// photos (200KB–2MB each) turned the shared box into a multi-megabyte launch
/// cost — on a low-RAM device that was seconds of splash screen. Encoded images
/// now live as plain files ([HotelImageBlobStore], the same split Meta's Fresco
/// uses: a small index in the store, blobs on disk) and the box only holds a
/// few bytes of metadata per photo.
///
/// Eviction policy (applied on every write):
/// - **TTL:** entries older than [ttl] are dropped (a hotel refreshing its
///   photos surfaces within a week).
/// - **LRU + size:** when the cache holds more than [maxEntries] or more than
///   [maxBytes], the least recently used entries are evicted until both caps
///   hold — a byte cap matters more than an entry count because one photo can
///   be twenty times another.
///
/// Failure policy: every method is best-effort and never throws — a broken
/// cache must degrade to a plain network fetch, never break the Home UI.
class HotelImageCache {
  HotelImageCache(
    this._cache, {
    HotelImageBlobStore? blobs,
    DateTime Function()? now,
  }) : _blobs = blobs ?? FileHotelImageBlobStore(),
       _now = now ?? DateTime.now;

  static const String _keyPrefix = 'hotel_image|';

  /// Bookkeeping key: bumped once the legacy photo bytes have left the box and
  /// the file has been compacted. Kept out of the `hotel_image|` namespace so
  /// eviction never treats it as a photo.
  static const String _schemaKey = 'hotel_image_schema';
  static const int _schemaVersion = 2;

  /// Maximum cached images. The Home rail realistically shows ~10 at once;
  /// the rest is headroom for a second row and a city rail.
  static const int maxEntries = 30;

  /// Hard cap on the bytes kept on disk. Entry count alone cannot bound this:
  /// observed hotel photos range from 200KB to 2MB.
  static const int maxBytes = 24 * 1024 * 1024;

  /// A single image above this size is served but not cached — it would evict
  /// several useful photos to buy one.
  static const int maxEntryBytes = 4 * 1024 * 1024;

  /// Entries older than this are considered stale and evicted/ignored.
  static const Duration ttl = Duration(days: 7);

  /// Repeated reads inside this window skip the LRU write. Ordering only needs
  /// minute-level precision, and on a lazy box every touch is a disk write.
  static const Duration _touchInterval = Duration(minutes: 1);

  final OfflineCache _cache;
  final HotelImageBlobStore _blobs;
  final DateTime Function() _now;

  /// Serializes mutations: several cards load at once, and eviction must not
  /// delete a blob another write is still finishing.
  Future<void> _queue = Future<void>.value();
  int _nameCounter = 0;

  /// Metadata of every cached image, loaded once per session.
  ///
  /// The box is opened lazily on the device, so reading 30 entries from it on
  /// every write would turn each photo into 30 disk seeks. The index keeps the
  /// same information in memory; the box stays the durable copy.
  Map<String, ImageCacheEntry>? _index;

  /// How many legacy byte entries this cache has moved out of Hive. Tracked
  /// across both paths (background [maintain] and lazy reads) because whichever
  /// runs first must trigger the compaction — otherwise the box keeps paying
  /// for the deleted photo bytes at every launch.
  int _legacyMigrations = 0;

  Future<T> _locked<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  /// Reads a cached image for [url] (also refreshes its LRU timestamp).
  /// Returns null on miss, stale entry, malformed entry, or storage error.
  Future<Uint8List?> read(String url) async {
    try {
      return await _locked(() async {
        final key = _keyFor(url);
        final index = await _indexLocked();
        final entry = index[key];
        if (entry == null) return null;

        final now = _now();
        if (now.difference(entry.cachedAt) > ttl) {
          // Stale — evict lazily and report a miss (caller re-fetches).
          await _removeLocked(key, entry);
          return null;
        }

        final resolved = await _resolveLocked(key, entry);
        if (resolved == null) {
          index.remove(key);
          return null;
        }

        // LRU touch: rewrite the metadata with a fresh lastUsedAt. A legacy
        // entry was just migrated to a blob, so use the resolved entry —
        // rewriting the old byte map would undo that.
        if (now.difference(resolved.entry.lastUsedAt) >= _touchInterval) {
          final touched = resolved.entry.touched(now);
          await _cache.write(key, touched.toMap());
          index[key] = touched;
        } else {
          index[key] = resolved.entry;
        }
        return resolved.bytes;
      });
    } catch (_) {
      return null; // Best-effort — degrade to network fetch.
    }
  }

  /// Stores [bytes] for [url] and enforces TTL + LRU eviction.
  Future<void> write(String url, Uint8List bytes) async {
    if (bytes.isEmpty || bytes.length > maxEntryBytes) return;
    try {
      await _locked(() async {
        final key = _keyFor(url);
        final index = await _indexLocked();
        final previous = index[key];

        final name = _newBlobName();
        if (!await _blobs.write(name, bytes)) return;

        final now = _now();
        final entry = ImageCacheEntry(
          file: name,
          size: bytes.length,
          cachedAt: now,
          lastUsedAt: now,
        );
        await _cache.write(key, entry.toMap());
        index[key] = entry;

        // The old blob is unreachable now that metadata points at the new one.
        final oldFile = previous?.file;
        if (oldFile != null && oldFile.isNotEmpty) {
          await _blobs.delete(oldFile);
        }
        await _evictLocked(index);
      });
    } catch (_) {
      // Best-effort — a failed write never breaks the UI.
    }
  }

  /// Drops every cached image (best-effort; used by tests and Settings).
  Future<void> clear() async {
    try {
      await _locked(() async {
        final index = await _indexLocked();
        for (final key in index.keys.toList()) {
          await _removeLocked(key, index[key]);
        }
        index.clear();
        // Anything left on disk is unreachable.
        for (final name in await _blobs.list()) {
          await _blobs.delete(name);
        }
      });
    } catch (_) {
      // Best-effort.
    }
  }

  /// One-time housekeeping after launch.
  ///
  /// Entries written before the file migration still hold their bytes inside
  /// Hive. Moving them out (and compacting the box afterwards) is what turns
  /// the old multi-megabyte box into a few kilobytes — the difference between
  /// a five-second and a sub-second open on a low-RAM device. Runs in the
  /// background; nothing here is required for the UI.
  Future<void> maintain() async {
    try {
      final cache = _cache;
      if (cache is DeferredOfflineCache) {
        await cache.ready.timeout(
          const Duration(seconds: 30),
          onTimeout: () {},
        );
        if (!cache.isAttached) return;
      }

      final schemaVersion = await _locked(() async {
        final raw = await _cache.read(_schemaKey);
        final version = raw?['version'];
        return version is int ? version : 1;
      });
      if (schemaVersion >= _schemaVersion && _legacyMigrations == 0) return;

      final migrated = await _locked(() async {
        var count = 0;
        for (final key in (await _cache.keys()).where(
          (k) => k.startsWith(_keyPrefix),
        )) {
          final raw = await _cache.read(key);
          final entry = raw == null ? null : ImageCacheEntry.fromMap(raw);
          if (entry == null) {
            await _cache.delete(key);
            continue;
          }
          final legacyBytes = entry.bytes;
          if (legacyBytes == null || legacyBytes.isEmpty) continue;

          final name = _newBlobName();
          if (!await _blobs.write(name, legacyBytes)) {
            await _cache.delete(key);
            continue;
          }
          await _cache.write(
            key,
            ImageCacheEntry(
              file: name,
              size: legacyBytes.length,
              cachedAt: entry.cachedAt,
              lastUsedAt: entry.lastUsedAt,
            ).toMap(),
          );
          count++;
        }
        // The box changed underneath the index.
        _index = null;
        return count;
      });

      // A concurrent first read may have migrated some entries before this
      // pass ran; either path must trigger the same compaction. The schema key
      // is written only AFTER the box is compacted, so an app killed mid-way
      // retries on the next launch instead of leaving the bloat behind.
      if (migrated > 0 ||
          _legacyMigrations > 0 ||
          schemaVersion < _schemaVersion) {
        await _cache.compact();
        _legacyMigrations = 0;
        await _cache.write(_schemaKey, <String, dynamic>{
          'version': _schemaVersion,
        });
      }
    } catch (_) {
      // Best-effort: a failed migration leaves the cache working as before.
    }
  }

  static String _keyFor(String url) => '$_keyPrefix$url';

  String _newBlobName() =>
      '${_now().microsecondsSinceEpoch}_${_nameCounter++}.img';

  /// Loads the metadata index once, pruning entries that cannot be used.
  Future<Map<String, ImageCacheEntry>> _indexLocked() async {
    final existing = _index;
    if (existing != null) return existing;

    final index = <String, ImageCacheEntry>{};
    for (final key in (await _cache.keys()).where(
      (k) => k.startsWith(_keyPrefix),
    )) {
      final raw = await _cache.read(key);
      final entry = raw == null ? null : ImageCacheEntry.fromMap(raw);
      if (entry == null) {
        await _cache.delete(key); // Malformed — remove.
        continue;
      }
      index[key] = entry;
    }
    return _index = index;
  }

  /// Resolves an entry's bytes, migrating a legacy byte entry to a blob on the
  /// way (so old installs heal without a dedicated pass).
  Future<_ResolvedImage?> _resolveLocked(
    String key,
    ImageCacheEntry entry,
  ) async {
    final file = entry.file;
    if (file != null && file.isNotEmpty) {
      final bytes = await _blobs.read(file);
      if (bytes == null) {
        // Metadata without its blob: unrecoverable, drop the entry.
        await _removeLocked(key, entry);
        return null;
      }
      return _ResolvedImage(bytes, entry);
    }

    final legacy = entry.bytes;
    if (legacy == null || legacy.isEmpty) {
      await _removeLocked(key, entry);
      return null;
    }

    final name = _newBlobName();
    if (!await _blobs.write(name, legacy)) {
      // Keep serving the bytes we have; the next read retries the migration.
      return _ResolvedImage(legacy, entry);
    }
    final migrated = ImageCacheEntry(
      file: name,
      size: legacy.length,
      cachedAt: entry.cachedAt,
      lastUsedAt: entry.lastUsedAt,
    );
    await _cache.write(key, migrated.toMap());
    _legacyMigrations++;
    return _ResolvedImage(legacy, migrated);
  }

  Future<void> _removeLocked(String key, ImageCacheEntry? entry) async {
    await _cache.delete(key);
    _index?.remove(key);
    final file = entry?.file;
    if (file != null && file.isNotEmpty) await _blobs.delete(file);
  }

  /// Enforces TTL (drop everything older than [ttl]) then LRU (drop the least
  /// recently used until both [maxEntries] and [maxBytes] hold).
  Future<void> _evictLocked(Map<String, ImageCacheEntry> index) async {
    final now = _now();
    for (final key in index.keys.toList()) {
      final entry = index[key];
      if (entry == null) continue;
      if (now.difference(entry.cachedAt) > ttl) {
        await _removeLocked(key, entry);
      }
    }

    var totalBytes = index.values.fold<int>(0, (sum, e) => sum + e.size);
    if (index.length <= maxEntries && totalBytes <= maxBytes) return;

    // Least-recently-used first until both caps hold.
    final alive = index.entries.toList()
      ..sort((a, b) => a.value.lastUsedAt.compareTo(b.value.lastUsedAt));
    for (final candidate in alive) {
      if (index.length <= maxEntries && totalBytes <= maxBytes) break;
      if (!index.containsKey(candidate.key)) continue;
      await _removeLocked(candidate.key, candidate.value);
      totalBytes -= candidate.value.size;
    }
  }
}

/// One cached image with its bookkeeping timestamps.
///
/// [file] points at a blob in [HotelImageBlobStore]; [bytes] is only populated
/// by entries written before the file migration (lazy-migrated on first read).
class ImageCacheEntry {
  const ImageCacheEntry({
    this.file,
    this.bytes,
    required this.size,
    required this.cachedAt,
    required this.lastUsedAt,
  });

  final String? file;
  final Uint8List? bytes;
  final int size;
  final DateTime cachedAt;
  final DateTime lastUsedAt;

  /// Same entry with a fresh LRU timestamp.
  ImageCacheEntry touched(DateTime at) => ImageCacheEntry(
    file: file,
    bytes: bytes,
    size: size,
    cachedAt: cachedAt,
    lastUsedAt: at,
  );

  Map<String, dynamic> toMap() => <String, dynamic>{
    if (file != null) 'file': file,
    if (bytes != null) 'bytes': bytes,
    'size': size,
    'cachedAt': cachedAt.toIso8601String(),
    'lastUsedAt': lastUsedAt.toIso8601String(),
  };

  /// Tolerant reader: any malformed field → null (never crash the Home).
  static ImageCacheEntry? fromMap(Map<String, dynamic> map) {
    final rawBytes = map['bytes'];
    // Accept both the typed list Hive stores and a plain byte list (older
    // boxes / a serializer that converted it) instead of declaring a valid
    // cached image "malformed" and deleting it on every read.
    final Uint8List? bytes = switch (rawBytes) {
      Uint8List value => value,
      List value => Uint8List.fromList(value.whereType<int>().toList()),
      _ => null,
    };
    final rawFile = map['file'];
    final String? file = rawFile is String && rawFile.isNotEmpty
        ? rawFile
        : null;

    final cachedAt = DateTime.tryParse(map['cachedAt']?.toString() ?? '');
    final lastUsedAt = DateTime.tryParse(map['lastUsedAt']?.toString() ?? '');
    if ((file == null && (bytes == null || bytes.isEmpty)) ||
        cachedAt == null ||
        lastUsedAt == null) {
      return null;
    }

    final rawSize = map['size'];
    final size = rawSize is int && rawSize >= 0
        ? rawSize
        : (bytes?.length ?? 0);

    return ImageCacheEntry(
      file: file,
      bytes: bytes,
      size: size,
      cachedAt: cachedAt,
      lastUsedAt: lastUsedAt,
    );
  }
}

/// The bytes of a cache hit together with the entry they came from — the entry
/// may differ from the stored one when a legacy byte entry was just migrated.
class _ResolvedImage {
  const _ResolvedImage(this.bytes, this.entry);

  final Uint8List bytes;
  final ImageCacheEntry entry;
}
