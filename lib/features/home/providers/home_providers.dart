import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tokigo/core/auth/auth_provider.dart';
import 'package:tokigo/core/events/events_tracker.dart';
import 'package:tokigo/core/geo/country_options.dart';
import 'package:tokigo/core/geo/geo_client.dart';
import 'package:tokigo/core/network/http_api_client.dart';
import 'package:tokigo/core/profile/profile_repository.dart';
import 'package:tokigo/core/repositories/impl/home_repository_impl.dart';
import 'package:tokigo/core/storage/offline_cache_providers.dart';
import 'package:tokigo/core/storage/secure_token_storage_provider.dart';
import 'package:tokigo/features/bag/application/bag_controller.dart';
import 'package:tokigo/features/booking/application/services/offer_revalidation_service.dart';
import 'package:tokigo/features/home/application/home_live_validation_service.dart';
import 'package:tokigo/features/home/application/hotel_image_cache.dart';
import 'package:tokigo/features/home/application/hotel_image_memory_cache.dart';
import 'package:tokigo/features/home/application/home_personalization_orchestrator.dart';
import 'package:tokigo/features/home/application/local_behavior_store.dart';
import 'package:tokigo/features/home/application/recommendation_service.dart';
import 'package:tokigo/features/home/domain/home_composer.dart';
import 'package:tokigo/features/home/domain/personalization_context.dart';
import 'package:tokigo/features/home/presentation/home_controller.dart';

final apiClientProvider = Provider((ref) => HttpApiClient());

final homeRepositoryProvider = Provider((ref) {
  final client = ref.watch(apiClientProvider);
  final cache = ref.watch(offlineCacheProvider);
  return HomeRepositoryImpl(client, offlineCache: cache);
});

/// Read-only local behavior signals (Phase 1B). Backed by the shared offline
/// cache; scans existing search keys, never writes.
final localBehaviorStoreProvider = Provider<LocalBehaviorStore>((ref) {
  return LocalBehaviorStore(ref.watch(offlineCacheProvider));
});

/// Phase 1C — Profile/Geo/Events/AI-rerank clients. All reuse the shared
/// HTTP client + secure token storage (AdminHttpMixin-style auth headers).
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(
    ref.watch(apiClientProvider),
    ref.watch(secureTokenStorageProvider),
  );
});

final geoClientProvider = Provider<GeoClient>((ref) {
  return GeoClient(ref.watch(apiClientProvider));
});

/// Incremented when the traveller grants location access (Phase 3), so the
/// country is re-resolved with GPS instead of the IP fallback. An unchanged
/// counter keeps the session-scoped result — no repeated lookups.
final geoRefreshProvider = StateProvider<int>((ref) => 0);

/// Device-level country choice, used when GPS permission is declined or
/// unavailable. Only the ISO-2 code is persisted.
final manualCountryCodeProvider =
    NotifierProvider<ManualCountryCodeController, String?>(
      ManualCountryCodeController.new,
    );

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

/// Country-level travel context shared by AI and search surfaces. This client
/// never raises the OS permission dialog (the Home explainer does) and
/// discards precise coordinates after the single lookup.
///
/// When [geoRefreshProvider] moves (the traveller granted location access),
/// the session-scoped geo result is discarded and resolved again with GPS.
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

final eventsTrackerProvider = Provider<EventsTracker>((ref) {
  return EventsTracker(
    ref.watch(apiClientProvider),
    ref.watch(secureTokenStorageProvider),
  );
});

/// Phase 1C — deterministic candidate ranking (no ML, no AI).
final recommendationServiceProvider = Provider<RecommendationService>((ref) {
  return const RecommendationService();
});

/// Phase 1C — parallel personalization orchestrator (profile/geo/behavior).
final homePersonalizationOrchestratorProvider =
    Provider<HomePersonalizationOrchestrator>((ref) {
      return HomePersonalizationOrchestrator(
        profileRepository: ref.watch(profileRepositoryProvider),
        geoClient: ref.watch(geoClientProvider),
        behaviorStore: ref.watch(localBehaviorStoreProvider),
        hasTripsResolver: (user) async {
          return ref.read(bagControllerProvider).currentTrips.isNotEmpty;
        },
      );
    });

/// Phase 1D — background live product validation for the Home snapshot.
/// Wraps the EXISTING `/offers/revalidate` pipeline (the same one booking
/// uses); no parallel revalidation architecture.
final homeLiveValidationServiceProvider = Provider<HomeLiveValidationService>((
  ref,
) {
  return HomeLiveValidationService(ref.watch(offerRevalidationServiceProvider));
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

/// Home is scoped to the caller's identity: anonymous users share the
/// `'anon'` snapshot while each authenticated user gets `'<userId>'`.
///
/// Watching [authUserProvider] means login/logout automatically rebuilds
/// the controller with the new scope — a user's snapshot can never render on
/// the anonymous surface (or another user's surface) and vice versa.
///
/// The context builder runs the personalization spine in the background —
/// profile ‖ geo ‖ local behavior ‖ trips, followed by deterministic ranking.
/// Opening Home never triggers an AI call.
final homeControllerProvider = StateNotifierProvider<HomeController, HomeState>(
  (ref) {
    final repo = ref.watch(homeRepositoryProvider);
    final user = ref.watch(authUserProvider);
    final orchestrator = ref.watch(homePersonalizationOrchestratorProvider);
    final recommendationService = ref.watch(recommendationServiceProvider);

    return HomeController(
      repo,
      audience: HomeRepositoryImpl.homeAudienceFor(user?.id),
      liveValidation: ref.watch(homeLiveValidationServiceProvider),
      // Read (not watch): a country change must NOT rebuild the controller and
      // replay the Home startup. Resolved per request instead.
      countryCode: () {
        final manual = ref.read(manualCountryCodeProvider);
        final geo = ref.read(geoCountryProvider).asData?.value?.countryCode;
        final code = (manual ?? geo)?.trim().toUpperCase();
        return (code != null && code.length == 2) ? code : null;
      },
      contextBuilder: (recommendedHotels) async {
        // 1) R-4 recommended hotels → deterministic candidates (real data
        //    only; the AI is never a product source).
        final baseCandidates = recommendedHotels.isEmpty
            ? const <PersonalizationCandidate>[]
            : recommendedHotels
                  .map(
                    (h) => PersonalizationCandidate(
                      id: h.id,
                      title: h.title,
                      subtitle: h.subtitle,
                      imageUrl: h.imageUrl,
                      price: h.price,
                      currency: h.currency,
                      rating: h.rating,
                      reviewCount: h.reviewCount,
                    ),
                  )
                  .toList();

        // 2) Parallel spine: profile ‖ geo ‖ behavior ‖ trips (each silent).
        final personalized = await orchestrator.build(
          user: user,
          candidates: baseCandidates,
        );

        // 3) Deterministic ranking on top (§6 priorities).
        final ranked = recommendationService.rank(baseCandidates, personalized);

        // 4) Compose the final context consumed by the deterministic composer.
        return HomeCompositionContext(
          userState: personalized.userState,
          displayName: personalized.displayName,
          recommendedHotels: recommendedHotels,
          recentSearches: personalized.recentSearches,
          hasBagTrips: personalized.hasTrips,
          viewedTitles: personalized.viewedTitles,
          favoriteTitles: personalized.favoriteTitles,
          upcomingDestination: personalized.upcomingDestination,
          personalizationEnabled: personalized.personalizationEnabled,
          rankedCandidates: ranked
              .map(
                (c) => RankedCandidate(
                  id: c.id,
                  title: c.title,
                  subtitle: c.subtitle,
                  imageUrl: c.imageUrl,
                  price: c.price,
                  currency: c.currency,
                  rating: c.rating,
                  reviewCount: c.reviewCount,
                  reason: c.reason,
                  source: c.source,
                  confidence: c.confidence,
                ),
              )
              .toList(),
          geoCountryCode: personalized.geoCountryCode,
        );
      },
    );
  },
);

/// A one-shot request to bring a Home section into view.
///
/// Another page sets it immediately BEFORE going back to Home (for example the
/// results page's "Discover more"); Home consumes it once the feed is laid out
/// and clears it, so the scroll never replays on a later rebuild.
enum HomeScrollTarget { discover }

final homeScrollTargetProvider = StateProvider<HomeScrollTarget?>(
  (ref) => null,
);
