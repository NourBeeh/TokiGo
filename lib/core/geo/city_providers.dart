import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tokigo/core/geo/city_catalog.dart';
import 'package:tokigo/core/geo/city_detection_service.dart';
import 'package:tokigo/core/geo/city_selection.dart';
import 'package:tokigo/core/storage/offline_cache_providers.dart';
import 'package:tokigo/features/home/providers/home_providers.dart';

/// Fetches/caches the canonical city catalog.
final cityCatalogClientProvider = Provider<CityCatalogClient>((ref) {
  return CityCatalogClient(
    ref.watch(apiClientProvider),
    ref.watch(offlineCacheProvider),
  );
});

/// The catalog for the City Selection picker. Null means "not available yet";
/// the UI renders a loading or retry state rather than an empty list.
final cityCatalogProvider = FutureProvider<CityCatalog?>((ref) async {
  return ref.watch(cityCatalogClientProvider).load();
});

/// Background detection, wired to the shared GeoClient and the selection
/// controller. Nothing here prompts for permission or blocks the UI.
final cityDetectionServiceProvider = Provider<CityDetectionService>((ref) {
  return CityDetectionService(
    locate: () => ref.read(geoClientProvider).locate(),
    currentAutomatic: () => ref.read(citySelectionProvider).automatic?.city,
    onResolved: (CityOption city, CitySelectionSource source) =>
        ref.read(citySelectionProvider.notifier).setAutomatic(city, source: source),
  );
});
