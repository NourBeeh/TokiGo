import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wetravellers/app/widgets/home_nav_buttons.dart';
import 'package:wetravellers/core/theme/app_colors.dart';
import 'package:wetravellers/core/theme/app_radius.dart';
import 'package:wetravellers/core/theme/app_spacing.dart';
import 'package:wetravellers/core/theme/app_typography.dart';
import 'package:wetravellers/core/widgets/shimmer.dart';
import 'package:wetravellers/core/domain/models/home/home_item.dart';
import 'package:wetravellers/features/home/presentation/home_controller.dart';
import 'package:wetravellers/features/home/presentation/widgets/cached_hotel_image.dart';
import 'package:wetravellers/features/home/presentation/widgets/home_ai_search_field.dart';
import 'package:wetravellers/features/home/presentation/widgets/home_section.dart';
import 'package:wetravellers/features/home/providers/home_providers.dart';
import 'package:wetravellers/features/search/application/providers/offer_selection_provider.dart';
import 'package:wetravellers/features/bag/application/bag_controller.dart';
import 'package:wetravellers/features/bag/domain/trip.dart';
import 'package:wetravellers/l10n/app_localizations.dart';

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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homeControllerProvider);
    final bag = ref.watch(bagControllerProvider);
    return Scaffold(
      // H1: pull-to-refresh removed by product decision — Home refreshes
      // prices/availability via live validation only (H2). The old
      // RefreshIndicator wrapper is gone; the SafeArea/Column tree is
      // unchanged.
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Seamless merged header — present across every feed state.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const _HomeTopActions(),
                  const SizedBox(height: AppSpacing.md),
                  const _HomeWelcome(),
                  const SizedBox(height: AppSpacing.md),
                  // Smart AI search pill — opens the suggestion sheet.
                  const HomeAiSearchField(),
                  const SizedBox(height: AppSpacing.md),
                  // NAV — Home-centric navigation: the product verticals
                  // (flights/hotels/cars/packages) + compact Explore/Groups.
                  const HomeNavButtons(),
                ],
              ),
            ),
            Expanded(child: _buildBody(state, ref, bag)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(HomeState state, WidgetRef ref, BagState bag) {
    switch (state.status) {
      case HomeStatus.loading:
        return ListView.builder(
          padding: EdgeInsets.all(AppSpacing.lg),
          itemCount: 5,
          itemBuilder: (_, _) => const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.md),
            child: _SkeletonCard(height: 180),
          ),
        );
      case HomeStatus.success:
      case HomeStatus.partial:
      case HomeStatus.developmentPreview:
        return CustomScrollView(
          slivers: [
            // Continue planning — current trips from the unified Bag.
            if (bag.currentTrips.isNotEmpty)
              SliverToBoxAdapter(child: _ContinuePlanningRow(trips: bag.currentTrips)),
            // H1 — Nuitee-only Home loading rail: while real hotels are on
            // their way (dev-preview after an empty feed), show ONE skeleton
            // rail with the EXACT geometry of the real carousel (same title,
            // same 260px cards, same 220px rail height) so the transition to
            // live data has zero layout jump (Instagram-style placeholder).
            // Real hotels or composed sections replace it seamlessly below.
            if (state.recommendedHotels.isEmpty && state.sections.isEmpty)
              const SliverToBoxAdapter(child: _SkeletonRecommendedRail()),
            // Recommended hotels from Nuitee (real data).
            // Phase 1B: the composer already renders these as "Picked for
            // You" for authenticated users — show the standalone carousel
            // ONLY when no composed section carries that semantic id, so the
            // rail is never duplicated.
            if (state.recommendedHotels.isNotEmpty &&
                !_hasPickedForYou(state))
              SliverToBoxAdapter(
                child: _RecommendedHotelsCarousel(hotels: state.recommendedHotels),
              ),
            SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => HomeSectionWidget(
                    section: state.sections[index],
                    onFlightTap: (HomeItem flight) {
                      // Set selected offer and navigate to booking review
                      final metadata = flight.metadata;
                      ref.read(selectedOfferProvider.notifier).state = SelectedOffer(
                        offerId: flight.id,
                        providerId: metadata['providerId']?.toString() ?? '',
                        providerName: metadata['providerName']?.toString() ?? '',
                        price: flight.price ?? 0,
                        currency: flight.currency ?? 'USD',
                        searchId: '',
                        offerType: 'flight',
                      );
                      context.push('/booking/review');
                    },
                    onViewAllFlights: () {
                      context.push('/flights');
                    },
                    onFavorite: (flightId, value) {
                      // Handle wishlist change
                    },
                  ),
                  childCount: state.sections.length,
                ),
              ),
            ],
        );
      case HomeStatus.empty:
        // Honest no-content state (2026-09-08): the Nuitee-only Home feed is
        // empty and no hotel rail arrived — say so clearly with a retry,
        // never skeleton headings with no data.
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.explore_off_outlined,
                  size: 48, color: AppColors.textTertiary),
              const SizedBox(height: AppSpacing.md),
              Text(
                'No recommendations right now',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'We couldn\'t load hotels at the moment.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textTertiary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () =>
                    ref.read(homeControllerProvider.notifier).load(),
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      case HomeStatus.error:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(state.errorMessage ?? 'Something went wrong. Please try again.'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.read(homeControllerProvider.notifier).load(),
                child: const Text('Retry'),
              ),
            ],
          ),
        );
    }
  }

  /// True when a composed section already presents the recommended hotels
  /// (Phase 1B authenticated "Picked for You").
  bool _hasPickedForYou(HomeState state) {
    return state.sections.any(
      (s) =>
          s.metadata['semanticId'] == 'picked-for-you' &&
          s.items.isNotEmpty,
    );
  }
}

/// "Continue planning" — horizontal strip of current trips from the unified
/// Bag, shown above the feed so users resume where they left off.
class _ContinuePlanningRow extends StatelessWidget {
  const _ContinuePlanningRow({required this.trips});

  final List<TripSummary> trips;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Continue planning',
                  style: typography.title.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              InkWell(
                onTap: () => context.push('/bag'),
                child: Text(
                  AppLocalizations.of(context)!.viewAll,
                  style: typography.captionSemibold.copyWith(
                    color: AppColors.brand,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
            itemCount: trips.length,
            itemBuilder: (context, index) {
              final trip = trips[index];
              return _ContinueTripTile(trip: trip);
            },
          ),
        ),
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
    final dateFormat = (DateTime d) =>
        '${d.day}/${d.month}';
    return Material(
      color: AppColors.brandContainer,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/bag'),
        child: SizedBox(
          width: 240,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.brand,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.luggage_rounded,
                    size: 22,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        trip.destination,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: typography.bodyLargeMedium.copyWith(
                          color: AppColors.onBrandContainer,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        '${dateFormat(trip.startDate)} → ${dateFormat(trip.endDate)} · ${trip.status}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: typography.caption.copyWith(
                          color: AppColors.onBrandContainer.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Seamless merged header actions — the page flows directly under the status
/// bar with no fixed shell header. Bag (my trips), notifications and profile.
///
/// The TokiGo wordmark plays a one-shot "slide & merge" entrance — Toki from
/// the left, Go from the right, settling with an elastic bounce — then keeps
/// a permanent gentle heartbeat pulse on the red "Go" half only. A
/// [RepaintBoundary] isolates the per-frame pulse repaints inside the logo.
class _HomeTopActions extends StatefulWidget {
  const _HomeTopActions();

  @override
  State<_HomeTopActions> createState() => _HomeTopActionsState();
}

class _HomeTopActionsState extends State<_HomeTopActions>
    with TickerProviderStateMixin {
  /// Wordmark colours — "Toki" dark grey, "Go" bright red.
  static const Color _tokiColor = Color(0xFF2E2E2E);
  static const Color _goColor = Color(0xFFFF2D2D);

  late final AnimationController _entrance;
  late final AnimationController _pulse;
  late final CurvedAnimation _merge;
  late final CurvedAnimation _entranceFade;
  late final Animation<double> _heartbeat;

  /// Fraction of the entrance the wordmark holds still (hidden off-stage)
  /// before merging — built into the curve so no real Timer is pending (the
  /// route transition would otherwise swallow the animation).
  static const double _entranceHold = 0.25;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    _merge = CurvedAnimation(
      parent: _entrance,
      curve: const _DelayedCurve(Curves.elasticOut, _entranceHold),
    );
    _entranceFade = CurvedAnimation(
      parent: _entrance,
      curve: const _DelayedCurve(Curves.easeOut, _entranceHold),
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _heartbeat = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _entrance.dispose();
    _pulse.dispose();
    _merge.dispose();
    _entranceFade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: AppTypography.weightExtraBold,
        );
    return Row(
      children: [
        RepaintBoundary(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Toki — slides in from the left and settles with the merge.
              SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(-2.5, 0),
                  end: Offset.zero,
                ).animate(_merge),
                child: FadeTransition(
                  opacity: _entranceFade,
                  child: Text(
                    'Toki',
                    style: titleStyle?.copyWith(color: _tokiColor),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              // Go — slides in from the right, then heartbeats forever.
              SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(2.5, 0),
                  end: Offset.zero,
                ).animate(_merge),
                child: FadeTransition(
                  opacity: _entranceFade,
                  child: ScaleTransition(
                    scale: _heartbeat,
                    child: Text(
                      'Go',
                      style: titleStyle?.copyWith(color: _goColor),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        _TopAction(
          icon: Icons.luggage_outlined,
          tooltip: 'My trips',
          onTap: () => context.push('/bag'),
        ),
        _TopAction(
          icon: Icons.notifications_none_rounded,
          tooltip: 'Notifications',
          onTap: () => context.push('/notifications'),
        ),
        _TopAction(
          icon: Icons.person_outline_rounded,
          tooltip: 'Profile',
          onTap: () => context.push('/profile'),
        ),
      ],
    );
  }
}

/// Curve wrapper that holds the parent value at its starting point for the
/// first [hold] fraction of the animation, then remaps the remaining span onto
/// the wrapped curve — a pure-math settle delay with no pending Timer (safe
/// for widget tests' fake async).
class _DelayedCurve extends Curve {
  const _DelayedCurve(this.curve, this.hold);

  final Curve curve;
  final double hold;

  @override
  double transformInternal(double t) {
    if (t <= hold) return 0.0;
    return curve.transform((t - hold) / (1 - hold));
  }
}

class _TopAction extends StatelessWidget {
  const _TopAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 22, color: AppColors.textPrimary),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
    );
  }
}

/// Compact welcome line — the hero search card now lives on the Search tab;
/// Home leads directly with the discovery feed.
class _HomeWelcome extends ConsumerWidget {
  const _HomeWelcome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typography = AppTypography.forLight();
    // Phase 1B: the greeting comes from the composer's deterministic
    // contract (authenticated users see their display name). Falls back to
    // the l10n lines for the anonymous default, unchanged from Wave 0.
    final greeting = ref.watch(
      homeControllerProvider.select((state) => state.greeting),
    );
    final title = greeting?.title;
    final subtitle = greeting?.subtitle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title ?? AppLocalizations.of(context)!.homeWelcome,
          style: typography.headline.copyWith(color: AppColors.textPrimary),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          subtitle ?? AppLocalizations.of(context)!.homeWelcomeSub,
          style: typography.body.copyWith(color: AppColors.textTertiary),
        ),
      ],
    );
  }
}

/// H1 — Nuitee-only Home loading placeholder: ONE skeleton rail that mirrors
/// the EXACT geometry of [_RecommendedHotelsCarousel] — same title row, same
/// 220px rail height, same 260px card width, same image/text block — so the
/// swap from skeleton to real Nuitee data causes zero layout jump.
///
/// No fake travel data: pure shimmer shapes on the shared [ShimmerBox]
/// primitive (same as `_isSkeletonItem` cards — loading UI only).
class _SkeletonRecommendedRail extends StatelessWidget {
  const _SkeletonRecommendedRail();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Text(
            // Same fixed title as the real rail — stable across the swap.
            'Recommended for You',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: AppTypography.weightBold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        SizedBox(
          height: 220, // == _RecommendedHotelsCarousel rail height.
          child: ListView(
            // Never scrolls — pure placeholder, matches the real rail's
            // viewport while its cards stream in.
            physics: const NeverScrollableScrollPhysics(),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            children: const <Widget>[
              _SkeletonHotelCard(),
              SizedBox(width: AppSpacing.md), // == separatorBuilder gap.
              _SkeletonHotelCard(),
              SizedBox(width: AppSpacing.md),
              _SkeletonHotelCard(),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

/// One skeleton hotel card — 260px wide like [_HotelCard], image block 120px
/// like the real card, then two text shimmer rows.
class _SkeletonHotelCard extends StatelessWidget {
  const _SkeletonHotelCard();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260, // == _HotelCard width.
      child: Card(
        elevation: 2, // == _HotelCard elevation.
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ShimmerBox(height: 120, width: double.infinity),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const <Widget>[
                    ShimmerBox(height: 14, width: 180), // title row.
                    SizedBox(height: 6),
                    ShimmerBox(height: 12, width: 120), // subtitle row.
                    Spacer(),
                    ShimmerBox(height: 12, width: 64), // price row.
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal carousel of recommended hotels sourced from Nuitee.
class _RecommendedHotelsCarousel extends StatelessWidget {
  const _RecommendedHotelsCarousel({required this.hotels});

  final List<HomeItem> hotels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Text(
            'Recommended for You',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: AppTypography.weightBold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            itemCount: hotels.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) {
              final hotel = hotels[index];
              return _HotelCard(hotel: hotel);
            },
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

/// Scroll-fix 2026-09-08: the card is a StatefulWidget with
/// [AutomaticKeepAliveClientMixin] so the ListView keeps its state alive
/// while scrolled off-screen — no re-load flash on scroll-back. The rail
/// is bounded (max 40 items from the repository), so keep-alive memory is
/// bounded by the same cap.
class _HotelCard extends ConsumerStatefulWidget {
  const _HotelCard({required this.hotel});

  final HomeItem hotel;

  @override
  ConsumerState<_HotelCard> createState() => _HotelCardState();
}

class _HotelCardState extends ConsumerState<_HotelCard>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // KeepAlive contract.
    final theme = Theme.of(context);
    final hotel = widget.hotel;
    // H3: hotel images load through the Hive-backed cache — a cached photo
    // renders instantly on cold start without any network call, and P2
    // decode sizing keeps memory tiny. The session memory layer renders
    // scroll-back photos in the same frame (no shimmer flash).
    final imageCache = ref.watch(hotelImageCacheProvider);
    final memoryCache = ref.watch(hotelImageMemoryCacheProvider);
    return SizedBox(
      width: 260,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hotel.imageUrl != null && hotel.imageUrl!.isNotEmpty)
              CachedHotelImage(
                url: hotel.imageUrl!,
                height: 120,
                width: double.infinity,
                cache: imageCache,
                memoryCache: memoryCache,
              )
            else
              Container(
                height: 120,
                color: AppColors.surfaceTertiary,
                child: const Icon(Icons.hotel_outlined, size: 32),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hotel.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: AppTypography.weightSemibold,
                      ),
                    ),
                    if (hotel.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        hotel.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                    const Spacer(),
                    Row(
                      children: [
                        if (hotel.rating != null) ...[
                          Icon(Icons.star_rounded, size: 16, color: Colors.amber[700]),
                          const SizedBox(width: 2),
                          Text(
                            hotel.rating!.toStringAsFixed(1),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: AppTypography.weightSemibold,
                            ),
                          ),
                          if (hotel.reviewCount != null) ...[
                            const SizedBox(width: 4),
                            Text(
                              '(${hotel.reviewCount})',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ],
                        const Spacer(),
                        if (hotel.price != null)
                          Text(
                            '${hotel.currency ?? '\$'}${hotel.price!.toStringAsFixed(0)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: AppTypography.weightBold,
                              color: AppColors.brand,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Skeleton ──────────────────────────────────────────────────────────────────

/// Page-level loading placeholder while the Home feed loads. Uses the shared
/// [ShimmerBox] primitive — no hardcoded greys, theme-aware in both modes.
class _SkeletonCard extends StatelessWidget {
  final double height;
  const _SkeletonCard({required this.height});

  @override
  Widget build(BuildContext context) {
    return ShimmerBox(
      height: height,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Flexible image placeholder — absorbs height changes so the
          // fixed text rows below can never overflow the card.
          const Expanded(child: ShimmerBox(width: double.infinity)),
          const SizedBox(height: AppSpacing.sm),
          const ShimmerBox(height: 14, width: 180),
          const SizedBox(height: AppSpacing.xs),
          const ShimmerBox(height: 12, width: 120),
        ],
      ),
    );
  }
}
