import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

/// One-time Hive bootstrap, kept off the startup critical path.
///
/// `Hive.init` only records the app's storage home — it never reads a box — but
/// resolving that home is a platform-channel round trip. Every storage user
/// awaits this future instead of calling `Hive.init` itself, so the channel is
/// hit once and no box can be opened before Hive knows where to put it.
///
/// Startup contract: nothing here opens a box. Opening the (potentially large)
/// offline cache box is deliberately deferred until after the first frame — see
/// `main.dart` and `DeferredOfflineCache`.
class StorageBootstrap {
  StorageBootstrap._();

  static Future<void>? _ready;

  /// Resolves the app's documents directory and initializes Hive.
  ///
  /// Safe to call from anywhere and from any number of providers: the work runs
  /// once and every caller shares the same future. A failed attempt is not
  /// cached, so a transient platform failure can be retried.
  static Future<void> ensureReady() {
    final existing = _ready;
    if (existing != null) return existing;

    final future = _initialize();
    _ready = future;
    // Do not pin a failure: a later caller may succeed (e.g. a test that mocks
    // the path provider after the first attempt).
    future.catchError((Object _) {
      if (identical(_ready, future)) _ready = null;
    });
    return future;
  }

  static Future<void> _initialize() async {
    final directory = await getApplicationDocumentsDirectory();
    Hive.init(directory.path);
  }
}
