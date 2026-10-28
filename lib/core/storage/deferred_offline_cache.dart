import 'dart:async';

import 'offline_cache.dart';

/// An [OfflineCache] that is usable before the on-disk store exists.
///
/// The app's first frame must not wait for a Hive box: on a low-RAM device a
/// multi-megabyte box can take seconds to parse, and the launch screen would
/// stay up for that whole time. `main()` therefore hands this cache to the
/// widget tree immediately and opens Hive in the background; [attach] swaps the
/// real store in as soon as it is ready.
///
/// Behaviour before [attach]:
/// * reads and writes are served by an in-memory store, so the app behaves
///   exactly as it does with a warm cache;
/// * the last [maxPendingWrites] writes are remembered and replayed onto the
///   disk store in order, so nothing the user did during the first frames is
///   silently dropped;
/// * [clear] supersedes everything queued before it.
///
/// The queue is bounded on purpose: a cache may lose work, but it must never
/// grow without limit or hold the UI hostage.
class DeferredOfflineCache implements OfflineCache {
  DeferredOfflineCache({OfflineCache? initial})
    : _inner = initial ?? MemoryOfflineCache();

  /// How many pre-attach writes are replayed. The first frames write at most a
  /// handful of entries (locale, onboarding, a Home snapshot); the cap only
  /// exists so a pathological loop cannot grow the queue forever.
  static const int maxPendingWrites = 64;

  OfflineCache _inner;
  final List<_PendingWrite> _pending = <_PendingWrite>[];
  final Completer<void> _ready = Completer<void>();

  bool _attached = false;
  bool _flushing = false;

  /// Whether the disk store has replaced the in-memory fallback.
  bool get isAttached => _attached;

  /// Completes when the disk store is attached. Already complete when [attach]
  /// has run.
  Future<void> get ready => _ready.future;

  /// Replaces the in-memory store with [cache] and replays queued writes.
  ///
  /// Idempotent: a second call (a retry after a slow open) is ignored.
  Future<void> attach(OfflineCache cache) async {
    if (_attached) return;

    _inner = cache;
    _flushing = true;
    try {
      // Writes issued while flushing go straight to the real store and are not
      // queued, so this loop only drains what happened before [attach].
      while (_pending.isNotEmpty) {
        final batch = List<_PendingWrite>.of(_pending);
        _pending.clear();
        for (final pending in batch) {
          await pending.apply(cache);
        }
      }
    } finally {
      _flushing = false;
      _attached = true;
      if (!_ready.isCompleted) _ready.complete();
    }
  }

  void _enqueue(_PendingWrite write) {
    if (_pending.length >= maxPendingWrites) {
      // Drop the oldest: the newest writes are the ones the UI just made.
      _pending.removeAt(0);
    }
    _pending.add(write);
  }

  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    await _inner.write(key, value);
    if (!_attached && !_flushing) {
      _enqueue(_PendingWrite.write(key, value));
    }
  }

  @override
  Future<Map<String, dynamic>?> read(String key) => _inner.read(key);

  @override
  Future<bool> contains(String key) => _inner.contains(key);

  @override
  Future<List<String>> keys() => _inner.keys();

  @override
  Future<void> compact() => _inner.compact();

  @override
  Future<void> delete(String key) async {
    await _inner.delete(key);
    if (!_attached && !_flushing) {
      _pending.removeWhere(
        (pending) => pending.key == key && pending.kind == _WriteKind.write,
      );
      _enqueue(_PendingWrite.delete(key));
    }
  }

  @override
  Future<void> clear() async {
    await _inner.clear();
    if (!_attached && !_flushing) {
      // A clear erases everything queued before it, including the in-memory
      // values those writes had produced.
      _pending.clear();
      _enqueue(const _PendingWrite.clear());
    }
  }
}

enum _WriteKind { write, delete, clear }

/// One deferred mutation, replayed in order once the disk store exists.
class _PendingWrite {
  const _PendingWrite.write(this.key, this.value) : kind = _WriteKind.write;

  const _PendingWrite.delete(this.key) : kind = _WriteKind.delete, value = null;

  const _PendingWrite.clear()
    : kind = _WriteKind.clear,
      key = null,
      value = null;

  final _WriteKind kind;
  final String? key;
  final Map<String, dynamic>? value;

  Future<void> apply(OfflineCache cache) {
    switch (kind) {
      case _WriteKind.write:
        return cache.write(key!, value!);
      case _WriteKind.delete:
        return cache.delete(key!);
      case _WriteKind.clear:
        return cache.clear();
    }
  }
}
