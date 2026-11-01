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
    _consumeScrollTarget();
    return Scaffold(
      backgroundColor: AppColors.background,
      // H1: pull-to-refresh removed by product decision — Home refreshes
      // prices/availability via live validation only (H2). The old
      // RefreshIndicator wrapper is gone; the SafeArea/Column tree is
      // unchanged.
      body: SafeArea(
        top: true,
        // `bottom: false` left the feed's last card under the Android
        // navigation bar (the pill it was written for is gone).
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
            Expanded(child: _buildBody(state, ref)),
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

  Widget _buildBody(HomeState state, WidgetRef ref) {
    // Owner decision (2026-10-24): clean home — only the chrome (pinned
    // search + nav buttons) renders by default. The mood feature was removed;
    // the mood-free feed below stays behind the [_homeFeedEnabled] flag.
    if (_homeFeedEnabled) {
      return _buildFeed(state, ref);
    }
    return CustomScrollView(
      controller: _feedController,
      slivers: _homeHeaderSlivers(ref),
    );
  }

  Widget _buildFeed(HomeState state, WidgetRef ref) {
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
        return CustomScrollView(
          controller: _feedController,
          slivers: <Widget>[
            ..._homeHeaderSlivers(ref),
            const SliverToBoxAdapter(child: _DiscoverSkeletonList()),
            const SliverToBoxAdapter(child: _StaysSkeletonList()),
          ],
        );
      case HomeStatus.success:
      case HomeStatus.partial:
      case HomeStatus.developmentPreview:
        return CustomScrollView(
          controller: _feedController,
          slivers: [
            ..._homeHeaderSlivers(ref),
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
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: HomeStaysCarousel(items: visibleHotels),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
            ],
            // Breathing room under the last card / section.
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
          ],
        );
      case HomeStatus.empty:
        return CustomScrollView(
          controller: _feedController,
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
                    child: AppWordmark(base: typography.title),
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

// ─── Discover (card D) ────────────────────────────────────────────────────────

/// The loading state of the Discover rail.
///
/// Discover leads the feed, so its placeholder leads the loading feed too: the
/// same page width and rail height [HomeStaysCarousel] computes, with a photo
/// block and the city-name line under it. One page only — the skeleton never
/// pretends there are cities to swipe before any has arrived.
class _DiscoverSkeletonList extends StatelessWidget {
  const _DiscoverSkeletonList();

  @override
  Widget build(BuildContext context) {
    final double railWidth = MediaQuery.sizeOf(context).width;
    final double cardWidth =
        railWidth * _StaysSkeletonList._skeletonViewportFraction;
    final double height = HomeStaysCarousel.railHeight(context);
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
        SizedBox(
          height: height,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: SizedBox(
              width: cardWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    child: ShimmerBox(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.md,
                      AppSpacing.md,
                    ),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: ShimmerBox(height: 20, width: 140),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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
    // Keep skeleton pages at the same width and photo ratio as the loaded rail.
    final double cardWidth = railWidth * _skeletonViewportFraction;
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
            padding: EdgeInsets.zero,
            itemCount: 2,
            separatorBuilder: (_, _) => const SizedBox.shrink(),
            itemBuilder: (_, _) => SizedBox(
              width: cardWidth,
              child: OverlapStayCard.skeleton(
                margin: EdgeInsets.zero,
                aspectRatio: HomeStaysCarousel.mediaAspectRatio,
                semanticsLabel: l10n.hotelLoading,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Keep in step with [HomeStaysCarousel.viewportFraction]'s default.
  static const double _skeletonViewportFraction = 0.8;
}
