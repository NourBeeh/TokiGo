import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tokigo/app/widgets/home_nav_buttons.dart';
import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/ui/app_message_state.dart';
import 'package:tokigo/core/ui/app_wordmark.dart';
import 'package:tokigo/core/ui/localized_date.dart';
import 'package:tokigo/core/widgets/cards/card.dart';
import 'package:tokigo/core/widgets/section_header.dart';
import 'package:tokigo/core/widgets/shimmer.dart';
import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_section.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/features/home/presentation/home_controller.dart';
import 'package:tokigo/features/home/presentation/widgets/home_ai_search_field.dart';
import 'package:tokigo/features/home/presentation/widgets/home_section.dart';
import 'package:tokigo/features/home/presentation/widgets/home_stays_carousel.dart';
import 'package:tokigo/features/home/providers/home_providers.dart';
import 'package:tokigo/features/search/domain/country_airport_suggestions.dart';
import 'package:tokigo/features/search/domain/search_context.dart';
import 'package:tokigo/features/search/application/providers/offer_selection_provider.dart';
import 'package:tokigo/features/bag/application/bag_controller.dart';
import 'package:tokigo/features/bag/domain/trip.dart';
import 'package:tokigo/features/bag/presentation/trip_labels.dart';
import 'package:tokigo/l10n/app_localizations.dart';

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

  /// Owner decision (2026-10-24): the mood feature was removed and the home
  /// feed restored mood-free — the composed Home feed (Discover + stays +
  /// other rails) renders again, with no mood rails or mood-matched products.
  /// Mirrors [HomeComposer.showsViewedRail].
  static const bool _homeFeedEnabled = true;

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
    final state = ref.watch(homeControllerProvider);
    final bag = ref.watch(bagControllerProvider);
    _consumeScrollTarget();
    return Scaffold(
      backgroundColor: AppColors.background,
      // H1: pull-to-refresh removed by product decision — Home refreshes
      // prices/availability via live validation only (H2). The old
      // RefreshIndicator wrapper is gone; the SafeArea/Column tree is
      // unchanged.
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.lg,
                AppSpacing.xs,
                AppSpacing.lg,
                AppSpacing.xs,
              ),
              child: const _HomeTopBar(),
            ),
            Expanded(child: _buildBody(state, ref, bag)),
          ],
        ),
      ),
    );
  }

  /// A section whose items are all destinations is Home's Discover section
  /// (DS-6) — the anchor the results page scrolls to.
  static bool _isDiscoverSection(HomeSection section) =>
      section.items.isNotEmpty &&
      section.items.every((item) => item.type == HomeCardType.destination);

  Widget _buildBody(HomeState state, WidgetRef ref, BagState bag) {
    // Owner decision (2026-10-24): clean home — only the chrome (pinned
    // search + nav buttons) renders by default. The mood feature was removed;
    // the mood-free feed below stays behind the [_homeFeedEnabled] flag.
    if (_homeFeedEnabled) {
      return _buildFeed(state, ref, bag);
    }
    return CustomScrollView(
      controller: _feedController,
      physics: const _ShorterHomeDragPhysics(),
      slivers: _homeHeaderSlivers(ref),
    );
  }

  Widget _buildFeed(HomeState state, WidgetRef ref, BagState bag) {
    final l10n = AppLocalizations.of(context)!;
    // The mood feature is gone: the feed shows every published section and the
    // recommended stays as-is, with no mood rails or mood-matched products.
    final List<HomeSection> visibleSections = state.sections
        .where((HomeSection section) => section.items.isNotEmpty)
        .toList();
    final List<HomeItem> visibleHotels = state.recommendedHotels;
    // The FIRST destination-only section is the Discover anchor.
    final int discoverIndex = visibleSections.indexWhere(_isDiscoverSection);
    switch (state.status) {
      case HomeStatus.loading:
        return CustomScrollView(
          controller: _feedController,
          physics: const _ShorterHomeDragPhysics(),
          slivers: <Widget>[
            ..._homeHeaderSlivers(ref),
            const SliverToBoxAdapter(child: _StaysSkeletonList()),
          ],
        );
      case HomeStatus.success:
      case HomeStatus.partial:
      case HomeStatus.developmentPreview:
        return CustomScrollView(
          controller: _feedController,
          physics: const _ShorterHomeDragPhysics(),
          slivers: [
            ..._homeHeaderSlivers(ref),
            // Recommended stays (doc 17 §3.5): section header + card A, paged
            // horizontally — one stay per swipe (owner decision, 2026-10-25).
            // Phase 1B: the composer renders these as "Picked for You" for
            // authenticated users — show the standalone rail ONLY when no
            // composed section carries that semantic id, so stays are never
            // repeated.
            if (visibleHotels.isNotEmpty &&
                !_hasPickedForYou(state)) ...<Widget>[
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: l10n.homeStaysTitle,
                  // Smaller than a standalone section heading: this one is a
                  // sentence ("Hotels recommended"), and at the display step it
                  // wrapped/dominated the cards it introduces.
                  titleStyle: AppTypography.forLight().titleMedium,
                  actionLabel: l10n.viewAll,
                  onAction: () => context.push('/hotels'),
                ),
              ),
              SliverToBoxAdapter(
                child: HomeStaysCarousel(items: visibleHotels),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
            ],
            // Doc 17 §2 — the trip row sits under the stays list, above the
            // composed sections.
            if (bag.currentTrips.isNotEmpty)
              SliverToBoxAdapter(
                child: _ContinuePlanningRow(trips: bag.currentTrips),
              ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => HomeSectionWidget(
                  // ONE anchor for the Discover section — a GlobalKey may only
                  // ever sit on a single widget.
                  key: index == discoverIndex ? _discoverKey : null,
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
            // Breathing room under the last card / section.
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
          ],
        );
      case HomeStatus.empty:
        return CustomScrollView(
          controller: _feedController,
          physics: const _ShorterHomeDragPhysics(),
          slivers: <Widget>[
            ..._homeHeaderSlivers(ref),
            SliverToBoxAdapter(
              child: AppMessageState(
                icon: Icons.explore_off_outlined,
                title: l10n.homeEmptyTitle,
                body: l10n.homeEmptyBody,
                actionLabel: l10n.retry,
                onAction: () =>
                    ref.read(homeControllerProvider.notifier).load(),
              ),
            ),
          ],
        );
      case HomeStatus.error:
        return CustomScrollView(
          controller: _feedController,
          physics: const _ShorterHomeDragPhysics(),
          slivers: <Widget>[
            ..._homeHeaderSlivers(ref),
            SliverToBoxAdapter(
              child: AppMessageState(
                icon: Icons.wifi_off_rounded,
                hue: AppColors.danger,
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
          ],
        );
    }
  }

  List<Widget> _homeHeaderSlivers(WidgetRef ref) => <Widget>[
    SliverPersistentHeader(
      pinned: true,
      delegate: _PinnedHomeSearchHeader(accentColor: AppColors.brand),
    ),
    SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.lg,
          AppSpacing.xs,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: HomeNavButtons(compact: true, searchContext: _searchContext()),
      ),
    ),
  ];

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

  /// True when a composed section already presents the recommended hotels
  /// (Phase 1B authenticated "Picked for You").
  /// Whether a section ALREADY shows the recommended stays.
  ///
  /// The composer's own section carries the semantic on the section; a
  /// section published from the admin carries it on its cards. Either way, the
  /// standalone list must not repeat the same stays twice.
  bool _hasPickedForYou(HomeState state) {
    return state.sections.any((HomeSection section) {
      if (section.items.isEmpty) return false;
      if (section.metadata['semanticId'] == 'picked-for-you') return true;
      return section.items.any(
        (HomeItem item) => item.metadata['semanticId'] == 'picked-for-you',
      );
    });
  }
}

class _ShorterHomeDragPhysics extends ScrollPhysics {
  const _ShorterHomeDragPhysics({super.parent});

  @override
  _ShorterHomeDragPhysics applyTo(ScrollPhysics? ancestor) {
    return _ShorterHomeDragPhysics(parent: buildParent(ancestor));
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    return super.applyPhysicsToUserOffset(position, offset) * 0.75;
  }
}

/// "Continue planning" — the trips that really exist in the Bag, as card F
/// rows (doc 15 §7): square thumb, title 17/600, a date/status line at 13/400
/// and a ⌀32 circle chevron. Rendered only when a real trip is present.
///
/// Three rows at most, then "View all" — the strip used to hold every trip
/// horizontally; the feed above it is the point of this screen.
class _ContinuePlanningRow extends StatelessWidget {
  const _ContinuePlanningRow({required this.trips});

  final List<TripSummary> trips;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeader(
          title: l10n.homeContinuePlanning,
          actionLabel: l10n.viewAll,
          onAction: () => context.push('/bag'),
        ),
        for (final TripSummary trip in trips.take(3))
          _ContinueTripTile(trip: trip),
      ],
    );
  }
}

class _ContinueTripTile extends StatelessWidget {
  const _ContinueTripTile({required this.trip});

  final TripSummary trip;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final l10n = AppLocalizations.of(context)!;
    final place = trip.destination.trim();
    final name = trip.title?.trim();
    // Name the trip with what the booking really carries (item name, place,
    // else its vertical); dates appear only when the booking has them.
    final headline = (name != null && name.isNotEmpty)
        ? name
        : (place.isNotEmpty ? place : tripTypeLabel(l10n, trip.type));
    final meta = <String>[
      if (trip.startDate != null) localizedMediumDate(context, trip.startDate!),
      if (trip.endDate != null) localizedMediumDate(context, trip.endDate!),
      tripStatusLabel(l10n, trip.status),
    ].join(' · ');

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Material(
        color: AppColors.surface,
        borderRadius: AppRadius.lgBorder,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/bag'),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: <Widget>[
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.brandContainer,
                    borderRadius: AppRadius.smBorder,
                  ),
                  child: Icon(
                    _tripIcon(trip.type),
                    size: 22,
                    color: AppColors.brand,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        headline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: typography.bodyLargeMedium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (meta.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: typography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                // Card F's trailing circle chevron.
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceSecondary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    // The chevron points the way the page reads.
                    Directionality.of(context) == TextDirection.rtl
                        ? Icons.chevron_left
                        : Icons.chevron_right,
                    size: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The booking's own vertical, as a glyph. Unknown verticals get the bag.
  IconData _tripIcon(String type) => switch (type) {
    'flight' => Icons.flight_takeoff_rounded,
    'hotel' => Icons.hotel_rounded,
    'car' => Icons.directions_car_rounded,
    'package' => Icons.card_travel_rounded,
    _ => Icons.luggage_rounded,
  };
}

/// The search field scrolls with the hero until it reaches the Home wordmark,
/// then stays pinned there while the discovery feed moves underneath it.
class _PinnedHomeSearchHeader extends SliverPersistentHeaderDelegate {
  const _PinnedHomeSearchHeader({required this.accentColor});

  final Color accentColor;

  @override
  double get minExtent => 64;

  @override
  double get maxExtent => 64;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => Material(
    color: AppColors.background,
    elevation: overlapsContent ? 2 : 0,
    child: SizedBox.expand(
      child: Center(
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.lg,
          ),
          child: HomeAiSearchField(accentColor: accentColor),
        ),
      ),
    ),
  );

  @override
  bool shouldRebuild(covariant _PinnedHomeSearchHeader oldDelegate) =>
      oldDelegate.accentColor != accentColor;
}

/// Home's top bar — the TokiGo wordmark on the leading edge, and on the
/// trailing edge the three destinations a traveller reaches from the app's
/// root: Bag (my trips), Notifications and the profile avatar.
///
/// The wordmark is the brand mark, so it is built ONLY through [AppWordmark]
/// (a hand-rolled pair of text halves would mirror into "GoToki" in Arabic).
/// It carries no greeting line: the logotype is Home's identity, and a
/// personalized greeting lives in the composition contract (home_greeting)
/// rather than occupying the page's loudest slot.
class _HomeTopBar extends ConsumerWidget {
  const _HomeTopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final typography = AppTypography.forLight();
    final bool hasCurrentTrips = ref
        .watch(bagControllerProvider)
        .currentTrips
        .isNotEmpty;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // 320pt phones are the narrowest target. The two 48pt actions and the
        // 56pt avatar take 152pt; give the wordmark only what is left and
        // scale it down rather than letting the row overflow.
        final double wordmarkWidth = (constraints.maxWidth - 160).clamp(
          0.0,
          172.0,
        );

        return Row(
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
                    child: AppWordmark(
                      style: typography.title.copyWith(
                        color: AppColors.wordmarkInk,
                      ),
                      goStyle: typography.title.copyWith(
                        color: AppColors.brandRed,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(),
            _TopAction(
              icon: Icons.luggage_outlined,
              semanticLabel: l10n.bag,
              color: hasCurrentTrips
                  ? AppColors.brandRed
                  : AppColors.textPrimary,
              onTap: () => context.push('/bag'),
            ),
            _TopAction(
              icon: Icons.notifications_none_rounded,
              semanticLabel: l10n.notifications,
              color: AppColors.textPrimary,
              onTap: () => context.push('/notifications'),
            ),
            const _HomeAvatar(),
          ],
        );
      },
    );
  }
}

/// A header icon action: 22px glyph inside the stock 48px touch target, so the
/// three trailing actions never crowd each other on a narrow phone.
class _TopAction extends StatelessWidget {
  const _TopAction({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            width: 42,
            height: 42,
            child: Center(child: Icon(icon, size: 25, color: color)),
          ),
        ),
      ),
    );
  }
}

/// Profile destination as a monochrome icon, without an avatar or tile.
class _HomeAvatar extends StatelessWidget {
  const _HomeAvatar();

  static const double size = 48;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Semantics(
      button: true,
      label: l10n.profile,
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: () => context.push('/profile'),
          child: SizedBox(
            width: size,
            height: size,
            child: const Center(
              child: Icon(
                Icons.person_outline_rounded,
                size: 25,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Recommended stays (card A) ───────────────────────────────────────────────

/// The loading state of the recommended-stays rail.
///
/// It mirrors the loaded layout — a horizontal rail of card-A skeletons at the
/// same width and height [HomeStaysCarousel] computes — so the feed does not
/// jump when the real stays land. The skeletons never scroll: pretending there
/// are pages to swipe before any stay exists would be a lie.
class _StaysSkeletonList extends StatelessWidget {
  const _StaysSkeletonList();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final double railWidth = MediaQuery.sizeOf(context).width;
    final double height = HomeStaysCarousel.railHeight(context);
    // The same page geometry the real rail uses: a 0.9 page plus the 0.1 gap
    // that shows up as the next card's peek.
    final double cardWidth = railWidth * _skeletonViewportFraction;
    final double gap = railWidth * (1 - _skeletonViewportFraction);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
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
        SizedBox(
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            itemCount: 2,
            separatorBuilder: (_, _) => SizedBox(width: gap),
            itemBuilder: (_, _) => SizedBox(
              width: cardWidth,
              child: OverlapStayCard.skeleton(
                margin: EdgeInsets.zero,
                semanticsLabel: l10n.hotelLoading,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Keep in step with [HomeStaysCarousel.viewportFraction]'s default.
  static const double _skeletonViewportFraction = 0.9;
}
