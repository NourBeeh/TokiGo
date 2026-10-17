import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import 'app/app.dart';
import 'core/storage/hive_offline_cache.dart';
import 'core/storage/offline_cache_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Enable edge-to-edge on Android/iOS and allow insets to be handled manually
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Initialize Hive and open the offline cache box
  final offlineCache = await HiveOfflineCache.open(boxName: HiveOfflineCache.defaultBoxName);

  runApp(
    ProviderScope(
      overrides: [
        offlineCacheProvider.overrideWithValue(offlineCache),
      ],
      child: const TokiGoApp(),
    ),
  );
}
