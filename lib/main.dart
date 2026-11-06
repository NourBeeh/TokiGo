import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import 'app/app.dart';
import 'core/storage/deferred_offline_cache.dart';
import 'core/storage/hive_offline_cache.dart';
import 'core/storage/last_route_store.dart';
import 'core/storage/offline_cache.dart';
import 'core/storage/offline_cache_providers.dart';
import 'shared/providers/last_route_provider.dart';
import 'shared/providers/theme_provider.dart';

/// How long the launch path may wait for the disk cache before the first frame.
///
/// Two things need the same window, which is why it exists at all:
///
/// * the persisted **locale** is read during the first build — without a head
///   start an Arabic user would see a few English frames before the app flips
///   language;
/// * on this class of device the engine needs a moment to attach its surface
///   before it can encode the first frame. Pushing a frame earlier than that
///   aborts inside Impeller's GLES backend on Mali GPUs
///   (flutter/flutter#169203), so the first frame must not be produced from a
///   synchronous `main`.
///
/// The wait is bounded: a slow or corrupt box can never own the launch again.
const Duration _cacheHeadStart = Duration(milliseconds: 250);

/// Opens the on-disk cache. Never throws: a cache is an optimisation.
Future<OfflineCache?> _openCache() async {
  try {
    return await HiveOfflineCache.open(
      boxName: HiveOfflineCache.defaultBoxName,
    );
  } catch (error, stackTrace) {
    debugPrint('TokiGo: Hive offline cache unavailable — $error');
    if (kDebugMode) debugPrintStack(stackTrace: stackTrace);
    return null;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Enable edge-to-edge on Android/iOS and allow insets to be handled manually.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Decoded photos are held in native memory, outside the Dart heap. The
  // engine's default budget is 100MB — on a 911MB-RAM phone that alone is a
  // sixth of the device's memory and the difference between staying alive and
  // being reclaimed after browsing a photo-heavy list. A smaller budget costs
  // a re-decode when scrolling far back, which is cheaper than a restart.
  PaintingBinding.instance.imageCache.maximumSizeBytes = 48 << 20;

  final cache = DeferredOfflineCache();
  final stopwatch = Stopwatch()..start();
  final opening = _openCache();
  OfflineCache? openedCache;

  if (kDebugMode) {
    // A debug (JIT) launch can spend ten seconds or more in the box open, and
    // it does that on the UI isolate. If `runApp` has already been called, the
    // engine is asked for a frame while that block is in flight and Impeller's
    // GLES backend aborts on this class of device
    // (blit_pass_gles.cc, "Must be able to encode GL commands without error").
    // Debug therefore waits for storage exactly like it used to: a slower dev
    // launch, never a crash. Release keeps the bounded head start below —
    // there the same open is ~200ms.
    openedCache = await opening;
  } else {
    // Bounded head start (see [_cacheHeadStart]); storage never blocks the UI
    // beyond it.
    openedCache = await opening.timeout(_cacheHeadStart, onTimeout: () => null);
  }

  final ThemeMode initialThemeMode = await _readInitialThemeMode(openedCache);
  final String initialLocation = await _readInitialLocation();

  runApp(
    ProviderScope(
      overrides: <Override>[
        offlineCacheProvider.overrideWithValue(cache),
        themeModeProvider.overrideWith(
          () => ThemeModeController(initialMode: initialThemeMode),
        ),
        lastInitialRouteProvider.overrideWithValue(initialLocation),
      ],
      child: const TokiGoApp(),
    ),
  );

  // The box keeps opening in the background; when it lands, the in-memory
  // store is swapped for the disk one and anything written meanwhile is
  // replayed onto it.
  unawaited(
    opening.then((opened) async {
      if (opened == null) return;
      await cache.attach(opened);
      debugPrint(
        'TokiGo: offline cache ready in ${stopwatch.elapsedMilliseconds}ms',
      );
    }),
  );
}

/// Reads the location the traveller was on when the app closed.
///
/// Bounded like the cache head start: a slow or unavailable settings box
/// falls back to Home instead of stalling the first frame.
Future<String> _readInitialLocation() async {
  try {
    return await LastRouteStore.read()
            .timeout(const Duration(milliseconds: 250), onTimeout: () => null) ??
        '/';
  } catch (error, stackTrace) {
    debugPrint('TokiGo: last-route restore unavailable — $error');
    if (kDebugMode) debugPrintStack(stackTrace: stackTrace);
    return '/';
  }
}

Future<ThemeMode> _readInitialThemeMode(OfflineCache? cache) async {
  if (cache == null) return ThemeMode.dark;
  try {
    final stored = await cache.read(ThemeModeController.cacheKey);
    return ThemeModeController.fromStoredValue(stored?['value']);
  } catch (error, stackTrace) {
    debugPrint('TokiGo: theme preference unavailable — $error');
    if (kDebugMode) debugPrintStack(stackTrace: stackTrace);
    return ThemeMode.dark;
  }
}
