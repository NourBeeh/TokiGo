import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tokigo/core/ai/ai_rerank_client.dart';
import 'package:tokigo/core/auth/auth_provider.dart';
import 'package:tokigo/core/events/events_tracker.dart';
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

final eventsTrackerProvider = Provider<EventsTracker>((ref) {
  return EventsTracker(
    ref.watch(apiClientProvider),
    ref.watch(secureTokenStorageProvider),
  );
});

final aiRerankClientProvider = Provider<AiRerankClient>((ref) {
  return AiRerankClient(
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
final homeLiveValidationServiceProvider =
    Provider<HomeLiveValidationService>((ref) {
  return HomeLiveValidationService(
    ref.watch(offerRevalidationServiceProvider),
  );
});

/// H3 — Hive-backed hotel image cache (LRU 30, TTL 7 days) on the shared
/// offline cache box. Bytes only; P2 decode sizing lives in the widget.
final hotelImageCacheProvider = Provider<HotelImageCache>((ref) {
  return HotelImageCache(ref.watch(offlineCacheProvider));
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
/// Phase 1C: the context builder now runs the full personalization spine in
/// the background — profile ‖ geo ‖ local behavior ‖ trips, then the
/// deterministic recommendation ranking, then an OPTIONAL AI rerank that can
/// only reorder the already-ranked real candidates. Every failure degrades
/// silently to discovery/behavioral-safe composition.
final homeControllerProvider = StateNotifierProvider<HomeController, HomeState>((
  ref,
) {
  final repo = ref.watch(homeRepositoryProvider);
  final user = ref.watch(authUserProvider);
  final orchestrator = ref.watch(homePersonalizationOrchestratorProvider);
  final recommendationService = ref.watch(recommendationServiceProvider);
  final rerankClient = ref.watch(aiRerankClientProvider);

  return HomeController(
    repo,
    audience: HomeRepositoryImpl.homeAudienceFor(user?.id),
    liveValidation: ref.watch(homeLiveValidationServiceProvider),
    contextBuilder: (recommendedHotels) async {
      // 1) R-4 recommended hotels → deterministic candidates (real data
      //    only; the AI is never a product source).
      final baseCandidates = recommendedHotels.isEmpty
          ? const <PersonalizationCandidate>[]
          : recommendedHotels
              .map((h) => PersonalizationCandidate(
                    id: h.id,
                    title: h.title,
                    subtitle: h.subtitle,
                    imageUrl: h.imageUrl,
                    price: h.price,
                    currency: h.currency,
                    rating: h.rating,
                    reviewCount: h.reviewCount,
                  ))
              .toList();

      // 2) Parallel spine: profile ‖ geo ‖ behavior ‖ trips (each silent).
      final personalized =
          await orchestrator.build(user: user, candidates: baseCandidates);

      // 3) Deterministic ranking on top (§6 priorities).
      final ranked =
          recommendationService.rank(baseCandidates, personalized);

      // 4) OPTIONAL AI rerank — only for authenticated users with
      //    personalization enabled; never blocks, never invents (client
      //    validates ids against the known set).
      var finalRanked = ranked;
      if (user != null && personalized.personalizationEnabled && ranked.isNotEmpty) {
        final rerank = await rerankClient.rerank(
          context: personalized.safeAiContext(),
          candidates: ranked
              .map((c) => AiRerankCandidate(
                    id: c.id,
                    title: c.title,
                    price: c.price,
                  ))
              .take(12)
              .toList(),
          allowedReasons: const [
            'recent_search',
            'recent_view',
            'favorite',
            'profile_preference',
            'trip_context',
            'geo',
            'recommendation',
            'discovery',
          ],
        );
        if (!rerank.fallback) {
          final byId = {for (final c in ranked) c.id: c};
          final ordered = rerank.rankedCandidateIds
              .map((id) => byId[id])
              .whereType<PersonalizationCandidate>()
              .toList();
          if (ordered.isNotEmpty) {
            finalRanked = ordered;
          }
        }
      }

      // 5) Compose the final context consumed by the deterministic composer.
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
        rankedCandidates: finalRanked
            .map((c) => RankedCandidate(
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
                ))
            .toList(),
        geoCountryCode: personalized.geoCountryCode,
      );
    },
  );
});
