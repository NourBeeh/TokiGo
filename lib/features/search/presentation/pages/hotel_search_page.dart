import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tokigo/core/auth/auth_provider.dart';
import 'package:tokigo/core/domain/models/offers/hotel_offer.dart';
import 'package:tokigo/core/domain/models/search/hotel_search_params.dart';
import 'package:tokigo/core/memory/explicit_preference_signal.dart';
import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_elevation.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/ui/localized_date.dart';
import 'package:tokigo/core/widgets/search_filter_chips.dart';
import 'package:tokigo/features/home/providers/home_providers.dart';
import 'package:tokigo/features/profile/application/wishlist_controller.dart';
import 'package:tokigo/features/search/application/controllers/hotel_search_controller.dart';
import 'package:tokigo/features/search/application/providers/hotel_car_providers.dart';
import 'package:tokigo/features/search/application/providers/search_view_providers.dart';
import 'package:tokigo/features/search/application/search_facets.dart';
import 'package:tokigo/features/search/application/search_results_processing.dart';
import 'package:tokigo/features/search/domain/search_context.dart';
import 'package:tokigo/features/search/domain/search_filters.dart';
import 'package:tokigo/features/search/domain/search_view_mode.dart';
import 'package:tokigo/features/search/domain/sort_option.dart';
import 'package:tokigo/features/search/presentation/widgets/destination_picker_sheet.dart';
import 'package:tokigo/features/search/presentation/widgets/filter_panel.dart';
import 'package:tokigo/features/search/presentation/widgets/hotel_overlap_card.dart';
import 'package:tokigo/features/search/presentation/widgets/search_map_placeholder.dart';
import 'package:tokigo/features/search/presentation/widgets/search_scaffold.dart';
import 'package:tokigo/features/search/presentation/widgets/search_states_view.dart';
import 'package:tokigo/features/search/presentation/widgets/search_view_toggle.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Phase 3C — per-vertical sort/filters state (hotels).
final hotelSortProvider = StateProvider<SortOption>(
  (ref) => SortOption.recommended,
);
final hotelFiltersProvider = StateProvider<SearchFilters>(
  (ref) => const SearchFilters(),
);

/// The hotels results-bar sorts. The provider's own ordering is "recommended",
/// so the reference board's "Price" chip is [cheapest].
enum _HotelSort { recommended, cheapest, topRated }

/// Hotel-class quick filters — the results bar's "All · 5★ · 4★ · 3★" group.
/// These filter the hotel's own star class (provider classification, 1-5), not
/// the guest review score — `null` is "All" (no class constraint).
const List<int?> _classChips = <int?>[null, 5, 4, 3];

/// DS-3 — the hotel results page on reference A's anatomy.
///
/// Once results exist the form collapses into the reference's **floating
/// summary card** (place + dates/guests + filter icon); tapping it expands the
/// form again. Below it: the class pill row, a results bar with the real count
/// and the sort control (decision D5), then card A for every stay.
class HotelSearchPage extends ConsumerStatefulWidget {
  const HotelSearchPage({super.key});

  @override
  ConsumerState<HotelSearchPage> createState() => _HotelSearchPageState();
}

class _HotelSearchPageState extends ConsumerState<HotelSearchPage> {
  String _destination = '';
  DateTime _checkIn = DateTime.now().add(const Duration(days: 7));
  DateTime _checkOut = DateTime.now().add(const Duration(days: 10));
  int _guests = 2;
  int _rooms = 1;

  _HotelSort _sort = _HotelSort.recommended;

  /// True while the user is editing a completed search: the summary card has
  /// been tapped open, so the full form shows again until the next search.
  bool _editing = false;

  HotelSearchParams? _lastParams;
  bool _prefilled = false;
  String? _destinationCountryCode;
  String? _marketCountryCode;

  /// Phase 4C — the traveller's own budget (from the explicit AI memory)
  /// with its currency. Null when there is no budget, when the traveller
  /// opted out, or when the budget was stated WITHOUT a currency: the app
  /// never converts prices, so such a budget cannot filter anything.
  ExplicitBudgetRange? _explicitBudget;

  /// True when the traveller removed the budget cap for this session. The
  /// memory itself is never touched — the chip is a view over it.
  bool _budgetRemoved = false;

  @override
  void initState() {
    super.initState();
    _loadExplicitBudget();
  }

  /// Reads the explicit budget once. A failure is silent on purpose: a
  /// missing budget must never break the search page.
  Future<void> _loadExplicitBudget() async {
    if (ref.read(authUserProvider) == null) return;
    try {
      final profile = await ref.read(profileRepositoryProvider).fetchProfile();
      if (!mounted) return;
      final budget = profile?.explicitPreferences?.budget;
      if (budget == null || budget.max == null) {
        return;
      }
      // A budget that arrived with the search context wins (it is the one
      // the traveller was looking at when they opened the page).
      if (_explicitBudget != null) return;
      setState(() => _explicitBudget = budget);
    } catch (_) {
      // No budget, no chip — the page keeps working.
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prefilled) return;
    _prefilled = true;
    // Pre-fill from navigation extras — must read the router AFTER
    // initState completes (inherited widgets are legal here).
    final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
    if (extra != null) {
      _destination = extra['city']?.toString() ?? '';
      _checkIn = extra['checkIn'] as DateTime? ?? _checkIn;
      _checkOut = extra['checkOut'] as DateTime? ?? _checkOut;
    }
    // Phase 4A — the traveller's travel context: the mood's real city
    // prefills the destination (the traveller sees it and can change it).
    final searchContext = SearchContext.fromMap(
      extra?['context'] as Map<String, dynamic>?,
    );
    if (_destination.isEmpty) {
      final city = searchContext?.destination;
      if (city != null && city.isNotEmpty) _destination = city;
    }
    if (searchContext?.budget != null) {
      _explicitBudget = searchContext!.budget;
    }
    _destinationCountryCode =
        _destination.trim() == searchContext?.destination?.trim()
        ? searchContext?.destinationCountryCode
        : null;
    _marketCountryCode = searchContext?.countryCode;
  }

  int get _nights => _checkOut.difference(_checkIn).inDays.abs().clamp(1, 999);

  /// The header line states a destination only once one produced the results
  /// on screen; before that it summarizes the form itself.
  String _summary(AppLocalizations l10n) {
    final searched = _lastParams;
    final nights = searched != null
        ? searched.checkOut.difference(searched.checkIn).inDays.abs()
        : _nights;
    return <String>[
      if (searched != null && searched.destination.isNotEmpty)
        searched.destination,
      l10n.hotelNightsCount(nights),
      l10n.hotelGuestsCount(searched?.adults ?? _guests),
      l10n.hotelRoomsCount(searched?.rooms ?? _rooms),
    ].join(' · ');
  }

  void _pickDestination() {
    showPickerSheet(
      context,
      title: AppLocalizations.of(context)!.searchHint,
      entries: kCities,
      onSelected: (entry) => setState(() {
        _destination = entry.name;
        _destinationCountryCode = entry.countryCode;
      }),
    );
  }

  Future<void> _pickCheckIn() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _checkIn,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) {
      setState(() {
        _checkIn = d;
        // Cross-validation: checkout must stay after checkin.
        if (_checkOut.isBefore(_checkIn)) {
          _checkOut = _checkIn.add(const Duration(days: 3));
        }
      });
    }
  }

  Future<void> _pickCheckOut() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _checkOut,
      firstDate: _checkIn.add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _checkOut = d);
  }

  void _search() {
    if (_destination.trim().isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.hotelDestinationRequired),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final params = HotelSearchParams(
      destination: _destination.trim(),
      checkIn: _checkIn,
      checkOut: _checkOut,
      rooms: _rooms,
      adults: _guests,
      countryCode: _destinationCountryCode,
      market: _marketCountryCode,
    );
    setState(() => _editing = false);
    _lastParams = params;
    ref.read(hotelSearchControllerProvider.notifier).search(params);
  }

  void _retry() {
    final params = _lastParams;
    if (params != null) {
      ref.read(hotelSearchControllerProvider.notifier).search(params);
    }
  }

  SortOption get _sortOption => switch (_sort) {
    _HotelSort.recommended => SortOption.recommended,
    _HotelSort.cheapest => SortOption.priceLowHigh,
    _HotelSort.topRated => SortOption.rating,
  };

  void _selectSort(_HotelSort sort) {
    setState(() => _sort = sort);
    ref.read(hotelSortProvider.notifier).state = _sortOption;
  }

  /// Quick class filter — cleared by the "All" chip (null).
  void _setMinStars(int? stars) {
    final filters = ref.read(hotelFiltersProvider);
    ref.read(hotelFiltersProvider.notifier).state = filters.withMinStars(stars);
  }

  void _showFilters() {
    final results = ref.read(hotelSearchControllerProvider).results;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FilterPanel(
        filters: ref.read(hotelFiltersProvider),
        onChanged: (f) => ref.read(hotelFiltersProvider.notifier).state = f,
        // Only what these results really contain.
        priceFacet: priceFacetOf(results),
        amenities: amenitiesOf(results),
        showStars: true,
        showRating: true,
        showAmenities: true,
      ),
    );
  }

  String _sortLabel(AppLocalizations l10n, _HotelSort sort) => switch (sort) {
    _HotelSort.recommended => l10n.sortRecommended,
    _HotelSort.cheapest => l10n.sortCheapest,
    _HotelSort.topRated => l10n.hotelSortTopRated,
  };

  /// Decision D5 — the sort lives in its own bar above the results, so it is
  /// visible next to the count without stealing the header's single action.
  Future<void> _showSortSheet() async {
    final l10n = AppLocalizations.of(context)!;
    final typography = AppTypography.forLight();
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadiusDirectional.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Text(
                l10n.sortBy,
                style: typography.title.copyWith(color: AppColors.textPrimary),
              ),
            ),
            for (final _HotelSort sort in _HotelSort.values)
              InkWell(
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _selectSort(sort);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          _sortLabel(l10n, sort),
                          style: typography.body.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: sort == _sort
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (sort == _sort)
                        const Icon(
                          Icons.check_rounded,
                          size: 20,
                          color: AppColors.brand,
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(hotelSearchControllerProvider);
    final filters = _effectiveFilters(
      ref.watch(hotelFiltersProvider),
      state.results,
    );
    final hasResults =
        state.status == HotelSearchStatus.success && state.results.isNotEmpty;
    final showSummary = hasResults && !_editing;

    // Long lists render through a lazy sliver: a [Column] would build every
    // card (and download every full-size photo) at once, which the Android
    // Low Memory Killer treats as an app to reclaim. Small lists keep the
    // eager path — there is nothing to gain and the whole page stays
    // assertable in one frame.
    final bool lazyResults =
        state.status == HotelSearchStatus.success &&
        ref.watch(searchViewModeProvider) == SearchViewMode.list &&
        _visibleResults(state, filters).length > kSearchLazyResultsThreshold;

    return SearchScaffold(
      title: l10n.searchHotels,
      subtitle: _summary(l10n),
      headerActions: const SearchViewToggle(),
      // Collapsed after a search: the reference's floating summary card.
      form: showSummary ? _buildSummaryCard(l10n) : _buildForm(l10n),
      bottomContent: hasResults ? _buildChipRow(l10n, filters) : null,
      body: lazyResults
          ? const SizedBox.shrink()
          : _buildResults(state, l10n, filters),
      bodySlivers: lazyResults
          ? _buildResultSlivers(state, l10n, filters)
          : null,
    );
  }

  /// Phase 4C — the filters actually applied: the traveller's own filter
  /// state plus their explicit budget cap, unless they removed the chip for
  /// this session. A budget without a currency never filters anything (the
  /// app never converts a price).
  SearchFilters _effectiveFilters(
    SearchFilters base,
    List<HotelOffer> results,
  ) {
    final budget = _explicitBudget;
    if (budget == null || budget.max == null || budget.currency == null) {
      return base;
    }
    if (_budgetRemoved) return base;
    return base.copyWith(
      budgetMax: budget.max,
      budgetCurrency: budget.currency,
    );
  }

  /// Filter + sort exactly once per build, shared by the eager and lazy
  /// render paths so they can never disagree about what is visible.
  List<HotelOffer> _visibleResults(
    HotelSearchState state,
    SearchFilters filters,
  ) {
    if (state.status != HotelSearchStatus.success) return const <HotelOffer>[];
    return sortHotelResults(
      applyHotelFilters(state.results, filters),
      ref.read(hotelSortProvider),
    );
  }

  // ── Summary card (results state) ────────────────────────────────────────

  Widget _buildSummaryCard(AppLocalizations l10n) {
    final typography = AppTypography.forLight();
    final params = _lastParams;
    final String place = (params?.destination.isNotEmpty ?? false)
        ? params!.destination
        : _destination;
    final DateTime checkIn = params?.checkIn ?? _checkIn;
    final DateTime checkOut = params?.checkOut ?? _checkOut;
    // MaterialLocalizations carries the month names for the active language —
    // the same source the form fields read, only in its short form so the
    // summary stays one line at 320pt.
    final ml = MaterialLocalizations.of(context);
    final String dates =
        '${ml.formatShortMonthDay(checkIn)} – ${ml.formatShortMonthDay(checkOut)}';
    final String meta =
        '$dates · ${l10n.hotelGuestsCount(params?.adults ?? _guests)}';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgBorder,
        boxShadow: AppElevation.shadow(
          background: AppColors.surface,
          level: AppElevation.sm,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.lgBorder,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => setState(() => _editing = true),
          child: Semantics(
            button: true,
            label: '${l10n.editSearch}: $place, $meta',
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: AppColors.textPrimary,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          place.isEmpty ? _summary(l10n) : place,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: typography.bodyLargeMedium.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
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
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton(
                    onPressed: _showFilters,
                    tooltip: l10n.filtersAction,
                    iconSize: 20,
                    color: AppColors.textPrimary,
                    icon: const Icon(Icons.tune_rounded),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Filter chips ────────────────────────────────────────────────────────

  Widget _buildChipRow(AppLocalizations l10n, SearchFilters filters) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
      child: SearchFilterChips(
        chips: <SearchFilterChipData>[
          for (final int? stars in _classChips)
            SearchFilterChipData(
              label: stars == null ? l10n.hotelRatingAll : '$stars',
              semanticLabel: stars == null
                  ? l10n.hotelRatingAll
                  : l10n.hotelStarClass('$stars'),
              icon: stars == null ? null : Icons.star_rounded,
              selected: filters.minStars == stars,
              onTap: () => _setMinStars(stars),
            ),
          if (_buildBudgetChip(l10n) != null) _buildBudgetChip(l10n)!,
        ],
      ),
    );
  }

  /// Phase 4C — the traveller's own budget as a VISIBLE, cancellable chip.
  ///
  /// It is never a hidden filter. When the listed prices are not in the
  /// budget's currency the cap cannot be applied (the app never converts a
  /// price), and the chip says exactly that instead of emptying the list.
  SearchFilterChipData? _buildBudgetChip(AppLocalizations l10n) {
    final budget = _explicitBudget;
    if (budget == null || budget.max == null) {
      return null;
    }
    if (budget.currency == null) {
      if (_budgetRemoved) return null;
      return SearchFilterChipData(
        label: l10n.searchBudgetNoCurrency(_numText(budget.max!)),
        semanticLabel: l10n.searchBudgetRemove,
        icon: Icons.savings_outlined,
        selected: false,
        onTap: () => setState(() => _budgetRemoved = true),
      );
    }
    final currency = budget.currency!;
    final label = l10n.searchBudgetCap(_numText(budget.max!), currency);
    final results = ref.read(hotelSearchControllerProvider).results;
    final pricedInBudgetCurrency = results.any(
      (offer) => offer.currency == currency,
    );
    if (!pricedInBudgetCurrency) {
      return SearchFilterChipData(
        label: label,
        semanticLabel: l10n.searchBudgetNotApplicable(currency),
        selected: false,
      );
    }
    final removed = _budgetRemoved;
    return SearchFilterChipData(
      label: label,
      semanticLabel: removed ? l10n.searchBudgetApply : l10n.searchBudgetRemove,
      icon: Icons.savings_outlined,
      selected: !removed,
      onTap: () => setState(() => _budgetRemoved = !_budgetRemoved),
    );
  }

  /// A number without a trailing ".0" — the provider's own money format.
  static String _numText(num n) {
    final d = n.toDouble();
    return d == d.roundToDouble() ? d.round().toString() : d.toString();
  }

  // ── Results bar (count + sort + filters) ────────────────────────────────

  Widget _buildResultsBar(
    AppLocalizations l10n,
    int count,
    SearchFilters filters,
  ) {
    final typography = AppTypography.forLight();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              l10n.hotelResultsCount(count),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: typography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          _ResultsBarAction(
            icon: Icons.swap_vert_rounded,
            label: _sortLabel(l10n, _sort),
            onTap: _showSortSheet,
          ),
          const SizedBox(width: AppSpacing.xs),
          _ResultsBarAction(
            icon: Icons.tune_rounded,
            onTap: _showFilters,
            semanticLabel: l10n.filtersAction,
            active: !filters.isEmpty,
          ),
        ],
      ),
    );
  }

  // ── Form ────────────────────────────────────────────────────────────────
  Widget _buildForm(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SearchFieldInput(
          icon: Icons.location_on_outlined,
          label: l10n.hotelDestination,
          hint: l10n.searchHint,
          value: _destination.isEmpty ? null : _destination,
          readOnly: true,
          onTap: _pickDestination,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: SearchFieldInput(
                icon: Icons.calendar_today_outlined,
                label: l10n.offerCheckIn,
                hint: l10n.pickDateHint,
                // Read in the active language on every build.
                value: localizedMediumDate(context, _checkIn),
                readOnly: true,
                onTap: _pickCheckIn,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: SearchFieldInput(
                icon: Icons.calendar_today_outlined,
                label: l10n.offerCheckOut,
                hint: l10n.pickDateHint,
                value: localizedMediumDate(context, _checkOut),
                readOnly: true,
                onTap: _pickCheckOut,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _buildGuestsRow(l10n),
        const SizedBox(height: AppSpacing.md),
        _buildRoomsRow(l10n),
        const SizedBox(height: AppSpacing.lg),
        SearchSubmitButton(label: l10n.findHotels, onPressed: _search),
      ],
    );
  }

  Widget _buildGuestsRow(AppLocalizations l10n) {
    return SearchStepperInput(
      icon: Icons.people_outline_rounded,
      label: l10n.hotelGuestsCount(_guests),
      count: _guests,
      onDecrement: () => setState(() {
        if (_guests > 1) _guests--;
      }),
      onIncrement: () => setState(() {
        if (_guests < 12) _guests++;
      }),
    );
  }

  Widget _buildRoomsRow(AppLocalizations l10n) {
    return SearchStepperInput(
      icon: Icons.meeting_room_outlined,
      label: l10n.hotelRoomsCount(_rooms),
      count: _rooms,
      onDecrement: () => setState(() {
        if (_rooms > 1) _rooms--;
      }),
      onIncrement: () => setState(() {
        if (_rooms < 8) _rooms++;
      }),
    );
  }

  // ── Results ─────────────────────────────────────────────────────────────
  Widget _buildResults(
    HotelSearchState state,
    AppLocalizations l10n,
    SearchFilters filters,
  ) {
    final viewMode = ref.watch(searchViewModeProvider);
    final List<HotelOffer> wishlist = ref.watch(wishlistProvider);

    switch (state.status) {
      case HotelSearchStatus.idle:
        return SearchStatesView.idle(
          icon: Icons.hotel_outlined,
          title: l10n.hotelIdleTitle,
          body: l10n.hotelIdleBody,
        );
      case HotelSearchStatus.loading:
        return const SearchStatesView.loading(
          skeleton: Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: HotelOverlapCard.loading(),
          ),
        );
      case HotelSearchStatus.success:
        if (viewMode == SearchViewMode.map) {
          return const SearchMapPlaceholder();
        }
        // Phase 3C — provider-safe post-processing: filter then sort the
        // returned list (deterministic; the provider order stays the
        // "recommended" order).
        final visible = _visibleResults(state, filters);
        // Filters that hide everything surface an explicit no-match state
        // (never a blank screen) while the raw result list stays intact.
        if (visible.isEmpty && state.results.isNotEmpty) {
          return SearchStatesView.empty(
            icon: Icons.filter_alt_off_outlined,
            title: l10n.searchFilteredEmptyTitle,
            body: l10n.searchFilteredEmptyBody,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _buildResultsBar(l10n, visible.length, filters),
            for (final offer in visible) _buildHotelCard(offer, wishlist),
            _buildResultsFooter(),
          ],
        );
      case HotelSearchStatus.empty:
        return SearchStatesView.empty(
          icon: Icons.search_off_rounded,
          title: l10n.hotelEmptyTitle,
          body: l10n.hotelEmptyBody,
        );
      case HotelSearchStatus.error:
        return SearchStatesView.error(
          title: l10n.searchErrorTitle,
          body: state.errorMessage ?? l10n.searchErrorBody,
          onAction: _retry,
        );
    }
  }

  /// One result card — shared by the eager list and the lazy sliver so both
  /// paths always draw the same card with the same wishlist state.
  Widget _buildHotelCard(HotelOffer offer, List<HotelOffer> wishlist) {
    return HotelOverlapCard(
      offer: offer,
      onTap: () => context.push('/offer-details', extra: offer),
      // The wishlist's source is the heart on the product.
      isFavorite: wishlist.any((HotelOffer saved) => saved.id == offer.id),
      onFavorite: (bool saved) =>
          ref.read(wishlistProvider.notifier).setSaved(offer, saved),
    );
  }

  /// The quiet Discover hand-off under the last result.
  Widget _buildResultsFooter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: AppSpacing.lg),
        // DS-6 — Discover is a Home section now: this hands the traveller
        // to it instead of to a page that no longer exists.
        _DiscoverMoreButton(
          onTap: () {
            ref.read(homeScrollTargetProvider.notifier).state =
                HomeScrollTarget.discover;
            context.go('/');
          },
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  /// The lazy render path for a long result list: header bar, a
  /// `SliverList.builder` that only builds cards as they enter the viewport,
  /// then the footer. Off-screen photos are never fetched, which keeps a
  /// 40+ stay search inside the memory budget of a low-RAM phone.
  List<Widget> _buildResultSlivers(
    HotelSearchState state,
    AppLocalizations l10n,
    SearchFilters filters,
  ) {
    final visible = _visibleResults(state, filters);
    final List<HotelOffer> wishlist = ref.watch(wishlistProvider);

    return <Widget>[
      SliverToBoxAdapter(
        child: _buildResultsBar(l10n, visible.length, filters),
      ),
      SliverList.builder(
        itemCount: visible.length,
        itemBuilder: (context, index) =>
            _buildHotelCard(visible[index], wishlist),
      ),
      SliverToBoxAdapter(child: _buildResultsFooter()),
    ];
  }
}

/// One compact text action in the results bar (sort / filters).
class _ResultsBarAction extends StatelessWidget {
  const _ResultsBarAction({
    required this.icon,
    required this.onTap,
    this.label,
    this.semanticLabel,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? label;
  final String? semanticLabel;

  /// Draws the brand dot — filters are applied.
  final bool active;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final String? label = this.label;
    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.pillBorder,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 18, color: AppColors.textPrimary),
                if (label != null) ...<Widget>[
                  const SizedBox(width: AppSpacing.xxs),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: typography.captionSemibold.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
                if (active) ...<Widget>[
                  const SizedBox(width: AppSpacing.xxs),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.brand,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Discover more" — the quiet exit from the results list into Home's
/// Discover section (DS-6). Not a CTA: it must not compete with a stay card.
class _DiscoverMoreButton extends StatelessWidget {
  const _DiscoverMoreButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: TextButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.explore_outlined, size: 20),
        label: Text(l10n.discoverMore),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.brand,
          minimumSize: const Size(48, 48),
          textStyle: typography.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
