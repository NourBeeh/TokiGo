import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'offline_cache.dart';

/// The app's cache store, shared app-wide.
///
/// `main()` overrides this with the **on-disk Hive box** (opened once; the box
/// is a singleton keyed by its name, so a provider restart reuses it rather
/// than re-opening the file).
///
/// The default is an in-memory store: a host that forgot to override it (a
/// test, a tool) still runs — it just does not persist. Crashing a whole page
/// because a cache is missing would be a worse failure than a cache that
/// forgets.
final offlineCacheProvider = Provider<OfflineCache>((ref) {
  return MemoryOfflineCache();
});

/// Convenience override used by tests to inject a lightweight in-memory store.
final memoryOfflineCacheProvider = Provider<OfflineCache>((ref) {
  return MemoryOfflineCache();
});
