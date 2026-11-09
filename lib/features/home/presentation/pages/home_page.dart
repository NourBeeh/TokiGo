import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/ui/app_message_state.dart';
import 'package:tokigo/core/widgets/section_header.dart';
import 'package:tokigo/core/widgets/shimmer.dart';
import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_section.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/features/home/presentation/home_controller.dart';
import 'package:tokigo/features/home/presentation/home_design_tokens.dart';
import 'package:tokigo/features/home/presentation/widgets/destination_cover_flow_carousel.dart';
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
    _consumeScrollTarget();
    return Scaffold(
      backgroundColor: HomeDesignTokens.backgroundOf(context),
      // H1: pull-to-refresh removed by product decision — Home refreshes
      // prices/availability via live validation only (H2).
      //
      // The keyboard resizes this body; the AI composer now lives in the
      // pinned shell chrome above it.
      body: SafeArea(
        top: true,
        // The feed stays edge-to-edge under the navigation bar.
        bottom: false,
        child: CustomScrollView(
          controller: _feedController,
          slivers: <Widget>[
            ..._feedSlivers(state, ref),
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

  /// The dashboard's feed content as slivers.
  ///
  /// The header, quick-action row and AI composer are provided by the
  /// persistent shell chrome above this scroll view. This scroll view only
  /// carries the feed content.
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

/// Centers an honest state (empty / offline) in the feed's remaining
/// viewport, beneath the pinned shell chrome.
///
/// The state scrolls only when its content genuinely cannot fit — a very
/// small screen or a large system type scale — so the message is never
/// clipped and never overlaps the pinned chrome.
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