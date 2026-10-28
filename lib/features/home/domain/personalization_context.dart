import 'package:tokigo/core/memory/derived_preference_profile.dart';
import 'package:tokigo/core/memory/explicit_preference_signal.dart';
import 'package:tokigo/core/profile/profile_repository.dart';
import 'package:tokigo/features/home/domain/home_composer.dart';

/// Unified personalization context (Phase 1C).
///
/// Everything the composer/orchestrator needs in one serializable value:
/// auth state, profile signals, geo (country only), local behavior, viewed/
/// favorite titles, trip context, and the ranked real candidates. SAFETY:
/// the context intentionally carries NO tokens, NO payment data, NO precise
/// GPS — [safeAiContext] is the single funnel that decides what an AI call
/// may ever see.
class PersonalizationContext {
  const PersonalizationContext({
    required this.userState,
    this.displayName,
    this.profile,
    this.geoCountryCode,
    this.recentSearches = const [],
    this.viewedTitles = const [],
    this.favoriteTitles = const [],
    this.hasTrips = false,
    this.upcomingDestination,
    this.personalizationEnabled = true,
    this.rankedCandidates = const [],
    this.derivedPreferences,
    this.explicitPreferences,
  });

  final HomeUserState userState;

  /// Authenticated display name (auth only). Never hardcoded.
  final String? displayName;

  /// Backend profile view (null for guests / on profile failure).
  final ProfileView? profile;

  /// Country-level geo (ISO-2) — nothing finer is ever stored or sent.
  final String? geoCountryCode;

  /// Local recent search signals (1B LocalBehaviorStore).
  final List<RecentSearchSignal> recentSearches;

  /// Derived viewed hotel titles (profile.derived + local fallback).
  final List<String> viewedTitles;

  /// Derived favorite hotel titles (profile.derived).
  final List<String> favoriteTitles;

  /// Bag context: are there current trips?
  final bool hasTrips;

  /// Upcoming destination (profile.derived / bag).
  final String? upcomingDestination;

  /// The user's personalization opt-out; false → discovery-safe composition.
  final bool personalizationEnabled;

  /// Real, ranked candidates from the recommendation service. NEVER invented.
  final List<PersonalizationCandidate> rankedCandidates;

  /// Phase 2B — computed behavioral preference profile from the memory
  /// spine (arrives on `GET /profile/me`). Null for guests / older
  /// responses / derivation failures — consumers must treat null as "no
  /// additional signal", never as a negative preference.
  final DerivedPreferenceProfile? derivedPreferences;

  /// PH-7 — explicit AI-conversation preference signal, ranked ABOVE the
  /// derived (behavioural) layer and ABOVE explicit profile prefs. Null for
  /// guests / opt-out / no facts / older backends. Deliberately NOT part of
  /// [safeAiContext] — the `/ai/rerank` whitelist must stay unchanged.
  final ExplicitPreferenceSignal? explicitPreferences;

  /// Minimal SAFE subset for AI calls. This is the ONLY shape that may reach
  /// an AI prompt — no PII beyond what the whitelist allows, no GPS finer
  /// than country, no tokens, no internal objects.
  Map<String, dynamic> safeAiContext() {
    if (!personalizationEnabled) {
      return <String, dynamic>{'userState': userState.name};
    }
    return <String, dynamic>{
      'userState': userState.name,
      if (geoCountryCode != null) 'countryCode': geoCountryCode,
      if (recentSearches.isNotEmpty)
        'recentSearchLabels': recentSearches
            .map((s) => s.label)
            .take(3)
            .toList(),
      if (viewedTitles.isNotEmpty)
        'viewedTitles': viewedTitles.take(3).toList(),
      if (favoriteTitles.isNotEmpty)
        'favoriteTitles': favoriteTitles.take(3).toList(),
      if (upcomingDestination != null)
        'upcomingDestination': upcomingDestination,
      if (profile?.topDestinations.isNotEmpty == true)
        'topDestinations': profile!.topDestinations.take(3).toList(),
      if (profile?.preferences['preferredStars'] != null)
        'preferredStars': profile!.preferences['preferredStars'],
      if (profile?.preferences['budgetMax'] != null)
        'budgetMax': profile!.preferences['budgetMax'],
      // Phase 2B — derived behavioral preferences (LABELS + budget bounds
      // only; never raw memory values, payloads, or provenance internals).
      if (derivedPreferences?.topDestinations.isNotEmpty == true)
        'derivedTopDestinations': derivedPreferences!.topDestinations
            .map((d) => d.name)
            .take(3)
            .toList(),
      if (derivedPreferences?.budgetRange?.max != null)
        'derivedBudgetMax': derivedPreferences!.budgetRange!.max,
      'hasTrips': hasTrips,
    };
  }

  /// Debug/audit view of the context (serializable, safe to log).
  Map<String, dynamic> toDebugMap() {
    return <String, dynamic>{
      'userState': userState.name,
      'hasDisplayName': displayName != null,
      'hasProfile': profile != null,
      'personalizationEnabled': personalizationEnabled,
      'geoCountryCode': geoCountryCode,
      'recentSearchCount': recentSearches.length,
      'viewedCount': viewedTitles.length,
      'favoriteCount': favoriteTitles.length,
      'hasTrips': hasTrips,
      'upcomingDestination': upcomingDestination,
      'rankedCandidateCount': rankedCandidates.length,
      'derivedTopDestinationCount':
          derivedPreferences?.topDestinations.length ?? 0,
    };
  }
}

/// One REAL candidate flowing into the composer (recommendation service
/// output). Carries only the fields the existing Card Engine already renders.
class PersonalizationCandidate {
  const PersonalizationCandidate({
    required this.id,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.price,
    this.currency,
    this.rating,
    this.reviewCount,
    this.reason = 'recommendation',
    this.source = 'recommendation',
    this.confidence,
  });

  final String id;
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final double? price;
  final String? currency;
  final double? rating;
  final int? reviewCount;

  /// Why this candidate surfaced (§11 dynamic section reasons vocabulary).
  final String reason;

  /// Where it came from (recommendation/local/discovery).
  final String source;
  final double? confidence;
}
