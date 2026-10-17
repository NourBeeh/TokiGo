import 'package:tokigo/core/auth/user_model.dart';
import 'package:tokigo/core/geo/geo_client.dart';
import 'package:tokigo/core/profile/profile_repository.dart';
import 'package:tokigo/features/home/application/local_behavior_store.dart';
import 'package:tokigo/features/home/domain/home_composer.dart';
import 'package:tokigo/features/home/domain/personalization_context.dart';

/// Builds the [PersonalizationContext] from every source in PARALLEL
/// (Phase 1C, §15): profile, geo, local behavior, recommendations inputs.
///
/// Hard guarantees:
/// - The snapshot/instant render NEVER waits for any of these (the caller
///   runs this only as a background refresh).
/// - Every source failure is silent: the context is built from whatever
///   succeeded, and Home continues (worst case = pure discovery context).
/// - Nothing sensitive is stored: country-level geo only, no tokens, no
///   precise coordinates.
class HomePersonalizationOrchestrator {
  HomePersonalizationOrchestrator({
    required ProfileRepository profileRepository,
    required GeoClient geoClient,
    required LocalBehaviorStore behaviorStore,
    required Future<bool> Function(AuthUser? user) hasTripsResolver,
  })  : _profileRepository = profileRepository,
        _geoClient = geoClient,
        _behaviorStore = behaviorStore,
        _hasTripsResolver = hasTripsResolver;

  final ProfileRepository _profileRepository;
  final GeoClient _geoClient;
  final LocalBehaviorStore _behaviorStore;
  final Future<bool> Function(AuthUser? user) _hasTripsResolver;

  /// Resolves the full personalization context for [user] (null = guest).
  Future<PersonalizationContext> build({
    AuthUser? user,
    List<PersonalizationCandidate> candidates = const [],
  }) async {
    // Everything runs in parallel; each branch has its own silent fallback.
    final results = await Future.wait<dynamic>([
      _profileBranch(user),
      _geoBranch(),
      _behaviorBranch(),
      _tripsBranch(user),
    ]);

    final profile = results[0] as ProfileView?;
    final geo = results[1] as GeoCountry?;
    final behavior = results[2] as _BehaviorSnapshot?;
    final hasTrips = results[3] as bool? ?? false;

    final userState = user != null
        ? HomeUserState.authenticated
        : (behavior?.hasFootprint ?? false)
            ? HomeUserState.returningAnonymous
            : HomeUserState.freshAnonymous;

    return PersonalizationContext(
      userState: userState,
      displayName: user?.displayName,
      profile: profile,
      geoCountryCode: geo?.countryCode,
      recentSearches: behavior?.recentSearches ?? const [],
      viewedTitles: _viewedTitles(profile, behavior),
      favoriteTitles: profile?.favoriteHotelTitles ?? const [],
      hasTrips: hasTrips,
      upcomingDestination: profile?.upcomingDestination,
      personalizationEnabled: profile?.personalizationEnabled ?? true,
      rankedCandidates: candidates,
      // Phase 2B — the computed behavioral preference profile rides the
      // SAME profile fetch (zero additional network calls, §23).
      derivedPreferences: profile?.derivedPreferences,
    );
  }

  Future<ProfileView?> _profileBranch(AuthUser? user) async {
    if (user == null) return null; // Guests have no server profile.
    try {
      return await _profileRepository.fetchProfile();
    } catch (_) {
      return null; // Profile failure → local data continues.
    }
  }

  Future<GeoCountry?> _geoBranch() async {
    try {
      return await _geoClient.resolveCountry();
    } catch (_) {
      return null; // Geo failure → continue without geo.
    }
  }

  Future<_BehaviorSnapshot?> _behaviorBranch() async {
    try {
      final footprint = await _behaviorStore.hasLocalFootprint();
      final searches =
          footprint ? await _behaviorStore.recentSearches() : const <RecentSearchSignal>[];
      return _BehaviorSnapshot(hasFootprint: footprint, recentSearches: searches);
    } catch (_) {
      return null; // Local store failure → fresh-anonymous behavior.
    }
  }

  Future<bool> _tripsBranch(AuthUser? user) async {
    try {
      return await _hasTripsResolver(user);
    } catch (_) {
      return false;
    }
  }

  /// Viewed titles: server profile first (auth), local search labels are NOT
  /// views — viewedTitles stays a server-derived signal for now.
  List<String> _viewedTitles(ProfileView? profile, _BehaviorSnapshot? behavior) {
    final fromProfile = profile?.lastViewedHotelTitle;
    if (fromProfile != null && fromProfile.isNotEmpty) return [fromProfile];
    return const [];
  }
}

class _BehaviorSnapshot {
  _BehaviorSnapshot({required this.hasFootprint, required this.recentSearches});
  final bool hasFootprint;
  final List<RecentSearchSignal> recentSearches;
}
