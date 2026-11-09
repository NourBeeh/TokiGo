import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import 'storage_bootstrap.dart';

/// Persists the last route the user was on, so the app can reopen where it
/// left off.
///
/// Only STATELESS destinations are restorable — a deep link that requires its
/// `extra` payload (offer details, booking funnel, …) would be lost on a cold
/// relaunch, so it falls back to Home instead of crashing or fabricating one.
///
/// The store is deliberately minimal: one key in the shared `tokigo_settings`
/// Hive box. Everything about it is optional — storage failures never block
/// app start and never crash the router.
class LastRouteStore {
  LastRouteStore._();

  static const String _boxName = 'tokigo_settings';
  static const String _key = 'last_route';

  /// The paths that are safe to restore on a cold relaunch (they need no
  /// `extra` payload). Query strings are preserved for the paths that carry
  /// one, e.g. `/bag?section=likes`.
  static const Set<String> _restorablePaths = <String>{
    '/',
    '/flights',
    '/hotels',
    '/cars',
    '/packages',
    '/groups',
    '/bag',
    '/notifications',
    '/profile',
    // Settings lives at `/settings` (a root-level destination, like Profile),
    // not under `/profile` — restoring a non-existent path would open the
    // router error page on a cold relaunch.
    '/settings',
    '/wishlist',
    '/search',
    '/explore',
    '/trip-builder',
    '/admin',
  };

  /// Whether [location] (with optional query) may be restored.
  static bool isRestorable(String location) {
    if (location.isEmpty) return false;
    final Uri? uri = Uri.tryParse(location);
    if (uri == null) return false;
    return _restorablePaths.contains(uri.path);
  }

  /// Reads the persisted location; null when nothing is stored or storage is
  /// unavailable.
  static Future<String?> read() async {
    try {
      await StorageBootstrap.ensureReady();
      final Box<Map> box = await _openBox();
      final String? value = box.get(_key)?['value'] as String?;
      return (value != null && isRestorable(value)) ? value : null;
    } catch (error) {
      _log('read failed', error);
      return null;
    }
  }

  /// Persists [location]. Never throws.
  static Future<void> write(String location) async {
    try {
      await StorageBootstrap.ensureReady();
      final Box<Map> box = await _openBox();
      await box.put(_key, <String, dynamic>{'value': location});
    } catch (error) {
      _log('write failed', error);
    }
  }

  static Future<Box<Map>> _openBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return Hive.openBox<Map>(_boxName);
    }
    return Hive.box<Map>(_boxName);
  }

  static void _log(String what, Object error) {
    assert(() {
      debugPrint('TokiGo last-route store $what — $error');
      return true;
    }());
  }
}
