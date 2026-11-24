import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/app/widgets/app_chrome.dart';
import 'package:tokigo/app/widgets/home_nav_buttons.dart';
import 'package:tokigo/core/geo/city_providers.dart';
import 'package:tokigo/core/geo/city_selection.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_section.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/features/home/domain/home_action.dart';
import 'package:tokigo/features/home/domain/explore_home_section.dart';
import 'package:tokigo/features/home/domain/promotional_stay.dart';
import 'package:tokigo/features/home/presentation/home_card_dimensions.dart';
import 'package:tokigo/features/home/presentation/home_design_tokens.dart';
import 'package:tokigo/features/home/presentation/widgets/home_top_bar.dart';
import 'package:tokigo/features/home/presentation/widgets/location_permission_card.dart';
import 'package:tokigo/features/home/presentation/widgets/nearby_stays_section.dart';
import 'package:tokigo/features/home/presentation/widgets/home_section.dart';
import 'package:tokigo/features/home/providers/home_providers.dart';
import 'package:tokigo/features/search/application/providers/offer_selection_provider.dart';
import 'package:tokigo/l10n/app_localizations.dart';
import 'package:tokigo/shared/providers/locale_provider.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  /// The feed's scroll position, used to honour a [HomeScrollTarget].
  final ScrollController _feedController = ScrollController();

  /// Anchors the Discover section so another page can land on it.
  final GlobalKey _discoverKey = GlobalKey();
  bool _scrollScheduled = false;

  /// The original composer's draft, lifted so it survives the header being
  /// scrolled out of the viewport and back.
  final TextEditingController _composerTextController = TextEditingController();

  /// Background city detection runs once, after the persisted selection has
  /// been restored.
  bool _detectionStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _bootstrapCityDetection();
    });
  }

  /// One background detection pass. Never prompts, never blocks, and never
  /// replaces a manual city (the selection controller enforces that).
  void _bootstrapCityDetection() {
    if (_detectionStarted) return;
    final CitySelectionState selection = ref.read(citySelectionProvider);
    if (selection.status == CitySelectionStatus.loading) return;
    _detectionStarted = true;
    if (selection.isManual) return;
    ref.read(cityDetectionServiceProvider).detectIfNeeded();
  }

  @override
  void dispose() {
    _composerTextController.dispose();
    _feedController.dispose();
    super.dispose();
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
        ref.read(nearbyStaysControllerProvider.notifier).refresh();
      }
    });
    // A currency change re-prices the promotional rail in the new currency.
    ref.listen(currencyProvider, (previous, next) {
      if (previous != next) {
        ref.read(nearbyStaysControllerProvider.notifier).refresh();
      }
    });
    // Restored or newly detected city: start detection once it is ready and
    // refresh the nearby rail whenever the effective city actually changes.
    ref.listen(citySelectionProvider, (previous, next) {
      _bootstrapCityDetection();
      if (previous?.effective?.city.id != next.effective?.city.id) {
        ref.read(nearbyStaysControllerProvider.notifier).refresh();
      }
    });
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
              controller: _feedController,
              slivers: <Widget>[
                // The original Home header — wordmark, AI composer and
                // navigation — is part of the scrollable content. It leaves the
                // viewport naturally as the feed scrolls.
                SliverToBoxAdapter(child: _buildOriginalHeader()),
                ..._feedSlivers(ref),
              ],
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

  /// The service navigation rail. It scrolls away with the feed.
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
    );
  }

  /// The sections Home renders: the bundled Explore catalog.
  ///
  /// Home no longer reads the backend Home feed. The backend's destination
  /// cards are still available to the Explore Cities page via
  /// [ExploreFeedController]; Home itself renders the on-device catalog.
  List<HomeSection> _exploreSections() => <HomeSection>[buildHomeExploreSection()];

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

  /// The dashboard's feed content as slivers.
  ///
  /// The original header (wordmark, AI composer and navigation) scrolls as
  /// the first section of this same scroll view. This method only carries the
  /// feed content that follows it.
  List<Widget> _feedSlivers(WidgetRef ref) {
    final List<HomeSection> visibleSections = _exploreSections();
    final nearby = ref.watch(nearbyStaysControllerProvider);
    // Home has exactly two content sections: Explore and Nearby Stays.
    // Explore is the on-device catalog; Nearby Stays is the promotional rail
    // backed by genuine geographic discovery. The old country-wide
    // recommendation rail is no longer rendered.
    return <Widget>[
      // Contextual, dismissible location explainer. It renders nothing when
      // permission is granted, unavailable, or a manual city already exists.
      const SliverToBoxAdapter(child: LocationPermissionCard()),
      ..._exploreRailSlivers(visibleSections),
      SliverToBoxAdapter(
        child: NearbyStaysSection(
          state: nearby,
          onStayTap: (PromotionalStay stay) =>
              context.push('/nearby-hotel', extra: stay),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
    ];
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
