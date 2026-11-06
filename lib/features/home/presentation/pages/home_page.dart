import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tokigo/app/widgets/home_nav_buttons.dart';
import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/ui/app_message_state.dart';
import 'package:tokigo/core/ui/app_wordmark.dart';
import 'package:tokigo/core/widgets/section_header.dart';
import 'package:tokigo/core/widgets/shimmer.dart';
import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_section.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/features/bag/presentation/pages/bag_page.dart';
import 'package:tokigo/features/groups/presentation/pages/groups_page.dart';
import 'package:tokigo/features/home/domain/home_action.dart';
import 'package:tokigo/features/home/presentation/home_controller.dart';
import 'package:tokigo/features/home/presentation/home_design_tokens.dart';
import 'package:tokigo/features/home/presentation/widgets/home_ai_search_field.dart';
import 'package:tokigo/features/home/presentation/widgets/destination_cover_flow_carousel.dart';
import 'package:tokigo/features/home/presentation/widgets/home_section.dart';
import 'package:tokigo/features/home/presentation/widgets/home_stays_carousel.dart';
import 'package:tokigo/core/widgets/pressable.dart';
import 'package:tokigo/features/home/providers/home_providers.dart';
import 'package:tokigo/features/notifications/presentation/widgets/notification_bell.dart';
import 'package:tokigo/features/search/domain/country_airport_suggestions.dart';
import 'package:tokigo/features/search/domain/search_context.dart';
import 'package:tokigo/features/search/application/providers/offer_selection_provider.dart';
import 'package:tokigo/features/search/presentation/pages/car_search_page.dart';
import 'package:tokigo/features/search/presentation/pages/flight_search_page.dart';
import 'package:tokigo/features/search/presentation/pages/hotel_search_page.dart';
import 'package:tokigo/features/search/presentation/pages/packages_search_page.dart';
import 'package:tokigo/l10n/app_localizations.dart';
import 'package:tokigo/shared/providers/locale_provider.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with WidgetsBindingObserver {
  /// Last router location seen by this page — used to detect RETURNS to the
  /// Home surface (any sub-route popping back onto '/' Home root).
  String? _lastSeenLocation;
  bool _routerHooked = false;
  GoRouter? _hookedRouter;

  /// The feed's scroll position (only needed to honour a [HomeScrollTarget]).
  final ScrollController _feedController = ScrollController();

  /// Anchors the Discover section so another page can land on it.
  final GlobalKey _discoverKey = GlobalKey();
  bool _scrollScheduled = false;

  /// The AI composer pill: a fixed 56dp tall at every scroll position.
  static const double _pillHeight = 56;

  /// Gap between the pill and the bottom edge of the screen.
  static const double _pillBottomMargin = AppSpacing.md;

  /// Space the scrollables reserve so the last card is never hidden behind
  /// the floating pill. Reserved ONCE, by each scrollable — never by the
  /// layout around it, which is what used to leave a dead empty band above
  /// the pill.
  static double composerReserve(BuildContext context) =>
      _pillHeight + _pillBottomMargin + MediaQuery.paddingOf(context).bottom;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Cannot look up ancestors in dispose — the router reference was saved at
    // hook time exactly for this.
    _hookedRouter?.routerDelegate.removeListener(_onRouteChanged);
    _hookedRouter = null;
    _routerHooked = false;
    _feedController.dispose();
    super.dispose();
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

  /// The Home surface is the shell root '/' — sub-routes ('/flights',
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
    final selectedAction = ref.watch(homeSelectedActionProvider);
    _consumeScrollTarget();
    return Scaffold(
      backgroundColor: HomeDesignTokens.backgroundOf(context),
      // H1: pull-to-refresh removed by product decision — Home refreshes
      // prices/availability via live validation only (H2).
      //
      // The keyboard resizes this body, so the floating pill (bottom: 0 of the
      // Stack) rides up with it and is never covered.
      body: SafeArea(
        top: true,
        // The feed stays edge-to-edge under the navigation bar; the pill owns
        // (and reserves) that inset itself.
        bottom: false,
        child: Stack(
          children: <Widget>[
            // Bottom layer: the pinned top area and the scrolling content. The
            // content reserves the pill's footprint ITSELF (each scrollable
            // does), so cards can scroll beneath the floating pill and nothing
            // is cut off.
            Column(
              children: <Widget>[
                // Pinned top: the header and the quick-action row. Neither
                // moves, resizes or animates while the feed scrolls beneath.
                _buildTopArea(context, selectedAction),
                Expanded(
                  child: selectedAction == null
                      ? _buildDashboard(state, ref)
                      : _buildSelectedAction(selectedAction),
                ),
              ],
            ),
            // Top layer: ONLY the pill. No full-width background — the canvas
            // shows through, so there is no dead band above it.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  _pillBottomMargin + MediaQuery.paddingOf(context).bottom,
                ),
                child: HomeAiSearchField(
                  accentColor: HomeDesignTokens.accentOf(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Home's pinned top: the header (wordmark, notifications, profile) with the
  /// quick-action row directly beneath it. Both stay fixed while the feed
  /// scrolls, so the traveller's service switcher is always reachable and the
  /// location-explainer slot it replaced is gone without leaving a gap.
  Widget _buildTopArea(BuildContext context, HomeAction? selectedAction) {
    return ColoredBox(
      color: HomeDesignTokens.backgroundOf(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              AppSpacing.lg,
              AppSpacing.xs,
              AppSpacing.lg,
              0,
            ),
            child: _HomeTopBar(),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: HomeActionBar(
              searchContext: _searchContext(),
              selectedAction: selectedAction,
              onActionSelected: _selectAction,
            ),
          ),
        ],
      ),
    );
  }

  /// Switches the in-page Home content. Tapping the already-selected action
  /// returns to the full dashboard (the quick-action tiles are the only Home
  /// switcher).
  void _selectAction(HomeAction action) {
    final HomeAction? current = ref.read(homeSelectedActionProvider);
    final HomeAction? next = current == action ? null : action;
    ref.read(homeSelectedActionProvider.notifier).state = next;
  }

  /// The normal Home dashboard: the composed feed inside ONE vertical
  /// scrollable owned by Home. The header and quick-action row are pinned
  /// above it; the floating pill is the feed's own bottom padding.
  Widget _buildDashboard(HomeState state, WidgetRef ref) {
    // The pill's footprint is appended INSIDE the same sliver list as the
    // feed's own bottom spacer (never as a SliverPadding around a group):
    // `SliverFillRemaining` measures its child's intrinsic height, and a
    // `SliverMainAxisGroup` cannot supply intrinsics — the empty/offline state
    // crashed the layout with "LayoutBuilder does not support returning
    // intrinsic dimensions".
    final List<Widget> slivers = _feedSlivers(state, ref);
    // The fill states (empty / offline) subtract the pill's footprint inside
    // `_CenteredFeedState` itself, so they must not reserve it again here —
    // that would leave the scroll view an extra reserve's worth of dead extent.
    // Keyed on the status, not on the trailing widget: the success feed also
    // ends in a spacer (its own breathing room), and it DOES need the reserve.
    final bool fillsViewport =
        state.status == HomeStatus.empty || state.status == HomeStatus.error;
    return CustomScrollView(
      controller: _feedController,
      slivers: <Widget>[
        ...slivers,
        // Reserved ONCE, inside the scrollable, so the last card scrolls up
        // past the pill instead of being clipped by a gap in the layout — and
        // the empty/offline state centres between the pinned row and the pill
        // instead of the bottom of the screen.
        if (!fillsViewport)
          SliverToBoxAdapter(child: SizedBox(height: composerReserve(context))),
      ],
    );
  }

  /// The selected service's existing page, embedded in Home's Scaffold.
  ///
  /// The top action bar stays pinned so the traveller can switch services
  /// at any time; the service itself keeps its own feature widgets, Riverpod
  /// controllers and scroll behaviour.
  Widget _buildSelectedAction(HomeAction action) {
    final SearchContext searchContext = _searchContext();
    return _buildFeatureContent(action, searchContext);
  }

  Widget _buildFeatureContent(HomeAction action, SearchContext searchContext) {
    // Each embedded page reserves the pill's footprint in its OWN scrollable,
    // so its last field/button is never hidden behind the floating pill and
    // its own canvas fills the reserve.
    final double reserve = composerReserve(context);
    switch (action) {
      case HomeAction.flights:
        return FlightSearchPage(
          key: const ValueKey<String>('home-flights-content'),
          embedded: true,
          searchContext: searchContext,
          bottomPadding: reserve,
        );
      case HomeAction.hotels:
        return HotelSearchPage(
          key: const ValueKey<String>('home-hotels-content'),
          embedded: true,
          searchContext: searchContext,
          bottomPadding: reserve,
        );
      case HomeAction.cars:
        return CarSearchPage(
          key: const ValueKey<String>('home-cars-content'),
          embedded: true,
          bottomPadding: reserve,
        );
      case HomeAction.activities:
        // The old Activities tile opened the packages/tour-programs search.
        return PackagesSearchPage(
          key: const ValueKey<String>('home-activities-content'),
          embedded: true,
          bottomPadding: reserve,
        );
      case HomeAction.groups:
        return GroupsPage(
          key: const ValueKey<String>('home-groups-content'),
          bottomPadding: reserve,
        );
      case HomeAction.trips:
        return BagPage(
          key: const ValueKey<String>('home-trips-content'),
          embedded: true,
          bottomPadding: reserve,
        );
    }
  }

  /// A section whose items are all destinations is Home's Discover section
  /// (DS-6) — the anchor the results page scrolls to.
  static bool _isDiscoverSection(HomeSection section) =>
      section.items.isNotEmpty &&
      section.items.every((item) => item.type == HomeCardType.destination);

  /// The dashboard's feed content as slivers. The header and quick-action row
  /// are pinned above this scroll view and the composer below it.
  List<Widget> _feedSlivers(HomeState state, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final List<HomeSection> visibleSections = state.sections
        .where(_isDiscoverSection)
        .take(1)
        .toList();
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
        return const <Widget>[
          SliverToBoxAdapter(child: _DiscoverSkeletonList()),
          SliverToBoxAdapter(child: _StaysSkeletonList()),
        ];
      case HomeStatus.success:
      case HomeStatus.partial:
      case HomeStatus.developmentPreview:
        return <Widget>[
          // Owner decision (2026-10-26): Discover leads the feed — the city
          // rail is the traveller's first "where next?" cue, and Stays
          // follows it.
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
                titleStyle: AppTypography.forLight().titleMedium.copyWith(
                  color: context.tokigoColors.textPrimary,
                ),
              ),
            ),
            SliverToBoxAdapter(child: HomeStaysCarousel(items: visibleHotels)),
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
              // The pill's footprint stays reserved for this state too, so the
              // message centres between the pinned row and the pill.
              reserveBottom: composerReserve(context),
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
              reserveBottom: composerReserve(context),
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

  /// Phase 4A — the traveller's travel context for the search tiles.
  ///
  /// The destination prefills from the first published Discover city; the
  /// traveller sees it and can change it. Context only — never a filter.
  SearchContext _searchContext() {
    final countryCode = ref
        .watch(geoCountryProvider)
        .asData
        ?.value
        ?.countryCode
        ?.trim()
        .toUpperCase();
    final destinations = ref
        .watch(homeControllerProvider)
        .sections
        .expand((HomeSection section) => section.items)
        .where((HomeItem item) => item.type == HomeCardType.destination)
        .toList();
    final String? destination = destinations.isEmpty
        ? null
        : destinations.first.title.trim();
    return SearchContext(
      destination: destination == null || destination.isEmpty
          ? null
          : destination,
      countryCode: countryCode == null || countryCode.isEmpty
          ? null
          : countryCode,
      airport: suggestedAirportCodeForCountry(countryCode),
    );
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

/// Home's top bar — the TokiGo wordmark, notifications and profile avatar.
///
/// The wordmark is the brand mark, so it is built ONLY through [AppWordmark]
/// (a hand-rolled pair of text halves would mirror into "GoToki" in Arabic).
/// It carries no greeting line: the logotype is Home's identity, and a
/// personalized greeting lives in the composition contract (home_greeting)
/// rather than occupying the page's loudest slot.
class _HomeTopBar extends StatelessWidget {
  const _HomeTopBar();

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // 320pt phones are the narrowest target. The two 48pt actions and the
        // 56pt avatar take 104pt; give the wordmark only what is left and
        // scale it down rather than letting the row overflow.
        final double wordmarkWidth = (constraints.maxWidth - 112).clamp(
          0.0,
          172.0,
        );

        return Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            textDirection: TextDirection.ltr,
            children: <Widget>[
              // One semantics node saying "TokiGo" — the two halves are one word.
              Semantics(
                label: 'TokiGo',
                container: true,
                child: ExcludeSemantics(
                  child: SizedBox(
                    width: wordmarkWidth,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: AppWordmark(base: typography.title),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              AnimatedNotificationBell(
                normalColor: context.tokigoColors.textPrimary,
                onTap: () => context.push('/notifications'),
              ),
              const _HomeAvatar(),
            ],
          ),
        );
      },
    );
  }
}

/// Profile destination as a fixed person glyph.
///
/// Intentionally static: the chrome looks the SAME whether or not the
/// traveller is signed in, so Home's only profile affordance never changes
/// shape (and a signed-in photo never leaks into the header).
class _HomeAvatar extends StatelessWidget {
  const _HomeAvatar();

  static const double size = 40;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Semantics(
      button: true,
      label: l10n.profile,
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(size / 2),
        child: Pressable(
          onTap: () => context.push('/profile'),
          child: ClipOval(
            child: SizedBox(
              width: size,
              height: size,
              child: Container(
                decoration: BoxDecoration(
                  color: context.tokigoColors.surfaceSecondary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: context.tokigoColors.hairlineStrong,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.person_rounded,
                  size: 22,
                  color: context.tokigoColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Centered honest states (empty / offline) ───────────────────────────────

/// Centers an honest state (empty / offline) in the feed's remaining
/// viewport, between the pinned quick-action row and the pinned composer.
///
/// The state scrolls only when its content genuinely cannot fit — a very
/// small screen or a large system type scale — so the message is never
/// clipped and never overlaps the pinned chrome.
///
/// [reserveBottom] is subtracted from the viewport height the message centres
/// in, so the pill's footprint is honoured without a trailing spacer sliver
/// (a second sliver after `SliverFillRemaining` forces it to measure its
/// child's intrinsics, which [LayoutBuilder] cannot provide).
class _CenteredFeedState extends StatelessWidget {
  const _CenteredFeedState({required this.child, this.reserveBottom = 0});

  final Widget child;

  /// Space kept clear at the bottom of the state's own viewport (the floating
  /// AI composer's footprint).
  final double reserveBottom;

  @override
  Widget build(BuildContext context) {
    // `SliverFillRemaining` fills the viewport and hands this child TIGHT
    // constraints, so the reserve is simply subtracted here — and `Padding` +
    // `Center` are both intrinsics-safe.
    //
    // This used to be a `LayoutBuilder`, which cannot answer intrinsic
    // dimensions: `RenderSliverFillRemaining.performLayout` always asks its
    // child for `getMaxIntrinsicHeight`, so every debug build of the
    // empty/offline state threw "LayoutBuilder does not support returning
    // intrinsic dimensions". `Padding`/`Center` implement intrinsics, so the
    // question is answered instead of crashing.
    //
    // No `SingleChildScrollView` either: it would give `Center` an UNBOUNDED
    // height, which makes `Center` top-align the message. `SliverFillRemaining`
    // already sizes itself to `max(viewport, child intrinsic)`, so a message
    // that genuinely cannot fit grows the sliver and the outer feed scrolls —
    // the message is never clipped and never overlaps the pill.
    return Padding(
      padding: EdgeInsets.only(bottom: reserveBottom),
      child: Center(child: child),
    );
  }
}

// ─── Discover (card D) ────────────────────────────────────────────────────────

/// The loading state of the Discover rail.
///
/// Discover leads the feed, so its placeholder leads the loading feed too. It
/// is the SAME [DestinationCoverFlowCarousel] the loaded feed uses, in its
/// loading state: the rail height, page width and photo ratio are the rail's
/// own, so nothing moves when the first city lands. One page only — the
/// skeleton never pretends there are cities to swipe before any has arrived.
class _DiscoverSkeletonList extends StatelessWidget {
  const _DiscoverSkeletonList();

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
            child: ShimmerBox(height: 24, width: 150),
          ),
        ),
        DestinationCoverFlowCarousel(
          items: const <HomeItem>[],
          onItemTap: null,
          loading: true,
        ),
      ],
    );
  }
}

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
            child: ShimmerBox(height: 24, width: 180),
          ),
        ),
        HomeStaysCarousel(items: const <HomeItem>[], loading: true),
      ],
    );
  }
}
