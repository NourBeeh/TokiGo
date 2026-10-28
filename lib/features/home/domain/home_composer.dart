import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_section.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';

/// The three Home user states (Phase 1B — Dynamic Home).
enum HomeUserState {
  /// No local behavioral signals at all: no cached searches and no previous
  /// Home snapshot. Discovery-first composition.
  freshAnonymous,

  /// Anonymous but with local behavioral signals (previous searches and/or a
  /// persisted Home snapshot). Behavior-first composition with discovery
  /// fallback.
  returningAnonymous,

  /// Signed-in user. Personalized-ready composition; consumes only the data
  /// that exists today (profile display name, R-4 recommended hotels) and
  /// leaves explicit extension points for the later memory/AI phases.
  authenticated,
}

/// One decoded local search signal (from the existing Hive search caches).
class RecentSearchSignal {
  const RecentSearchSignal({
    required this.kind,
    required this.label,
    required this.at,
  });

  /// 'flight' | 'hotel' | 'car'.
  final String kind;

  /// Human label decoded from the cache key, e.g. 'Cairo → Paris'.
  final String label;

  final DateTime at;
}

/// Everything the composer is allowed to know. Deliberately closed: later
/// phases extend this context (profile, events, geo, memory) and the
/// composer rules grow — but the output contract stays `List<HomeSection>`
/// so the Card Engine and the Phase 1A snapshot never change shape.
class HomeCompositionContext {
  const HomeCompositionContext({
    required this.userState,
    this.displayName,
    this.backendSections = const [],
    this.recommendedHotels = const [],
    this.recentSearches = const [],
    this.hasBagTrips = false,
    // Phase 1C — personalization spine fields (all optional, 1B-compatible).
    this.viewedTitles = const [],
    this.favoriteTitles = const [],
    this.upcomingDestination,
    this.personalizationEnabled = true,
    this.rankedCandidates = const [],
    this.geoCountryCode,
  });

  final HomeUserState userState;

  /// Authenticated user's display name (auth only). Never hardcoded.
  final String? displayName;

  /// Sections from `GET /home/sections` (admin/seed content). The ONLY
  /// product source the composer may reorder/wrap — it never invents items.
  final List<HomeSection> backendSections;

  /// R-4 recommended hotels flow output (Nuitee-backed). Used as the
  /// "Picked for You" rail for authenticated users.
  final List<HomeItem> recommendedHotels;

  /// Decoded local search signals (read-only scan of existing Hive keys).
  final List<RecentSearchSignal> recentSearches;

  /// Whether the Bag currently holds trips (Continue planning is rendered by
  /// the existing Bag row; the composer only uses this to skip duplicates).
  final bool hasBagTrips;

  // -- Phase 1C: personalization spine -----------------------------------

  /// Server-derived viewed hotel titles (profile.derived.lastViewedHotel).
  final List<String> viewedTitles;

  /// Server-derived favorite hotel titles (profile.derived.favoriteHotels).
  final List<String> favoriteTitles;

  /// Upcoming trip destination (profile.derived / bag).
  final String? upcomingDestination;

  /// Personalization opt-out — false forces the discovery-safe composition.
  final bool personalizationEnabled;

  /// Deterministically ranked REAL candidates (RecommendationService).
  final List<RankedCandidate> rankedCandidates;

  /// Country-level geo context (ISO-2). Never finer.
  final String? geoCountryCode;
}

/// A real, ranked candidate the composer may surface as cards. Mirrors the
/// recommendation service output — the composer never mutates or invents
/// product data, it only decides placement.
class RankedCandidate {
  const RankedCandidate({
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

  /// §11 reason vocabulary: recent_search | recent_view | favorite |
  /// profile_preference | trip_context | geo | recommendation | discovery.
  final String reason;
  final String source;
  final double? confidence;
}

/// Result of a composition.
class HomeComposition {
  const HomeComposition({required this.sections});

  final List<HomeSection> sections;
}

/// Deterministic Home composer (Phase 1B).
///
/// Responsibilities: pick the Home state, choose + order sections, assign
/// section titles/subtitles, and tag every composed section with a
/// `semanticId` + `reason` in its metadata so later phases can localize
/// titles and explain placement WITHOUT changing the snapshot shape.
///
/// Hard rules:
/// - The composer NEVER invents products, prices, or destinations — real
///   items come only from [HomeCompositionContext.backendSections] or
///   [HomeCompositionContext.recommendedHotels].
/// - AI is never responsible for building UI. This class is pure and
///   deterministic: same context in, same sections out.
/// - Insufficient data always falls back to the full discovery order.
class HomeComposer {
  const HomeComposer();

  /// OWNER DECISION (2026-10-21): Home no longer leads with what the traveller
  /// has already seen — the "Based on what you viewed / recent activity" rail
  /// is hidden for now. It repeated cards the user had just left and pushed
  /// live discovery down the feed. The builder stays intact behind this switch
  /// (its safe-chip contract is still unit-tested), so a later phase can bring
  /// the rail back without rewriting it.
  static const bool showsViewedRail = false;

  Future<HomeComposition> compose(HomeCompositionContext ctx) async {
    final sections = _composeSync(ctx);
    return HomeComposition(sections: sections);
  }

  List<HomeSection> _composeSync(HomeCompositionContext ctx) {
    switch (ctx.userState) {
      case HomeUserState.freshAnonymous:
        return _freshAnonymous(ctx);
      case HomeUserState.returningAnonymous:
        return _returningAnonymous(ctx);
      case HomeUserState.authenticated:
        return _authenticated(ctx);
    }
  }

  // -- Fresh anonymous: discovery-first ---------------------------------

  List<HomeSection> _freshAnonymous(HomeCompositionContext ctx) {
    // The backend/seed order IS the discovery order; each section is tagged
    // so the reason stays explainable.
    return ctx.backendSections
        .map((s) => _tagged(s, semanticId: s.id, reason: 'discovery'))
        .toList();
  }

  // -- Returning anonymous: behavior-first, discovery fallback ----------

  List<HomeSection> _returningAnonymous(HomeCompositionContext ctx) {
    final out = <HomeSection>[];

    // 1) "Based on what you viewed" — built from LOCAL search signals only.
    //    Destination-type items keep this safe: no prices, no availability.
    //    Hidden for now (owner decision 2026-10-21); see [showsViewedRail].
    if (showsViewedRail) {
      final viewed = _basedOnViewedSection(ctx);
      if (viewed != null) out.add(viewed);
    }

    // 2) Discovery fallback: everything else in backend order.
    out.addAll(
      ctx.backendSections.map(
        (s) => _tagged(s, semanticId: s.id, reason: 'discovery'),
      ),
    );

    // Guard: insufficient data → pure discovery (never an empty Home).
    if (out.isEmpty) return _freshAnonymous(ctx);
    return out;
  }

  // -- Authenticated: personalized-ready ---------------------------------

  List<HomeSection> _authenticated(HomeCompositionContext ctx) {
    // Personalization opted out (or profile unavailable + disabled flag):
    // sensitive signals are ignored, discovery-safe composition applies.
    if (!ctx.personalizationEnabled) {
      return _authenticatedDiscoverySafe(ctx);
    }

    final out = <HomeSection>[];

    // 1) "Complete Your Trip" — trip context drives the rail first.
    final completeTrip = _completeTripSection(ctx);
    if (completeTrip != null) out.add(completeTrip);

    // 2) "Because you viewed X" — server-derived viewed titles (1C).
    final viewed = _becauseYouViewedSection(ctx);
    if (viewed != null) out.add(viewed);

    // 3) "Picked for You" — ranked REAL candidates when present (1C),
    //    otherwise the R-4 recommended hotels rail, unchanged source.
    final picked = _pickedForYouSection(ctx);
    if (picked != null) out.add(picked);

    // 4) "Based on your recent activity" — local signals (same safe builder
    //    as returning anonymous; the later memory phases replace the source).
    //    Hidden for now (owner decision 2026-10-21); see [showsViewedRail].
    if (showsViewedRail) {
      final activity = _basedOnViewedSection(ctx);
      if (activity != null) out.add(activity);
    }

    // 5) Deals (any backend deals content) before the rest of discovery.
    final deals = _firstBackendSectionOfType(ctx, HomeCardType.deal);
    if (deals != null) {
      out.add(_tagged(deals, semanticId: 'deals', reason: 'deals'));
    }

    // 6) Discovery fallback for everything else.
    out.addAll(
      ctx.backendSections
          .where((s) => s != deals)
          .map((s) => _tagged(s, semanticId: s.id, reason: 'discovery')),
    );

    // Guard: insufficient data → pure discovery.
    if (out.isEmpty) return _freshAnonymous(ctx);
    return out;
  }

  /// Discovery-safe composition when personalization is disabled: only
  /// non-sensitive rails (picked-for-you from the anonymous recommendation
  /// flow) + deals + discovery.
  List<HomeSection> _authenticatedDiscoverySafe(HomeCompositionContext ctx) {
    final out = <HomeSection>[];

    final picked = _pickedForYouSection(ctx);
    if (picked != null) out.add(picked);

    final deals = _firstBackendSectionOfType(ctx, HomeCardType.deal);
    if (deals != null) {
      out.add(_tagged(deals, semanticId: 'deals', reason: 'deals'));
    }
    out.addAll(
      ctx.backendSections
          .where((s) => s != deals)
          .map((s) => _tagged(s, semanticId: s.id, reason: 'discovery')),
    );

    if (out.isEmpty) return _freshAnonymous(ctx);
    return out;
  }

  /// "Complete Your Trip" — ranked candidates tied to the trip context.
  HomeSection? _completeTripSection(HomeCompositionContext ctx) {
    if (!ctx.hasBagTrips || ctx.rankedCandidates.isEmpty) return null;
    final tripCandidates = ctx.rankedCandidates
        .where((c) => c.reason == 'trip_context')
        .toList();
    if (tripCandidates.isEmpty) return null;
    return HomeSection(
      id: 'complete-your-trip',
      title: 'Complete Your Trip',
      subtitle: ctx.upcomingDestination != null
          ? 'For your trip to ${ctx.upcomingDestination}'
          : 'Finish what you started',
      layout: HomeSectionLayout.horizontalPeek,
      items: tripCandidates.map(_candidateToItem).toList(),
      // The English strings above stay as the fallback for non-UI readers; the
      // presentation layer resolves these KEYS in the active language.
      metadata: <String, dynamic>{
        ..._meta('complete-your-trip', 'trip_context'),
        'titleKey': 'completeYourTrip',
        'subtitleKey': ctx.upcomingDestination != null
            ? 'forYourTripTo'
            : 'finishWhatYouStarted',
        if (ctx.upcomingDestination != null)
          'destination': ctx.upcomingDestination,
      },
    );
  }

  /// "Because you viewed X" — server-derived viewed hotel titles.
  HomeSection? _becauseYouViewedSection(HomeCompositionContext ctx) {
    if (ctx.viewedTitles.isEmpty) return null;
    final items = <HomeItem>[];
    for (final title in ctx.viewedTitles.take(3)) {
      if (title.isEmpty) continue;
      items.add(
        HomeItem(
          id: 'viewed-${items.length}',
          type: HomeCardType.hotel,
          title: title,
          subtitle: 'Because you viewed this',
          metadata: _meta('viewed-${items.length}', 'recent_view'),
        ),
      );
    }
    if (items.isEmpty) return null;
    return HomeSection(
      id: 'because-you-viewed',
      title: 'Because you viewed ${ctx.viewedTitles.first}',
      subtitle: 'Picks related to what you saw',
      layout: HomeSectionLayout.horizontalPeek,
      items: items,
      metadata: <String, dynamic>{
        ..._meta('because-you-viewed', 'recent_view'),
        'titleKey': 'becauseYouViewed',
        'titleArg': ctx.viewedTitles.first,
        'subtitleKey': 'picksRelatedToWhatYouSaw',
      },
    );
  }

  /// "Picked for You" — deterministic ranked candidates (1C) when present,
  /// else the R-4 recommended hotels (1B behaviour, unchanged).
  HomeSection? _pickedForYouSection(HomeCompositionContext ctx) {
    if (ctx.rankedCandidates.isNotEmpty) {
      final top = ctx.rankedCandidates.take(8).toList();
      final leadReason = _reasonLabel(top.first.reason);
      return HomeSection(
        id: 'picked-for-you',
        title: 'Picked for You',
        subtitle: leadReason,
        layout: HomeSectionLayout.horizontalPeek,
        items: top.map(_candidateToItem).toList(),
        metadata: <String, dynamic>{
          ..._meta('picked-for-you', top.first.reason),
          'source': top.first.source,
          if (top.first.confidence != null) 'confidence': top.first.confidence,
          'titleKey': 'pickedForYou',
          'subtitleKey': _reasonKey(top.first.reason),
        },
      );
    }
    if (ctx.recommendedHotels.isNotEmpty) {
      return HomeSection(
        id: 'picked-for-you',
        title: 'Picked for You',
        subtitle: 'Based on your profile',
        layout: HomeSectionLayout.horizontalPeek,
        items: ctx.recommendedHotels,
        metadata: <String, dynamic>{
          ..._meta('picked-for-you', 'profile-recommendations'),
          'titleKey': 'pickedForYou',
          'subtitleKey': 'basedOnYourProfile',
        },
      );
    }
    return null;
  }

  /// The key of a recommendation reason, so the presentation layer can read
  /// it in the active language.
  static String _reasonKey(String reason) {
    switch (reason) {
      case 'recent_search':
        return 'basedOnRecentSearches';
      case 'recent_view':
        return 'basedOnWhatYouViewed';
      case 'favorite':
        return 'yourFavoritesFirst';
      case 'profile_preference':
        return 'matchedToYourPreferences';
      case 'trip_context':
        return 'forYourUpcomingTrip';
      case 'geo':
        return 'popularNearYou';
      default:
        return 'basedOnYourProfile';
    }
  }

  String _reasonLabel(String reason) {
    switch (reason) {
      case 'recent_search':
        return 'Based on your recent searches';
      case 'recent_view':
        return 'Based on what you viewed';
      case 'favorite':
        return 'Your favorites first';
      case 'profile_preference':
        return 'Matched to your preferences';
      case 'trip_context':
        return 'For your upcoming trip';
      case 'geo':
        return 'Popular near you';
      default:
        return 'Based on your profile';
    }
  }

  /// Converts a real ranked candidate to the standard Card Engine item.
  /// Carries reason/source/confidence in metadata (§11).
  HomeItem _candidateToItem(RankedCandidate c) {
    return HomeItem(
      id: c.id,
      type: HomeCardType.hotel,
      title: c.title,
      subtitle: c.subtitle,
      imageUrl: c.imageUrl,
      price: c.price,
      currency: c.currency,
      rating: c.rating,
      reviewCount: c.reviewCount,
      metadata: <String, dynamic>{
        'reason': c.reason,
        'source': c.source,
        if (c.confidence != null) 'confidence': c.confidence,
      },
    );
  }

  // -- Shared builders ----------------------------------------------------

  /// Builds the "Based on what you viewed / recent activity" section from
  /// local signals. Items are lightweight destination-style chips (no
  /// prices) so nothing untrusted is presented as bookable truth.
  HomeSection? _basedOnViewedSection(HomeCompositionContext ctx) {
    if (ctx.recentSearches.isEmpty) return null;
    final isAuth = ctx.userState == HomeUserState.authenticated;
    final seen = <String>{};
    final items = <HomeItem>[];
    for (final signal in ctx.recentSearches) {
      if (signal.label.isEmpty) continue;
      if (!seen.add(signal.label)) continue;
      items.add(
        HomeItem(
          id: 'recent-${signal.kind}-${items.length}',
          type: HomeCardType.destination,
          title: signal.label,
          subtitle: signal.kind == 'flight'
              ? 'Flight search'
              : signal.kind == 'hotel'
              ? 'Hotel search'
              : 'Car search',
          metadata: _meta('recent-search-${signal.kind}', 'local-behavior'),
        ),
      );
      if (items.length >= 6) break;
    }
    if (items.isEmpty) return null;
    return HomeSection(
      id: 'based-on-activity',
      title: isAuth
          ? 'Based on your recent activity'
          : 'Based on what you viewed',
      subtitle: 'From your recent searches',
      layout: HomeSectionLayout.horizontal,
      items: items,
      metadata: <String, dynamic>{
        ..._meta('based-on-activity', 'local-behavior'),
        'titleKey': isAuth ? 'basedOnRecentActivity' : 'basedOnWhatYouViewed',
        'subtitleKey': 'basedOnRecentSearches',
      },
    );
  }

  HomeSection? _firstBackendSectionOfType(
    HomeCompositionContext ctx,
    HomeCardType type,
  ) {
    for (final s in ctx.backendSections) {
      final id = s.id.toLowerCase();
      // Content-based match (all items of the type) or well-known section id
      // (the seeded 'deals' section before its cards load).
      if ((s.items.isNotEmpty && s.items.every((i) => i.type == type)) ||
          id == type.name ||
          id == '${type.name}s') {
        return s;
      }
    }
    return null;
  }

  Map<String, dynamic> _meta(String semanticId, String reason) =>
      <String, dynamic>{'semanticId': semanticId, 'reason': reason};

  /// Returns a copy of [s] carrying the composer metadata. Original section
  /// metadata is preserved (merged, composer keys win).
  HomeSection _tagged(
    HomeSection s, {
    required String semanticId,
    required String reason,
  }) {
    return HomeSection(
      id: s.id,
      title: s.title,
      subtitle: s.subtitle,
      layout: s.layout,
      items: s.items,
      isPaginated: s.isPaginated,
      metadata: <String, dynamic>{...s.metadata, ..._meta(semanticId, reason)},
    );
  }
}
