import 'package:hive/hive.dart';

import 'storage_bootstrap.dart';

/// Persists the traveller's last visited destination (Task 11).
///
/// Uses the same lightweight Hive settings box as the onboarding flag, so the
/// value survives a cold start and is readable before the first frame. Every
/// operation is best-effort: a storage failure must never block navigation.
abstract final class ResumeDestinationStore {
  static const String _boxName = 'tokigo_settings';
  static const String _key = 'resume_destination';

  /// Reads the saved location, or null when none is stored / storage fails.
  static Future<String?> read() async {
    try {
      final Box<Map> box = await _openBox();
      return box.get(_key)?['value']?.toString();
    } catch (_) {
      return null;
    }
  }

  /// Saves [location]; a null value clears the entry.
  static Future<void> write(String? location) async {
    try {
      final Box<Map> box = await _openBox();
      if (location == null) {
        await box.delete(_key);
      } else {
        await box.put(_key, <String, dynamic>{'value': location});
      }
    } catch (_) {
      // Persistence is best-effort; never block navigation on it.
    }
  }

  /// Clears the saved location (logout / first install).
  static Future<void> clear() => write(null);

  static Future<Box<Map>> _openBox() async {
    await StorageBootstrap.ensureReady();
    return Hive.isBoxOpen(_boxName)
        ? Hive.box<Map>(_boxName)
        : Hive.openBox<Map>(_boxName);
  }
}
