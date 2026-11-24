import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tokigo/core/auth/auth_provider.dart';
import 'package:tokigo/core/events/events_tracker.dart';
import 'package:tokigo/core/geo/city_selection.dart';
import 'package:tokigo/core/geo/country_options.dart';
import 'package:tokigo/core/geo/currency.dart';
import 'package:tokigo/core/geo/geo_client.dart';
import 'package:tokigo/core/geo/location_permission_providers.dart'
    show geoRefreshProvider, locationAccessProvider;
import 'package:tokigo/core/geo/location_permission_service.dart';
import 'package:tokigo/core/geo/user_location.dart';
import 'package:tokigo/core/network/http_api_client.dart';
import 'package:tokigo/core/profile/profile_repository.dart';
import 'package:tokigo/core/repositories/contracts/home_repository.dart';
import 'package:tokigo/core/repositories/impl/home_repository_impl.dart';
import 'package:tokigo/core/storage/offline_cache_providers.dart';
import 'package:tokigo/core/storage/secure_token_storage_provider.dart';
import 'package:tokigo/features/home/application/hotel_image_cache.dart';
import 'package:tokigo/features/home/application/hotel_image_memory_cache.dart';
import 'package:tokigo/features/home/presentation/explore_feed_controller.dart';
import 'package:tokigo/features/home/presentation/nearby_stays_controller.dart';
import 'package:tokigo/shared/providers/locale_provider.dart';

final apiClientProvider = Provider((ref) => HttpApiClient());

class ManualCountryCodeController extends Notifier<String?> {
  static const String cacheKey = 'settings:manual-country-code';
  int _changeGeneration = 0;

  @override
  String? build() {
    _restore();
    return null;
  }

  Future<void> selectCountry(String countryCode) async {
    final normalized = countryCode.trim().toUpperCase();
    if (!isManualCountryCode(normalized)) {
      throw ArgumentError.value(
        countryCode,
        'countryCode',
        'Unsupported country.',
      );
    }

    final generation = ++_changeGeneration;
    final previous = state;
    ref.read(geoRefreshProvider.notifier).state = 0;
    state = normalized;
    try {
      await ref.read(offlineCacheProvider).write(cacheKey, <String, dynamic>{
        'value': normalized,
      });
    } catch (_) {
      if (generation == _changeGeneration) state = previous;
      rethrow;
    }

    // Best-effort server echo: the local choice is already applied and saved,
    // so a profile-network failure must never surface as "not saved".
    if (ref.read(authUserProvider) != null) {
      try {
        await ref
            .read(profileRepositoryProvider)
            .saveDetectedCountry(normalized, 'high');
      } catch (_) {
        // The device-level choice stands; the profile syncs on a later edit.
      }
    }
  }

  Future<void> _restore() async {
    final generation = _changeGeneration;
    try {
      final stored = await ref.read(offlineCacheProvider).read(cacheKey);
      if (generation != _changeGeneration) return;
      final value = stored?['value']?.toString();
      if (value != null && isManualCountryCode(value)) {
        state = value.toUpperCase();
      }
    } catch (_) {
      // An unavailable local cache leaves the country unset; the user can
      // still choose it again from the location prompt or Settings.
    }
  }
}

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  final cache = ref.watch(offlineCacheProvider);
  return HomeRepositoryImpl(client, offlineCache: cache);
});

/// Device-level country choice, used when GPS permission is declined or
/// unavailable. Only the ISO-2 code is persisted.
final manualCountryCodeProvider =
    NotifierProvider<ManualCountryCodeController, String?>(
      ManualCountryCodeController.new,
    );

/// Phase 1C — Profile/Geo/Events/AI-rerank clients. All reuse the shared
/// HTTP client + secure token storage (AdminHttpMixin-style auth headers).
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(
    ref.watch(apiClientProvider),
    ref.watch(secureTokenStorageProvider),
  );
});

/// Geo client for country resolution.
final geoClientProvider = Provider<GeoClient>((ref) {
  return GeoClient(ref.watch(apiClientProvider));
});

/// The traveller's coarse position, ONLY when location permission is already
/// granted (never prompts) and a fix is actually available. Null otherwise —
/// the honest fallback. Used solely to rank "Stays Near You" by real distance;
/// never persisted, never sent anywhere.
final userLocationProvider = FutureProvider<UserLocation?>((ref) async {
  final LocationAccess access = await ref.watch(locationAccessProvider.future);
  if (access != LocationAccess.granted) return null;
  final position = await ref.watch(geoClientProvider).currentPosition();
  if (position == null) return null;
  return UserLocation(
    latitude: position.latitude,
    longitude: position.longitude,
    accuracy: position.accuracy >= 0 ? position.accuracy : null,
  );
});

/// Phase 1C — Profile/Geo/Events/AI-rerank clients. All reuse the shared
/// HTTP client + secure token storage (AdminHttpMixin-style auth headers).
final geoCountryProvider = FutureProvider<GeoCountry?>((ref) {
  final int generation = ref.watch(geoRefreshProvider);
  final manualCountry = ref.watch(manualCountryCodeProvider);
  if (manualCountry != null && generation == 0) {
    return GeoCountry(
      countryCode: manualCountry,
      confidence: 'high',
      source: 'manual',
    );
  }
  return _resolveHomeCountry(ref, refresh: generation > 0);
});

Future<GeoCountry?> _resolveHomeCountry(Ref ref, {bool refresh = false}) async {
  final GeoClient client = ref.read(geoClientProvider);
  final detected = refresh
      ? await client.refreshCountry()
      : await client.resolveCountry();
  if (detected?.countryCode != null) return detected;
  final user = ref.read(authUserProvider);
  if (user == null) return null;
  final profile = await ref.read(profileRepositoryProvider).fetchProfile();
  final code = profile?.countryCode;
  if (code == null || code.isEmpty) return null;
  return GeoCountry(
    countryCode: code,
    confidence: profile?.countryConfidence,
    source: 'profile',
  );
}

/// Persisted GPS-detected country (if any). Writes the country code to the
/// offline cache ONLY when the user has not manually selected a country.
///
/// This provider is read by the router's entry-point logic to decide whether
/// to show the location explainer (no country) or the Home (country exists).
final geoDetectedCountryProvider = FutureProvider<GeoCountry?>((ref) async {
  // First, try the GPS-detected country (refs geoCountryProvider's logic).
  final gpsCountry = await ref.read(geoCountryProvider.future);
  if (gpsCountry != null) return gpsCountry;

  // Fallback: profile country (already stored on the server).
  final user = ref.read(authUserProvider);
  if (user == null) return null;
  final profile = await ref.read(profileRepositoryProvider).fetchProfile();
  final profileCountry = profile?.countryCode;
  if (profileCountry != null && profileCountry.isNotEmpty) {
    return GeoCountry(
      countryCode: profileCountry,
      confidence: profile?.countryConfidence,
      source: 'profile',
    );
  }
  return null;
});

/// Applies the GPS-detected country to disk (if the user has not manually
/// selected one). Called after location is granted.
Future<void> detectAndPersistCountry(Ref ref) async {
  final manualCountry = ref.read(manualCountryCodeProvider);
  if (manualCountry != null) return; // never overwrite manual selection

  final detected = await ref.read(geoCountryProvider.future);
  if (detected?.countryCode == null) return;

  try {
    await ref.read(offlineCacheProvider).write(
      'settings:geolocation-country-code',
      <String, dynamic>{'value': detected!.countryCode},
    );
  } catch (_) {
    // Persistence failure must not block the UI or override the manual choice.
  }
}

final eventsTrackerProvider = Provider<EventsTracker>((ref) {
  return EventsTracker(
    ref.watch(apiClientProvider),
    ref.watch(secureTokenStorageProvider),
  );
});

/// H3 — hotel image cache: bytes on disk (app cache dir), metadata in the
/// shared offline cache box. Byte caps and TTL live in [HotelImageCache].
final hotelImageCacheProvider = Provider<HotelImageCache>((ref) {
  final images = HotelImageCache(ref.watch(offlineCacheProvider));
  // One-time background housekeeping: move any pre-file-migration photo bytes
  // out of Hive and reclaim the box file. Never blocks the UI.
  unawaited(images.maintain());
  return images;
});

/// Scroll-fix 2026-09-08 — session memory layer in front of the disk cache:
/// ListView destroys off-screen cards, so a scroll-back re-reads Hive
/// asynchronously and flashes the shimmer. This synchronous layer renders
/// the photo in the same frame. Disk stays the cold-start truth; this is a
/// session-scoped fast path with the same LRU/TTL discipline.
final hotelImageMemoryCacheProvider = Provider<HotelImageMemoryCache>((ref) {
  return HotelImageMemoryCache();
});

/// Backend destination feed for the Explore Cities page. Home itself does NOT
/// use this: it renders the bundled Explore catalog directly. No snapshot, no
/// price validation, no composer, no recommendation rail.
final exploreFeedControllerProvider =
    StateNotifierProvider<ExploreFeedController, ExploreFeedState>((ref) {
      return ExploreFeedController(ref.watch(homeRepositoryProvider));
    });

/// Promotional Nearby Stays (R5): cached cards render immediately, the
/// background refresh replaces them, and a failure preserves them. The
/// location function is read (not watched) so a position change does not
/// rebuild the controller.
final nearbyStaysControllerProvider =
    StateNotifierProvider<NearbyStaysController, NearbyStaysState>((ref) {
  return NearbyStaysController(
    ref.watch(homeRepositoryProvider),
    location: () => ref.read(userLocationProvider.future),
    manualCity: () => ref.read(citySelectionProvider).manual?.city,
    automaticCity: () => ref.read(citySelectionProvider).automatic?.city,
    languageCode: () => ref.read(localeProvider).languageCode,
    currencyCode: () {
      final city = ref.read(citySelectionProvider).effective?.city;
      return effectiveCurrency(
        chosen: ref.read(currencyProvider),
        countryCode: city?.countryCode,
        cityCurrency: city?.currency,
      );
    },
  );
});

/// A one-shot request to bring a Home section into view.
///
/// Another page sets it immediately BEFORE going back to Home (for example the
/// results page's "Discover more"); Home consumes it once the feed is laid out
/// and clears it, so the scroll never replays on a later rebuild.
enum HomeScrollTarget { discover }

final homeScrollTargetProvider = StateProvider<HomeScrollTarget?>(
  (ref) => null,
);
