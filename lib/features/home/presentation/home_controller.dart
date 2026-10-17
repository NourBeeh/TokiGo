import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_section.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/core/network/user_facing_message.dart';
import 'package:tokigo/core/repositories/contracts/home_repository.dart';
import 'package:tokigo/features/home/application/home_live_validation_service.dart';
import 'package:tokigo/features/home/domain/home_composer.dart';
import 'package:tokigo/features/home/domain/home_greeting.dart';


enum HomeStatus { loading, success, empty, error, partial, developmentPreview }

class HomeState {
  final HomeStatus status;
  final List<HomeSection> sections;
  final List<HomeItem> recommendedHotels;
  final String? errorMessage;
  final bool isRefreshing;
  final bool fromCache;
  final HomeGreeting? greeting;

  const HomeState({
    this.status = HomeStatus.loading,
    this.sections = const [],
    this.recommendedHotels = const [],
    this.errorMessage,
    this.isRefreshing = false,
    this.fromCache = false,
    this.greeting,
  });

  HomeState copyWith({
    HomeStatus? status,
    List<HomeSection>? sections,
    List<HomeItem>? recommendedHotels,
    String? errorMessage,
    bool? isRefreshing,
    bool? fromCache,
    HomeGreeting? greeting,
  }) {
    return HomeState(
      status: status ?? this.status,
      sections: sections ?? this.sections,
      recommendedHotels: recommendedHotels ?? this.recommendedHotels,
      errorMessage: errorMessage ?? this.errorMessage,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      fromCache: fromCache ?? this.fromCache,
      greeting: greeting ?? this.greeting,
    );
  }
}

class HomeController extends StateNotifier<HomeState> {
  HomeController(
    this.repository, {
    this.audience = 'anon',
    HomeComposer composer = const HomeComposer(),
    Future<HomeCompositionContext> Function(List<HomeItem> recommendedHotels)?
        contextBuilder,
    HomeLiveValidationService? liveValidation,
  })  : _composer = composer,
        _contextBuilder = contextBuilder,
        _liveValidation = liveValidation,
        super(const HomeState()) {
    _startUp();
  }

  final HomeRepository repository;

  /// Snapshot scope for this controller instance: `'anon'` or `'user:<id>'`.
  ///
  /// Set by the provider layer from the auth state so login/logout rebuilds
  /// the controller with a different scope and a user's snapshot can never
  /// render on the anonymous surface (or vice versa).
  final String audience;

  /// Deterministic Home composer (Phase 1B). Never AI-driven.
  final HomeComposer _composer;

  /// Supplies the composition context (user state, local signals, display
  /// name) given the currently known recommended hotels. Null in legacy/test
  /// wiring → pure discovery composition, identical to Phase 1A behaviour.
  final Future<HomeCompositionContext> Function(List<HomeItem> recommendedHotels)?
      _contextBuilder;

  /// Phase 1D — optional background live-validation layer. Null keeps the
  /// controller exactly as Phase 1C (tests/legacy wiring).
  final HomeLiveValidationService? _liveValidation;

  /// Guards against duplicate validation jobs for the same snapshot (§15).
  bool _validationInFlight = false;

  /// Last context supplied by the builder — reused for greetings/recompose
  /// between network rounds.
  HomeCompositionContext? _lastContext;

  /// Phase 1A startup: render the persisted snapshot instantly, then refresh
  /// from the network in the background without ever blocking the UI.
  Future<void> _startUp() async {
    await restoreFromSnapshot();
    await load();
  }

  /// Reads the audience snapshot and, when present, publishes it immediately
  /// as success content. A missing or empty snapshot keeps the loading state
  /// so the normal network flow takes over.
  Future<void> restoreFromSnapshot() async {
    final snapshot = await repository.readHomeSnapshot(audience: audience);
    if (snapshot == null || snapshot.isEmpty) return;
    if (state.sections.isNotEmpty) return; // Already rendering content.
    state = state.copyWith(
      status: HomeStatus.success,
      sections: snapshot,
      fromCache: true,
      greeting: _greeting(),
    );
    // Phase 1D — cached Home is ALREADY on screen; re-check its bookable
    // products against the live providers in the background.
    _runLiveValidation();
  }

  /// Deterministic greeting for the current composition (Phase 1B).
  HomeGreeting _greeting() {
    return buildGreeting(_latestContext);
  }

  /// Best-known context snapshot for greeting purposes; falls back to the
  /// anonymous default until the provider builder has supplied one.
  HomeCompositionContext get _latestContext {
    return _lastContext ??
        const HomeCompositionContext(
          userState: HomeUserState.freshAnonymous,
        );
  }

  Future<void> load() async {
    if (state.sections.isEmpty) {
      state = state.copyWith(status: HomeStatus.loading, fromCache: false);
    } else {
      // Content already rendered (snapshot or previous load): refresh quietly
      // behind the UI instead of flipping back to a blocking loading state.
      state = state.copyWith(isRefreshing: true);
    }
    final result = await repository.getHomeSections();
    result.when(
      success: (sections) async {
        if (sections.isEmpty) {
          // Backend reachable but feed legitimately EMPTY (fake sections
          // removed — Home is Nuitee-only now). Drop the audience snapshot so
          // stale fake sections can never resurface from cache. The page now
          // renders the honest Nuitee-only state: the hotel rail when it
          // lands, or an explicit no-content state with a retry — never the
          // old empty skeleton preview (removed 2026-09-08: headings with no
          // data carry zero information and look unfinished).
          await repository.clearHomeSnapshot(audience: audience);
          state = state.copyWith(
            status: HomeStatus.success,
            sections: const [],
            isRefreshing: false,
            fromCache: false,
            greeting: _greeting(),
          );
          // If the rail is already on screen (parallel load finished
          // first), this is a no-op; otherwise the honest empty state
          // shows until loadRecommendedHotels lands.
          if (state.recommendedHotels.isEmpty) {
            state = state.copyWith(status: HomeStatus.empty);
          }
        } else {
          // Phase 1B: compose the dynamic Home from the network sections +
          // the current user context, then publish and persist it. Same
          // snapshot key/envelope as Phase 1A — only the content source grew.
          final composed = await _compose(sections);
          state = state.copyWith(
            status: HomeStatus.success,
            sections: composed,
            isRefreshing: false,
            fromCache: false,
            greeting: _greeting(),
          );
          // Persist the final network-confirmed sections as this audience's
          // snapshot so the next cold start renders instantly.
          await repository.saveHomeSnapshot(composed, audience: audience);
          // Phase 1D — fresh content just landed; validate its bookable
          // products against the live providers in the background.
          _runLiveValidation();
        }
      },
      failure: (error) async {
        if (state.sections.isEmpty) {
          final message = userFacingMessage(error, subject: 'home feed');
          state = state.copyWith(
            status: HomeStatus.error,
            errorMessage: message,
            isRefreshing: false,
            fromCache: false,
          );
        } else {
          // Cached content is on screen — a failed background refresh keeps
          // the last good content and NEVER turns the page into an error.
          state = state.copyWith(
            status: HomeStatus.partial,
            errorMessage: userFacingMessage(error, subject: 'home feed'),
            isRefreshing: false,
          );
        }
      },
    );
    // Fetch recommended hotels in parallel — non-blocking
    loadRecommendedHotels();
  }

  /// Runs the deterministic composer over [networkSections]. Without a
  /// context builder (legacy wiring/tests) the composition is the identity
  /// discovery order, exactly like Phase 1A.
  Future<List<HomeSection>> _compose(List<HomeSection> networkSections) async {
    final ctx = await (_contextBuilder?.call(state.recommendedHotels) ??
        Future.value(const HomeCompositionContext(
          userState: HomeUserState.freshAnonymous,
        )));
    _lastContext = ctx;
    final composition = await _composer.compose(_withSections(ctx, networkSections));
    return composition.sections;
  }

  /// Threads the context + network sections into one composition context,
  /// preserving every Phase 1C personalization field.
  HomeCompositionContext _withSections(
    HomeCompositionContext ctx,
    List<HomeSection> networkSections,
  ) {
    return HomeCompositionContext(
      userState: ctx.userState,
      displayName: ctx.displayName,
      backendSections: networkSections,
      recommendedHotels: ctx.recommendedHotels.isNotEmpty
          ? ctx.recommendedHotels
          : state.recommendedHotels,
      recentSearches: ctx.recentSearches,
      hasBagTrips: ctx.hasBagTrips,
      viewedTitles: ctx.viewedTitles,
      favoriteTitles: ctx.favoriteTitles,
      upcomingDestination: ctx.upcomingDestination,
      personalizationEnabled: ctx.personalizationEnabled,
      rankedCandidates: ctx.rankedCandidates,
      geoCountryCode: ctx.geoCountryCode,
    );
  }

  /// Recomposes the Home from the CURRENT state (used when a supplementary
  /// signal such as the recommended hotels lands after the sections did).
  Future<void> recompose() async {
    final builder = _contextBuilder;
    if (builder == null) return;
    if (state.sections.isEmpty) return;
    if (state.status != HomeStatus.success && state.status != HomeStatus.partial) {
      return;
    }
    // Rebuild sections from the last network content: the composed snapshot
    // already carries the composer tags; recompose uses the CURRENT state's
    // sections as the backend base only when they lack composer metadata.
    final hasComposerTags =
        state.sections.any((s) => s.metadata.containsKey('semanticId'));
    if (!hasComposerTags) return;
    final ctx = await builder(state.recommendedHotels);
    final base = _stripComposerTags(state.sections);
    final composed = await _composer.compose(_withSections(ctx, base));
    if (composed.sections.isEmpty) return;
    state = state.copyWith(sections: composed.sections);
  }

  /// Removes composer-added metadata so a recompose never stacks tags.
  List<HomeSection> _stripComposerTags(List<HomeSection> sections) {
    return sections
        .map((s) {
          if (!s.metadata.containsKey('semanticId') &&
              !s.metadata.containsKey('reason')) {
            return s;
          }
          final meta = Map<String, dynamic>.of(s.metadata)
            ..remove('semanticId')
            ..remove('reason');
          return HomeSection(
            id: s.id,
            title: s.title,
            subtitle: s.subtitle,
            layout: s.layout,
            items: s.items,
            isPaginated: s.isPaginated,
            metadata: meta,
          );
        })
        .toList();
  }

  // -- Phase 1D: background live product validation -----------------------

  /// H2 — price/availability-only refresh entry point.
  ///
  /// Called when the user returns to the Home surface (app foreground, or
  /// navigating back to the Home route). Revalidates the bookable products
  /// on screen against the live providers and applies fresh prices/expiry —
  /// WITHOUT reloading sections, hotel data or images. All the guards of
  /// [_runLiveValidation] apply (one job per snapshot, content on screen,
  /// never after dispose); on the Nuitee-only Home the sections list is
  /// empty, so this is a safe no-op until composed sections return (7B).
  void refreshPrices() => _runLiveValidation();

  /// Runs the background live validation exactly once per snapshot (§15):
  /// guard against duplicate jobs, never before content is on screen, and
  /// never write state after dispose.
  Future<void> _runLiveValidation() async {
    final service = _liveValidation;
    if (service == null) return;
    if (_validationInFlight) return; // One job per snapshot.
    if (!mounted) return;
    if (state.sections.isEmpty) return;
    if (state.status != HomeStatus.success && state.status != HomeStatus.partial) {
      return;
    }
    _validationInFlight = true;

    try {
      final results = await service.validate(state.sections);
      if (!mounted) return; // No state updates after dispose (§15).

      // Index results by product identity for fast application.
      final byId = <String, LiveValidationResult>{
        for (final r in results) r.productId: r,
      };
      if (byId.isEmpty) return; // Nothing worth acting on — Home untouched.

      // Replacement pipeline (§7): the SAME 1C context builder supplies the
      // personalized real candidates; deterministic ranking/AI rerank are
      // already applied inside it. No invented replacements — only
      // candidates that exist in the context.
      List<RankedCandidate>? replacements;
      final changed = results.any((r) => r.needsReplacement);
      if (changed) {
        final builder = _contextBuilder;
        if (builder != null) {
          final ctx = await builder(state.recommendedHotels);
          replacements = ctx.rankedCandidates;
        }
      }

      final applied = _applyValidationResults(byId, replacements);
      if (applied == null) return; // No visible change — keep state as-is.

      state = state.copyWith(sections: applied);
      // Persist the validated Home under the SAME snapshot key/envelope.
      await repository.saveHomeSnapshot(applied, audience: audience);
    } catch (_) {
      // Validation must NEVER surface as a Home error — the cached content
      // simply stays.
    } finally {
      _validationInFlight = false;
    }
  }

  /// Applies the validation results to the current sections:
  /// - valid → refresh price/expiry from the live response (keep);
  /// - needsReplacement → swap in the next real unused candidate of the
  ///   same type, or drop the item when none exists;
  /// - validationFailed/unsupported → keep the cached item untouched.
  /// Returns null when nothing visibly changed.
  List<HomeSection>? _applyValidationResults(
    Map<String, LiveValidationResult> byId,
    List<RankedCandidate>? replacements,
  ) {
    var changed = false;
    final usedCandidateIds = <String>{};

    // Pre-compute the identities already on screen so replacements never
    // duplicate visible products.
    final onScreenIds = <String>{};
    for (final s in state.sections) {
      for (final item in s.items) {
        final identity = item.metadata['providerOfferId']?.toString() ?? item.id;
        onScreenIds.add(identity);
      }
    }

    final newSections = <HomeSection>[];
    for (final section in state.sections) {
      final newItems = <HomeItem>[];
      for (final item in section.items) {
        final identity =
            item.metadata['providerOfferId']?.toString() ?? item.id;
        final result = byId[identity];

        if (result == null) {
          newItems.add(item); // Not validated (unsupported/discovery) — keep.
          continue;
        }

        if (result.status == LiveValidationStatus.valid) {
          newItems.add(_refreshLiveFields(item, result));
          changed = true;
          continue;
        }

        if (result.needsReplacement) {
          final replacement = _nextReplacement(
            item,
            replacements,
            onScreenIds,
            usedCandidateIds,
          );
          if (replacement != null) {
            newItems.add(replacement);
          }
          // No candidate → the invalid product is removed (never shown as
          // bookable truth). The section survives with its other items.
          changed = true;
          continue;
        }

        // validationFailed — keep the cached item; retry next refresh.
        newItems.add(item);
      }
      newSections.add(HomeSection(
        id: section.id,
        title: section.title,
        subtitle: section.subtitle,
        layout: section.layout,
        items: newItems,
        isPaginated: section.isPaginated,
        metadata: section.metadata,
      ));
    }
    return changed ? newSections : null;
  }

  /// Updates the price/expiry of a valid item from the live provider
  /// response. Identity and all other presentation fields stay untouched.
  HomeItem _refreshLiveFields(HomeItem item, LiveValidationResult result) {
    if (result.currentPrice == null &&
        result.currency == null &&
        result.expiresAt == null) {
      return item; // Nothing to refresh.
    }
    return HomeItem(
      id: item.id,
      type: item.type,
      title: item.title,
      subtitle: item.subtitle,
      description: item.description,
      imageUrl: item.imageUrl,
      price: result.currentPrice ?? item.price,
      currency: result.currency ?? item.currency,
      rating: item.rating,
      reviewCount: item.reviewCount,
      badge: item.badge,
      highlights: item.highlights,
      tags: item.tags,
      actionLabel: item.actionLabel,
      metadata: <String, dynamic>{
        ...item.metadata,
        if (result.expiresAt != null) 'validUntil': result.expiresAt,
        'validatedAt': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Picks the next REAL replacement candidate of the same card type that
  /// is neither on screen nor already used. Provenance (reason/source) from
  /// the 1C candidate is preserved in the item metadata (§16 provenance).
  HomeItem? _nextReplacement(
    HomeItem invalid,
    List<RankedCandidate>? replacements,
    Set<String> onScreenIds,
    Set<String> usedCandidateIds,
  ) {
    if (replacements == null || replacements.isEmpty) return null;
    for (final candidate in replacements) {
      if (candidate.id.isEmpty) continue;
      if (onScreenIds.contains(candidate.id)) continue;
      if (!usedCandidateIds.add(candidate.id)) continue;
      return HomeItem(
        id: candidate.id,
        type: invalid.type, // Same placement/type as the product it replaces.
        title: candidate.title,
        subtitle: candidate.subtitle,
        imageUrl: candidate.imageUrl,
        price: candidate.price,
        currency: candidate.currency,
        rating: candidate.rating,
        reviewCount: candidate.reviewCount,
        metadata: <String, dynamic>{
          'providerId': 'nuitee', // Candidates come from the R-4 flow.
          'providerOfferId': candidate.id,
          'reason': candidate.reason,
          'source': candidate.source,
          if (candidate.confidence != null) 'confidence': candidate.confidence,
          'replacedAt': DateTime.now().toIso8601String(),
        },
      );
    }
    return null;
  }

  Future<void> loadRecommendedHotels() async {
    final result = await repository.getRecommendedHotels();
    result.when(
      success: (hotels) {
        if (hotels.isNotEmpty) {
          state = state.copyWith(recommendedHotels: hotels);
          // The R-4 rail feeds the authenticated "Picked for You" section —
          // re-run the deterministic composition so the rail lands in place.
          //
          // Nuitee-only Home (empty feed): the rail IS the content. Whether
          // the empty-feed branch left us on the honest empty state or the
          // rail landed first, real hotels on screen = success.
          if (state.status == HomeStatus.developmentPreview ||
              state.status == HomeStatus.empty) {
            state = state.copyWith(
              status: HomeStatus.success,
              sections: const [],
            );
            return;
          }
          recompose();
        }
      },
      failure: (_) {
        // Silently ignore — recommended hotels are supplementary. If the
        // feed was empty too, the honest empty state stays on screen with
        // its retry affordance.
      },
    );
  }

  List<HomeSection> _developmentPreviewSections() {
    // Development preview — shown while the backend home feed is empty.
    //
    // Renders the approved card layouts as skeleton/loading UI ONLY. The
    // HomeItem entries carry NO fake travel data: empty titles, null images,
    // null prices, empty metadata. Cards detect these empty items via
    // `_isSkeletonItem` in HomeSectionWidget and render their loading state.
    HomeItem skeleton(HomeCardType type, int index) => HomeItem(
          id: 'dev-${type.name}-$index',
          type: type,
          title: '',
          subtitle: '',
          description: '',
          imageUrl: null,
          price: null,
          currency: null,
          metadata: const <String, dynamic>{},
        );

    return <HomeSection>[
      HomeSection(
        id: 'dev-flights',
        title: 'Flight Recommendations',
        subtitle: 'Recommended flights will appear here',
        layout: HomeSectionLayout.flightRecommendationList,
        items: <HomeItem>[
          skeleton(HomeCardType.flight, 0),
          skeleton(HomeCardType.flight, 1),
        ],
      ),
      HomeSection(
        id: 'dev-hotels',
        title: 'Hotels',
        subtitle: 'Top-rated stays will appear here',
        layout: HomeSectionLayout.horizontalPeek,
        items: <HomeItem>[
          skeleton(HomeCardType.hotel, 0),
          skeleton(HomeCardType.hotel, 1),
        ],
      ),
      HomeSection(
        id: 'dev-cars',
        title: 'Car Rentals',
        subtitle: 'Drive offers will appear here',
        layout: HomeSectionLayout.horizontalPeek,
        items: <HomeItem>[
          skeleton(HomeCardType.car, 0),
          skeleton(HomeCardType.car, 1),
        ],
      ),
      HomeSection(
        id: 'dev-packages',
        title: 'Tour Packages',
        subtitle: 'Curated journeys will appear here',
        layout: HomeSectionLayout.horizontalPeek,
        items: <HomeItem>[
          skeleton(HomeCardType.package, 0),
          skeleton(HomeCardType.package, 1),
        ],
      ),
      HomeSection(
        id: 'dev-deals',
        title: 'Hot Deals',
        subtitle: 'Limited-time offers will appear here',
        layout: HomeSectionLayout.verticalDealList,
        items: <HomeItem>[
          skeleton(HomeCardType.deal, 0),
          skeleton(HomeCardType.deal, 1),
        ],
      ),
      HomeSection(
        id: 'dev-destinations',
        title: 'Destinations',
        subtitle: 'Discover your next adventure',
        layout: HomeSectionLayout.horizontal,
        items: <HomeItem>[
          skeleton(HomeCardType.destination, 0),
          skeleton(HomeCardType.destination, 1),
        ],
      ),
    ];
  }

  // H1: the manual pull-to-refresh entry point is removed by product
  // decision — `HomePage` no longer wraps the feed in a RefreshIndicator.
  // The repository refresh hook stays intact (it is part of the
  // HomeRepository contract and used elsewhere); `load()` remains the
  // automatic startup/background refresh path, and H2 routes price and
  // availability updates through the live-validation service instead.
}
