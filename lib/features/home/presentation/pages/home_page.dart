import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/app/widgets/app_chrome.dart';
import 'package:tokigo/app/widgets/home_nav_buttons.dart';
import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/ui/app_message_state.dart';
import 'package:tokigo/core/widgets/section_header.dart';
import 'package:tokigo/core/widgets/shimmer.dart';
import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_section.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/features/home/domain/home_action.dart';
import 'package:tokigo/features/home/domain/explore_home_section.dart';
import 'package:tokigo/features/home/presentation/home_card_dimensions.dart';
import 'package:tokigo/features/home/presentation/home_controller.dart';
import 'package:tokigo/features/home/presentation/home_design_tokens.dart';
import 'package:tokigo/features/home/presentation/widgets/home_top_bar.dart';
import 'package:tokigo/features/home/presentation/widgets/home_ai_search_field.dart';
import 'package:tokigo/features/home/presentation/widgets/home_section.dart';
import 'package:tokigo/features/home/presentation/widgets/home_stays_carousel.dart';
import 'package:tokigo/features/home/providers/home_providers.dart';
import 'package:tokigo/features/search/application/providers/offer_selection_provider.dart';
import 'package:tokigo/l10n/app_localizations.dart';
import 'package:tokigo/shared/providers/locale_provider.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  /// Last router location seen by this page — used to detect RETURNS to the
  /// Home surface (any sub-route popping back onto '/' Home root).
  String? _lastSeenLocation;
  bool _routerHooked = false;
  GoRouter? _hookedRouter;

  /// The feed's scroll position (only needed to honour a [HomeScrollTarget]
  /// and to drive the secondary search reveal).
  final ScrollController _feedController = ScrollController();

  /// The navigation rail whose ACTUAL disappearance drives the secondary
  /// search. Its render box is measured against the viewport on every scroll
  /// frame — never a guessed scroll offset.
  final GlobalKey _navKey = GlobalKey();

  /// The Home scroll view, used as the coordinate space for the rail's
  /// visibility measurement.
  final GlobalKey _scrollKey = GlobalKey();

  /// Anchors the Discover section so another page can land on it.
  final GlobalKey _discoverKey = GlobalKey();
  bool _scrollScheduled = false;

  /// Drives the secondary compact search's entrance from above the viewport.
  late final AnimationController _searchReveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );

  /// Whether the navigation rail has fully left the viewport.
  bool _navGone = false;

  /// The original composer's draft, lifted so it survives the header being
  /// scrolled out of the viewport and back.
  final TextEditingController _composerTextController = TextEditingController();

  /// Guards the post-frame visibility measurement, so a scroll frame schedules
  /// at most one re-measurement.
  bool _revealScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _feedController.addListener(_onFeedScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateSearchReveal());
  }

  @override
  void dispose() {
    _feedController.removeListener(_onFeedScroll);
    _searchReveal.dispose();
    _composerTextController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    // Cannot look up ancestors in dispose — the router reference was saved at
    // hook time exactly for this.
    _hookedRouter?.routerDelegate.removeListener(_onRouteChanged);
    _hookedRouter = null;
    _routerHooked = false;
    _feedController.dispose();
    super.dispose();
  }

  /// Drives the secondary search from the navigation rail's ACTUAL position.
  ///
  /// The rail's render box is measured against the scroll view's viewport on
  /// every scroll frame, so the reveal begins at the exact frame the final
  /// navigation item leaves the screen — not at a guessed scroll offset — and
  /// reverses naturally when the rail returns.
  void _onFeedScroll() {
    // The scroll notification arrives BEFORE the frame's layout, so the rail's
    // render box still holds its previous position. Measure after the frame,
    // when the layout reflects the new scroll offset.
    if (_revealScheduled) return;
    _revealScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _revealScheduled = false;
      if (mounted) _updateSearchReveal();
    });
  }

  void _updateSearchReveal() {
    if (!_feedController.hasClients) return;
    final BuildContext? navContext = _navKey.currentContext;
    final BuildContext? scrollContext = _scrollKey.currentContext;
    if (navContext == null || scrollContext == null) return;
    final RenderBox? navBox = navContext.findRenderObject() as RenderBox?;
    final RenderBox? scrollBox = scrollContext.findRenderObject() as RenderBox?;
    if (navBox == null || scrollBox == null) return;
    if (!navBox.hasSize || !scrollBox.hasSize) return;
    final double navBottom = navBox
        .localToGlobal(Offset(0, navBox.size.height), ancestor: scrollBox)
        .dy;
    final bool gone = navBottom <= 0;
    if (gone == _navGone) return;
    _navGone = gone;
    if (gone) {
      _searchReveal.forward();
    } else {
      _searchReveal.reverse();
    }
  }

  /// Hooks the router listener lazily (H2): the widget tree may host
  /// HomePage in contexts without a GoRouter (tests); `maybeOf` makes the
  /// hook strictly optional so those hosts stay valid.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routerHooked) return;
    final router = GoRouter.maybeOf(context);
    if (router == null) return;
    _lastSeenLocation = router.state.matchedLocation;
    router.routerDelegate.addListener(_onRouteChanged);
    _hookedRouter = router;
    _routerHooked = true;
  }

  void _onRouteChanged() {
    final router = _hookedRouter;
    if (router == null) return;
    final location = router.state.matchedLocation;
    final previous = _lastSeenLocation;
    final wasHome = _isHomeLocation(previous);
    final isHome = _isHomeLocation(location);
    _lastSeenLocation = location;
    // A route CHANGE landing on the Home surface (returning from a
    // sub-route or another tab) triggers the H2 price/availability
    // revalidation. Controller guards make repeats harmless (one job per
    // snapshot) and cold start a no-op.
    if (isHome && (previous != location || !wasHome)) {
      _refreshPrices();
    }
  }

  /// The Home surface is Today, the router root '/' — sub-routes
  /// ('/flights',
  /// '/hotels', ...) are their own pages; only returning to '/' counts.
  bool _isHomeLocation(String? location) => location == '/';

  /// H2: revalidate prices/availability in the background — never reloads
  /// sections, hotels or images (all guards live in the controller).
  void _refreshPrices() {
    ref.read(homeControllerProvider.notifier).refreshPrices();
  }

  // H2: app foreground (user returns to the app) → same price/availability
  // revalidation, matching the "open the app → refresh prices" contract.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshPrices();
    }
  }

  /// Consumes a pending [HomeScrollTarget] once the feed has been laid out.
  void _consumeScrollTarget() {
    if (_scrollScheduled) return;
    if (ref.read(homeScrollTargetProvider) == null) return;
    _scrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollScheduled = false;
      if (!mounted) return;
      final BuildContext? target = _discoverKey.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          alignment: 0.02,
        );
      }
      ref.read(homeScrollTargetProvider.notifier).state = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(localeProvider, (previous, next) {
      if (previous?.languageCode != next.languageCode) {
        ref.read(homeControllerProvider.notifier).loadRecommendedHotels();
      }
    });
    // A currency change re-prices the recommendation rail in the new display
    // currency (the controller reads the choice per request).
    ref.listen(currencyProvider, (previous, next) {
      if (previous != next) {
        ref.read(homeControllerProvider.notifier).loadRecommendedHotels();
      }
    });
    final state = ref.watch(homeControllerProvider);
    _consumeScrollTarget();
    return Scaffold(
      backgroundColor: HomeDesignTokens.backgroundOf(context),
      // H1: pull-to-refresh removed by product decision — Home refreshes
      // prices/availability via live validation only (H2).
      //
      // The original header (wordmark, AI composer, navigation) is part of
      // the scrollable content; the compact search overlay appears only after
      // the navigation rail has left the viewport.
      // Section pages are pushed routes with their own header/back control.
      body: SafeArea(
        top: true,
        // The feed stays edge-to-edge under the navigation bar.
        bottom: false,
        child: Stack(
          children: <Widget>[
            CustomScrollView(
              key: _scrollKey,
              controller: _feedController,
              slivers: <Widget>[
                // The original Home header — wordmark, AI composer and
                // navigation — is part of the scrollable content. It leaves the
                // viewport naturally as the feed scrolls.
                SliverToBoxAdapter(child: _buildOriginalHeader()),
                ..._feedSlivers(state, ref),
              ],
            ),
            // The secondary compact search. It is an OVERLAY: it never changes
            // the scroll extent of the original content, and it is only
            // revealed once the navigation rail has completely left the
            // viewport.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _SecondarySearchOverlay(controller: _searchReveal),
            ),
          ],
        ),
      ),
    );
  }

  /// The original Home header: wordmark, AI composer and navigation, as one
  /// continuous section of the scrollable content.
  ///
  /// Nothing here is pinned. The wordmark, the original AI search box and the
  /// navigation buttons all leave the viewport together as the feed scrolls.
  Widget _buildOriginalHeader() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            AppSpacing.lg,
            AppSpacing.xs,
            AppSpacing.lg,
            0,
          ),
          child: SizedBox(
            height: HomeCardDimensions.topBarHeight,
            child: HomeTopBar(),
          ),
        ),
        // The original AI composer — the same widget the pinned slot used.
        AppChrome(controller: _composerTextController),
        _buildActionBar(),
      ],
    );
  }

  /// The service navigation rail. It scrolls away with the feed; its real
  /// position drives the secondary search reveal.
  Widget _buildActionBar() {
    final l10n = AppLocalizations.of(context)!;
    final List<HomeActionDefinition> definitions = homeActionDefinitions(l10n);
    final Map<HomeAction, String> paths = <HomeAction, String>{
      for (final HomeActionDefinition definition in definitions)
        definition.action: definition.path,
    };
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        top: AppSpacing.md,
        bottom: AppSpacing.md,
      ),
      child: KeyedSubtree(
        key: _navKey,
        child: HomeActionBar(
          definitions: definitions,
          // Pushing (not `go`) keeps Home beneath the section page, so the
          // section's back control returns to the dashboard.
          onActionSelected: (HomeAction action) {
            final String? path = paths[action];
            if (path == null) return;
            context.push(path);
          },
        ),
      ),
    );
  }

  /// The sections Home renders.
  ///
  /// OWNER DECISION (2026-11): Home shows exactly two things — the **Explore**
  /// destination rail and the **Stays Near You** rail. Every other backend
  /// section ("Recommended for you", "Tour packages", "Experiences & stories",
  /// …) is dropped permanently.
  ///
  /// Nothing real is lost by dropping the chrome: the backend's destination
  /// cards are still merged INTO Explore, and its stay cards still feed the
  /// Stays rail through [HomeState.recommendedHotels] (with the composed
  /// picked-for-you/hotel section as the fallback). Only the extra section
  /// headings and layouts disappear.
  List<HomeSection> _exploreSections(HomeState state) {
    final HomeSection bundled = buildHomeExploreSection();
    final List<HomeItem> backendDestinations = <HomeItem>[
      for (final HomeSection section in state.sections)
        if (_isDiscoverSection(section))
          ...section.items.where(
            (HomeItem item) => item.type == HomeCardType.destination,
          ),
    ];
    if (backendDestinations.isEmpty) return <HomeSection>[bundled];
    return <HomeSection>[
      mergeBackendDestinations(
        bundled,
        backendDestinations: backendDestinations,
      ),
    ];
  }

  /// The Explore rail as a sliver list.
  ///
  /// Shared by the loading, empty and success states so the bundled catalog is
  /// rendered immediately — the feed can add backend destinations on top, but
  /// it must never be a precondition for Explore to exist.
  List<Widget> _exploreRailSlivers(List<HomeSection> visibleSections) {
    return <Widget>[
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => HomeSectionWidget(
            // ONE anchor for the Discover section — a GlobalKey may only
            // ever sit on a single widget.
            key: index == 0 ? _discoverKey : null,
            section: visibleSections[index],
            onFlightTap: (HomeItem flight) =>
                _selectFlightForBooking(ref, flight),
            onViewAllFlights: () => context.push('/flights'),
            onFavorite: (flightId, value) {
              // Handle wishlist change
            },
          ),
          childCount: visibleSections.length,
        ),
      ),
    ];
  }

  /// A section whose items are all destinations is Home's Discover section
  /// (DS-6) — the anchor the results page scrolls to.
  static bool _isDiscoverSection(HomeSection section) =>
      section.items.isNotEmpty &&
      section.items.every((item) => item.type == HomeCardType.destination);

  /// The dashboard's feed content as slivers.
  ///
  /// The original header (wordmark, AI composer and navigation) scrolls as
  /// the first section of this same scroll view. This method only carries the
  /// feed content that follows it.
  List<Widget> _feedSlivers(HomeState state, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final AppTypography typography =
        Theme.of(context).brightness == Brightness.dark
        ? AppTypography.forDark()
        : AppTypography.forLight();
    final List<HomeSection> visibleSections = _exploreSections(state);
    final HomeSection? pickedForYou = state.sections
        .where(
          (HomeSection section) =>
              section.metadata['semanticId'] == 'picked-for-you' ||
              section.items.any(
                (HomeItem item) =>
                    item.metadata['semanticId'] == 'picked-for-you',
              ),
        )
        .firstOrNull;
    final HomeSection? hotelSection = state.sections
        .where(
          (HomeSection section) => section.items.any(
            (HomeItem item) => item.type == HomeCardType.hotel,
          ),
        )
        .firstOrNull;
    final List<HomeItem> visibleHotels = state.recommendedHotels.isNotEmpty
        ? state.recommendedHotels
        : ((pickedForYou ?? hotelSection)?.items
                  .where((HomeItem item) => item.type == HomeCardType.hotel)
                  .toList() ??
              const <HomeItem>[]);
    switch (state.status) {
      case HomeStatus.loading:
        return <Widget>[
          // The bundled Explore catalog is on-device, so it NEVER waits for the
          // feed: on a slow or unreachable backend the cities are already on
          // screen instead of a full-page skeleton. Only the Stays rail (which
          // is provider-backed) stays in its loading state.
          ..._exploreRailSlivers(visibleSections),
          const SliverToBoxAdapter(child: _StaysSkeletonList()),
        ];
      // The bundled Explore catalog is on-device, so a FAILED feed (offline,
      // server down) must not blank Home: the rail still renders. The global
      // offline banner already tells the traveller what happened.
      case HomeStatus.error when visibleSections.isNotEmpty:
      case HomeStatus.success:
      case HomeStatus.partial:
      case HomeStatus.developmentPreview:
      // The bundled Explore catalog guarantees cities on a first offline
      // launch, so an empty BACKEND feed is not an empty Home: the rail still
      // renders. Only a genuinely empty catalog shows the empty state below.
      case HomeStatus.empty when visibleSections.isNotEmpty:
        return <Widget>[
          // Owner decision (2026-10-26): Discover leads the feed — the city
          // rail is the traveller's first "where next?" cue, and Stays
          // follows it.
          ..._exploreRailSlivers(visibleSections),
          // Recommended stays (doc 17 §3.5): section header + card A, paged
          // horizontally — one stay per swipe (owner decision, 2026-10-25).
          // Phase 1B: the composer renders these as "Picked for You" for
          // authenticated users — show the standalone rail ONLY when no
          // composed section carries that semantic id, so stays are never
          // repeated.
          if (visibleHotels.isNotEmpty) ...<Widget>[
            SliverToBoxAdapter(
              child: SectionHeader(
                title: l10n.homeStaysTitle,
                // Same step as every other Home section heading so Discover
                // and Stays read as one rhythm (owner decision, 2026-10-26).
                titleStyle: typography.titleMedium.copyWith(
                  color: context.tokigoColors.textPrimary,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: HomeStaysCarousel(
                items: visibleHotels,
                // Home's "Stays Near You" rail uses the approved horizontal
                // 60/40 split and draws the heart directly on the photo.
                splitLayout: true,
                showHeartPlatter: false,
                // The card is the SAME measured width and height as a
                // Trending Destinations city card: the city rail's page
                // fraction and its pageWidth / ratio height.
                viewportFraction:
                    HomeCardDimensions.destinationViewportFraction,
                cardHeightBuilder: HomeStaysCarousel.splitCardHeightFor,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
          ],
          // Breathing room under the last card / section.
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
        ];
      case HomeStatus.empty:
        return <Widget>[
          SliverFillRemaining(
            hasScrollBody: false,
            child: _CenteredFeedState(
              child: AppMessageState(
                icon: Icons.explore_off_outlined,
                title: l10n.homeEmptyTitle,
                body: l10n.homeEmptyBody,
                actionLabel: l10n.retry,
                onAction: () =>
                    ref.read(homeControllerProvider.notifier).load(),
              ),
            ),
          ),
        ];
      case HomeStatus.error:
        return <Widget>[
          SliverFillRemaining(
            hasScrollBody: false,
            child: _CenteredFeedState(
              child: AppMessageState(
                icon: Icons.wifi_off_rounded,
                hue: context.tokigoColors.danger,
                title: l10n.homeErrorTitle,
                // Deliberately NOT `state.errorMessage`: that string comes from
                // the network layer in English and would be the only English
                // sentence an Arabic user ever sees.
                body: l10n.homeErrorBody,
                actionLabel: l10n.retry,
                onAction: () =>
                    ref.read(homeControllerProvider.notifier).load(),
              ),
            ),
          ),
        ];
    }
  }

  void _selectFlightForBooking(WidgetRef ref, HomeItem flight) {
    final Map<String, dynamic> metadata = flight.metadata;
    ref.read(selectedOfferProvider.notifier).state = SelectedOffer(
      offerId: flight.id,
      providerId: metadata['providerId']?.toString() ?? '',
      providerName: metadata['providerName']?.toString() ?? '',
      price: flight.price ?? 0,
      currency: flight.currency ?? 'USD',
      searchId: '',
      offerType: 'flight',
      title: flight.title,
      subtitle: flight.subtitle,
      imageUrl: flight.imageUrl,
    );
    context.push('/booking/review');
  }
}

/// The secondary compact search, pinned as an overlay at the top of Home.
///
/// It is a SEPARATE control from the original AI composer — which scrolls away
/// with the header — and owns its own state. It enters from above the viewport
/// when the navigation rail has completely left the screen, and exits upward
/// when the rail returns.
///
/// It is an OVERLAY, not a sliver: it never changes the scroll extent of the
/// original content, and it never overlaps the original header (which has
/// already left the viewport before the overlay is revealed).
class _SecondarySearchOverlay extends StatelessWidget {
  const _SecondarySearchOverlay({required this.controller});

  final AnimationController controller;

  /// The compact field's resting line: the original composer band's top edge
  /// (the top-bar inset plus the top-bar height). The overlay slides down to
  /// exactly this line, so it lands on the composer's own position instead of
  /// jumping up to the viewport top.
  static const double _restingOffset =
      AppSpacing.xs + HomeCardDimensions.topBarHeight;

  @override
  Widget build(BuildContext context) {
    // The hidden shift must clear the resting offset as well as the pill,
    // otherwise the parked overlay would still poke into the viewport.
    final double hiddenShift =
        -1.0 - _restingOffset / AppChrome.pinnedHeight;
    return IgnorePointer(
      ignoring: controller.value == 0,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0, hiddenShift),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: controller, curve: Curves.easeOutCubic),
        ),
        child: Transform.translate(
          offset: const Offset(0, _restingOffset),
          child: SizedBox(
            height: AppChrome.pinnedHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Center(
                child: HomeAiSearchField(
                  compact: true,
                  accentColor: HomeDesignTokens.accentOf(context),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Centers an honest state (empty / offline) in the feed's remaining
/// viewport, beneath the original header.
///
/// The state scrolls only when its content genuinely cannot fit — a very
/// small screen or a large system type scale — so the message is never
/// clipped and never overlaps the compact search overlay.
///
/// This used to be a `LayoutBuilder`, which cannot answer intrinsic
/// dimensions: `RenderSliverFillRemaining.performLayout` always asks its
/// child for `getMaxIntrinsicHeight`, so every debug build of the
/// empty/offline state threw "LayoutBuilder does not support returning
/// intrinsic dimensions". `Center` implements intrinsics, so the question is
/// answered instead of crashing.
///
/// No `SingleChildScrollView` either: it would give `Center` an UNBOUNDED
/// height, which makes `Center` top-align the message.
/// `SliverFillRemaining` already sizes itself to `max(viewport, child
/// intrinsic)`, so a message that genuinely cannot fit grows the sliver and
/// the outer feed scrolls — the message is never clipped.
class _CenteredFeedState extends StatelessWidget {
  const _CenteredFeedState({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(child: child);
  }
}

// ─── Discover (card D) ────────────────────────────────────────────────────────

// ─── Recommended stays (card A) ───────────────────────────────────────────────

/// The loading state of the recommended-stays rail.
///
/// It is the SAME [HomeStaysCarousel] the loaded feed uses, in its loading
/// state: same page fraction, same rail height, same trailing gap, one
/// placeholder card at the exact width and height a real stay will occupy — so
/// the feed does not jump when the real stays land. The skeleton never scrolls:
/// pretending there are pages to swipe before any stay exists would be a lie.
class _StaysSkeletonList extends StatelessWidget {
  const _StaysSkeletonList();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: ShimmerBox(
              height: AppSpacing.xl,
              width: HomeCardDimensions.sectionTitleSkeletonWidth,
            ),
          ),
        ),
        // The SAME geometry the loaded "Stays Near You" rail uses: the split
        // layout, the 60/40 card, the Discover page fraction and the city
        // card's height. A skeleton at any other size makes the feed jump
        // when the real stays land.
        HomeStaysCarousel(
          items: const <HomeItem>[],
          loading: true,
          splitLayout: true,
          showHeartPlatter: false,
          viewportFraction: HomeCardDimensions.destinationViewportFraction,
          cardHeightBuilder: HomeStaysCarousel.splitCardHeightFor,
        ),
      ],
    );
  }
}
