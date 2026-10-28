import 'dart:async';

import 'package:tokigo/core/storage/offline_cache.dart';
import 'package:tokigo/features/home/domain/home_composer.dart';

/// Read-only scan of the EXISTING local search caches (Phase 1B).
///
/// The store never writes anything: it decodes the flight/hotel/car search
/// cache keys the search controllers already persist (same box, same key
/// format as `offline_cache_serializers.dart`) into behavioral signals for
/// the Home composer. This is the anonymous user's "local memory" — no
/// backend, no new tracking.
class LocalBehaviorStore {
  LocalBehaviorStore(this._cache);

  final OfflineCache _cache;

  static const int _maxSignals = 6;

  /// Decodes the user's recent searches from cache keys, newest first.
  Future<List<RecentSearchSignal>> recentSearches({
    int limit = _maxSignals,
  }) async {
    List<String> keys;
    try {
      keys = await _cache.keys();
    } catch (_) {
      return const [];
    }

    final signals = <_ScoredSignal>[];
    for (final key in keys) {
      final decoded = _decode(key);
      if (decoded == null) continue;
      final entry = await _readTimestamp(key);
      signals.add(
        _ScoredSignal(decoded.signal, entry?['timestamp']?.toString(), key),
      );
    }

    // Order by the stored timestamp when present, key as a stable tiebreak.
    signals.sort((a, b) {
      final at = DateTime.tryParse(a.timestamp ?? '');
      final bt = DateTime.tryParse(b.timestamp ?? '');
      if (at != null && bt != null) return bt.compareTo(at);
      if (at != null) return -1;
      if (bt != null) return 1;
      return b.key.compareTo(a.key);
    });

    final unique = <String>{};
    final out = <RecentSearchSignal>[];
    for (final s in signals) {
      if (out.length >= limit) break;
      if (!unique.add(s.signal.label)) continue;
      out.add(s.signal);
    }
    return out;
  }

  /// True when ANY local behavioral footprint exists (search keys or a Home
  /// snapshot). Used to separate fresh from returning anonymous users —
  /// read-only, never writes a counter.
  Future<bool> hasLocalFootprint() async {
    try {
      final keys = await _cache.keys();
      final hasSearch = keys.any(
        (k) =>
            k.startsWith('flight|') ||
            k.startsWith('hotel|') ||
            k.startsWith('car|'),
      );
      final hasSnapshot = keys.any((k) => k.startsWith('home|snapshot|'));
      return hasSearch || hasSnapshot;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> _readTimestamp(String key) async {
    try {
      return await _cache.read(key);
    } catch (_) {
      return null;
    }
  }

  /// Decodes one cache key into a signal.
  ///
  /// Key formats (from `offline_cache_serializers.dart`):
  ///   flight|orig|dest|ISO[|retISO][|pax]  → 'Cairo → Paris'
  ///   hotel|city|ISO|ISO[|guests]          → 'Hotels in Cairo'
  ///   car|loc|ISO|ISO                       → 'Cars in Cairo'
  _DecodedSearch? _decode(String key) {
    final parts = key.split('|');
    switch (parts.first) {
      case 'flight':
        if (parts.length < 4) return null;
        final origin = _title(parts[1]);
        final dest = _title(parts[2]);
        if (origin.isEmpty || dest.isEmpty) return null;
        return _DecodedSearch(
          RecentSearchSignal(
            kind: 'flight',
            label: '$origin → $dest',
            at:
                DateTime.tryParse(parts[3]) ??
                DateTime.fromMillisecondsSinceEpoch(0),
          ),
          key,
        );
      case 'hotel':
        if (parts.length < 4) return null;
        final city = _title(parts[1]);
        if (city.isEmpty) return null;
        return _DecodedSearch(
          RecentSearchSignal(
            kind: 'hotel',
            label: 'Hotels in $city',
            at:
                DateTime.tryParse(parts[2]) ??
                DateTime.fromMillisecondsSinceEpoch(0),
          ),
          key,
        );
      case 'car':
        if (parts.length < 4) return null;
        final loc = _title(parts[1]);
        if (loc.isEmpty) return null;
        return _DecodedSearch(
          RecentSearchSignal(
            kind: 'car',
            label: 'Cars in $loc',
            at:
                DateTime.tryParse(parts[2]) ??
                DateTime.fromMillisecondsSinceEpoch(0),
          ),
          key,
        );
      default:
        return null;
    }
  }

  String _title(String raw) {
    if (raw.isEmpty) return '';
    return raw
        .split(RegExp(r'[_\s]+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }
}

class _DecodedSearch {
  _DecodedSearch(this.signal, this.key);
  final RecentSearchSignal signal;
  final String key;
}

class _ScoredSignal {
  _ScoredSignal(this.signal, this.timestamp, this.key);
  final RecentSearchSignal signal;
  final String? timestamp;
  final String key;
}
