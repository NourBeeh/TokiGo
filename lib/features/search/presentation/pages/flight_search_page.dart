import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tokigo/core/auth/auth_provider.dart';
import 'package:tokigo/core/memory/explicit_preference_signal.dart';
import 'package:tokigo/core/widgets/search_filter_chips.dart';
import 'package:tokigo/features/search/application/providers/search_providers.dart';
import 'package:tokigo/features/search/application/controllers/flight_search_controller.dart';
import 'package:tokigo/core/domain/models/search/flight_search_params.dart';
import 'package:tokigo/features/search/presentation/widgets/search_scaffold.dart';
import 'package:tokigo/features/search/presentation/widgets/search_states_view.dart';
import 'package:tokigo/features/search/presentation/widgets/destination_picker_sheet.dart';
import 'package:tokigo/features/home/providers/home_providers.dart'
    show geoCountryProvider, profileRepositoryProvider;
import 'package:tokigo/features/search/presentation/widgets/flight_search_card.dart';
import 'package:tokigo/core/domain/models/offers/flight_offer.dart';
import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/features/search/domain/sort_option.dart';
import 'package:tokigo/features/search/application/search_facets.dart';
import 'package:tokigo/features/search/application/search_results_processing.dart';
import 'package:tokigo/features/search/domain/search_context.dart';
import 'package:tokigo/features/search/domain/search_filters.dart';
import 'package:tokigo/features/search/presentation/widgets/filter_panel.dart';
import 'package:tokigo/core/ui/localized_date.dart';
import 'package:tokigo/l10n/app_localizations.dart';

final flightSortProvider = StateProvider<SortOption>(
  (ref) => SortOption.recommended,
);
final flightFiltersProvider = StateProvider<SearchFilters>(
  (ref) => const SearchFilters(),
);

/// Trip shape offered by the form. Only the two shapes the search backend
/// actually supports are offered — a dead "Multi-City" segment would be a fake
/// capability.
enum _TripType { oneWay, roundTrip, multiCity }

/// Sort choices actually applied to the provider's results.
enum _FlightSort { recommended, cheapest, fastest, longest }

class FlightSearchPage extends ConsumerStatefulWidget {
  const FlightSearchPage({super.key});

  @override
  ConsumerState<FlightSearchPage> createState() => _FlightSearchPageState();
}

class _FlightSearchPageState extends ConsumerState<FlightSearchPage> {
  final _originCtrl = TextEditingController();
  final _destCtrl = TextEditingController();
  final _departureCtrl = TextEditingController();
  final _returnCtrl = TextEditingController();

  DateTime _departure = DateTime.now().add(const Duration(days: 7));
  DateTime? _returnDate;
  _TripType _tripType = _TripType.oneWay;
  int _passengers = 1;

  /// The legs of a multi-city itinerary (owner decision, 2026-10-20). Empty
  /// until the traveller switches the trip type.
  final List<_LegDraft> _legs = <_LegDraft>[];

  _FlightSort _sort = _FlightSort.recommended;

  FlightSearchParams? _lastParams;
  bool _prefilled = false;
  bool _originSuggestionStarted = false;
  String? _marketCountryCode;

  /// Phase 4C — the traveller's own budget (from the explicit AI memory)
  /// with its currency. Null when there is no budget, when the traveller
  /// opted out, or when the budget was stated WITHOUT a currency: the app
  /// never converts prices, so such a budget cannot filter anything.
  ExplicitBudgetRange? _explicitBudget;

  /// True when the traveller removed the budget cap for this session. The
  /// memory itself is never touched — the chip is a view over it.
  bool _budgetRemoved = false;

  bool get _roundTrip => _tripType == _TripType.roundTrip;
  bool get _multiCity => _tripType == _TripType.multiCity;

  /// The provider's own limit for one offer request.
  static const int _maxLegs = 6;

  @override
  void initState() {
    super.initState();
    // Keep the existing sort provider as the single source of the ordering.
    _sort = switch (ref.read(flightSortProvider)) {
      SortOption.priceLowHigh ||
      SortOption.priceHighLow => _FlightSort.cheapest,
      SortOption.duration => _FlightSort.fastest,
      _ => _FlightSort.recommended,
    };
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

  /// Phase 4C — the filters actually applied: the traveller's own filter
  /// state plus their explicit budget cap, unless they removed the chip for
  /// this session. A budget without a currency never filters anything (the
  /// app never converts a price).
  SearchFilters _effectiveFilters(
    SearchFilters base,
    List<FlightOffer> results,
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Dates are read in the active language, so they are (re)formatted here
    // rather than in initState — and again if the language changes.
    _departureCtrl.text = _formatDate(_departure);
    final returnDate = _returnDate;
    if (returnDate != null) _returnCtrl.text = _formatDate(returnDate);
    if (_prefilled) return;
    _prefilled = true;
    // Pre-fill from navigation extras — must read the router AFTER
    // initState completes (inherited widgets are legal here).
    final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
    if (extra != null) {
      _originCtrl.text = extra['origin']?.toString() ?? '';
      _destCtrl.text = extra['destination']?.toString() ?? '';
      final initialDeparture = extra['departureDate'] as DateTime?;
      if (initialDeparture != null) {
        _departure = initialDeparture;
        _departureCtrl.text = _formatDate(_departure);
      }
    }
    if (_originCtrl.text.trim().isEmpty) _suggestOriginFromCountry();
    // Phase 4A — the traveller's travel context: the departure airport
    // suggested for their country prefills the origin, and the budget
    // arrives with the page.
    final searchContext = SearchContext.fromMap(
      extra?['context'] as Map<String, dynamic>?,
    );
    if (_originCtrl.text.trim().isEmpty) {
      final airport = searchContext?.airport;
      if (airport != null && airport.isNotEmpty) {
        _originCtrl.text = airport;
      }
    }
    if (searchContext?.budget != null) {
      _explicitBudget = searchContext!.budget;
    }
    _marketCountryCode = searchContext?.countryCode;
  }

  void _suggestOriginFromCountry() {
    if (_originSuggestionStarted) return;
    _originSuggestionStarted = true;
    ref.read(geoCountryProvider.future).then((country) {
      if (!mounted) return;
      _marketCountryCode = country?.countryCode?.trim().toUpperCase();
      if (_originCtrl.text.trim().isNotEmpty) return;
      final airport = suggestedAirportForCountryCode(country?.countryCode);
      if (airport == null) return;
      setState(() => _originCtrl.text = airport.code);
    });
  }

  @override
  void dispose() {
    for (final _LegDraft leg in _legs) {
      leg.dispose();
    }
    _originCtrl.dispose();
    _destCtrl.dispose();
    _departureCtrl.dispose();
    _returnCtrl.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) => localizedMediumDate(context, date);

  /// The form sends a stable IATA code, but the field shows it plainly so a
  /// half-width card never has to truncate a long airport name.
  String? _routeValue(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }

  void _setTripType(_TripType type) {
    setState(() {
      _tripType = type;
      if (type == _TripType.roundTrip && _returnDate == null) {
        // Default the return leg the same way the departure is defaulted —
        // a real date the traveller can change, never a provider claim.
        _returnDate = _departure.add(const Duration(days: 3));
        _returnCtrl.text = _formatDate(_returnDate!);
      }
      if (type == _TripType.multiCity) _seedLegs();
    });
  }

  /// A multi-city trip starts with two legs: the route the traveller already
  /// typed, and an empty second leg to fill in. Nothing is invented.
  void _seedLegs() {
    if (_legs.isNotEmpty) return;
    _legs.add(
      _LegDraft(
        origin: TextEditingController(text: _originCtrl.text.trim()),
        destination: TextEditingController(text: _destCtrl.text.trim()),
        date: _departure,
      ),
    );
    _legs.add(_LegDraft(date: _departure));
  }

  void _addLeg() {
    if (_legs.length >= _maxLegs) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(l10n.flightLegsMax)));
      return;
    }
    setState(() {
      final last = _legs.isEmpty ? null : _legs.last;
      _legs.add(_LegDraft(date: last?.date ?? _departure));
    });
  }

  void _removeLeg(int index) {
    if (_legs.length <= 2) return;
    setState(() {
      _legs.removeAt(index).dispose();
    });
  }

  void _swapRoute() {
    setState(() {
      final origin = _originCtrl.text;
      _originCtrl.text = _destCtrl.text;
      _destCtrl.text = origin;
    });
  }

  SortOption get _sortOption {
    switch (_sort) {
      case _FlightSort.cheapest:
        return SortOption.priceLowHigh;
      case _FlightSort.fastest:
      case _FlightSort.longest:
        return SortOption.duration;
      case _FlightSort.recommended:
        return SortOption.recommended;
    }
  }

  List<FlightOffer> _applySort(List<FlightOffer> items) {
    if (_sort == _FlightSort.longest) {
      final sorted = List<FlightOffer>.from(items)
        ..sort(
          (a, b) => b.arrivalTime
              .difference(b.departureTime)
              .inMinutes
              .compareTo(a.arrivalTime.difference(a.departureTime).inMinutes),
        );
      return sorted;
    }
    return sortFlightResults(items, _sortOption);
  }

  void _pickOrigin() {
    final l10n = AppLocalizations.of(context)!;
    showPickerSheet(
      context,
      title: l10n.pickerFromTitle,
      entries: kAirports,
      onSelected: (entry) => setState(() => _originCtrl.text = entry.code),
    );
  }

  void _pickDestination() {
    final l10n = AppLocalizations.of(context)!;
    showPickerSheet(
      context,
      title: l10n.searchHint,
      entries: kAirports,
      onSelected: (entry) => setState(() => _destCtrl.text = entry.code),
    );
  }

  Future<void> _pickDepartureDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _departure,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _departure = picked;
        _departureCtrl.text = _formatDate(_departure);
        if (_returnDate != null && _returnDate!.isBefore(_departure)) {
          _returnDate = null;
          _returnCtrl.clear();
          if (_roundTrip) {
            _returnDate = _departure.add(const Duration(days: 3));
            _returnCtrl.text = _formatDate(_returnDate!);
          }
        }
      });
    }
  }

  Future<void> _pickReturnDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _returnDate ?? _departure.add(const Duration(days: 3)),
      firstDate: _departure,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _returnDate = picked;
        _returnCtrl.text = _formatDate(_returnDate!);
      });
    }
  }

  void _search() {
    final l10n = AppLocalizations.of(context)!;
    if (_multiCity) {
      final legs = <FlightSearchLeg>[
        for (final _LegDraft leg in _legs)
          FlightSearchLeg(
            origin: leg.origin.text.trim(),
            destination: leg.destination.text.trim(),
            date: leg.date,
          ),
      ];
      final incomplete = legs.any(
        (FlightSearchLeg leg) => leg.origin.isEmpty || leg.destination.isEmpty,
      );
      if (incomplete) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(l10n.flightLegsIncomplete)));
        return;
      }
      final params = FlightSearchParams(
        origin: legs.first.origin,
        destination: legs.first.destination,
        departureDate: legs.first.date,
        tripType: 'multicity',
        adults: _passengers,
        legs: legs,
        market: _marketCountryCode,
      );
      _lastParams = params;
      ref.read(flightSearchControllerProvider.notifier).search(params);
      return;
    }
    // An untouched form has no route to search: say so instead of firing a
    // request that can only come back as a misleading "connection error".
    if (_originCtrl.text.trim().isEmpty || _destCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(l10n.flightRouteRequired)));
      return;
    }
    final params = FlightSearchParams(
      origin: _originCtrl.text.trim(),
      destination: _destCtrl.text.trim(),
      departureDate: _departure,
      returnDate: _roundTrip ? _returnDate : null,
      tripType: _roundTrip ? 'roundtrip' : 'oneway',
      adults: _passengers,
      market: _marketCountryCode,
    );
    _lastParams = params;
    ref.read(flightSearchControllerProvider.notifier).search(params);
  }

  void _retry() {
    final params = _lastParams;
    if (params != null) {
      ref.read(flightSearchControllerProvider.notifier).search(params);
    }
  }

  void _selectSort(_FlightSort sort) {
    setState(() => _sort = sort);
    ref.read(flightSortProvider.notifier).state = _sortOption;
  }

  void _showFilters() {
    final results = ref.read(flightSearchControllerProvider).results;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FilterPanel(
        filters: ref.read(flightFiltersProvider),
        onChanged: (f) => ref.read(flightFiltersProvider.notifier).state = f,
        // Only what these results really contain.
        priceFacet: priceFacetOf(results),
        airlines: airlinesOf(results),
        showStops: true,
        showAirlines: true,
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
    final results = ref.read(flightSearchControllerProvider).results;
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(flightSearchControllerProvider);
    final filters = _effectiveFilters(
      ref.watch(flightFiltersProvider),
      state.results,
    );
    final hasResults =
        state.status == SearchStatus.success && state.results.isNotEmpty;

    // Long result lists must not build every card up front — the same
    // Low Memory Killer risk the hotel results hit applies to a busy route.
    final List<FlightOffer> visible = state.status == SearchStatus.success
        ? _visibleFlights(state, filters)
        : const <FlightOffer>[];
    final bool lazyResults = visible.length > kSearchLazyResultsThreshold;

    return SearchScaffold(
      title: l10n.searchFlights,
      subtitle: l10n.flightSearchSubtitle,
      form: _buildForm(l10n),
      // Sorting and filtering only make sense once there is something to sort.
      bottomContent: hasResults
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SortChipsRow<_FlightSort>(
                  options: _FlightSort.values,
                  selected: _sort,
                  labelOf: (sort) => switch (sort) {
                    _FlightSort.recommended => l10n.sortRecommended,
                    _FlightSort.cheapest => l10n.sortCheapest,
                    _FlightSort.fastest => l10n.sortFastest,
                    _FlightSort.longest => l10n.sortLongest,
                  },
                  onSelected: _selectSort,
                  filtersLabel: l10n.filtersAction,
                  filtersActive: !filters.isEmpty,
                  onFilters: _showFilters,
                ),
                if (_buildBudgetChip(l10n) != null)
                  Padding(
                    padding: const EdgeInsets.only(
                      top: AppSpacing.xs,
                      bottom: AppSpacing.xs,
                    ),
                    child: SearchFilterChips(
                      chips: <SearchFilterChipData>[_buildBudgetChip(l10n)!],
                    ),
                  ),
              ],
            )
          : null,
      body: lazyResults
          ? const SizedBox.shrink()
          : _buildResults(state, filters, l10n),
      bodySlivers: lazyResults
          ? <Widget>[
              SliverList.builder(
                itemCount: visible.length,
                itemBuilder: (context, index) {
                  final offer = visible[index];
                  return FlightSearchCard(
                    offer: offer,
                    onTap: () => context.push('/offer-details', extra: offer),
                  );
                },
              ),
            ]
          : null,
    );
  }

  /// Filter + sort the returned flights once, shared by the eager and lazy
  /// paths so both show exactly the same list in the same order.
  List<FlightOffer> _visibleFlights(
    FlightSearchState state,
    SearchFilters filters,
  ) {
    if (state.status != SearchStatus.success) return const <FlightOffer>[];
    return _applySort(applyFlightFilters(state.results, filters));
  }

  // ── Form ────────────────────────────────────────────────────────────────
  Widget _buildForm(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SearchSegmentedControl<_TripType>(
          options: const [
            _TripType.oneWay,
            _TripType.roundTrip,
            _TripType.multiCity,
          ],
          selected: _tripType,
          labelOf: (type) => switch (type) {
            _TripType.oneWay => l10n.tripTypeOneWay,
            _TripType.roundTrip => l10n.tripTypeRoundTrip,
            _TripType.multiCity => l10n.tripTypeMultiCity,
          },
          onSelected: _setTripType,
        ),
        const SizedBox(height: AppSpacing.md),
        if (_multiCity)
          ..._buildMultiCity(l10n)
        else
          ..._buildSingleRoute(l10n),
        const SizedBox(height: AppSpacing.md),
        _buildPassengersRow(l10n),
        const SizedBox(height: AppSpacing.lg),
        SearchSubmitButton(label: l10n.findFlights, onPressed: _search),
      ],
    );
  }

  /// The one-way / round-trip route: a single row of endpoints and dates.
  List<Widget> _buildSingleRoute(AppLocalizations l10n) {
    return <Widget>[
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: SearchFieldInput(
              icon: Icons.flight_takeoff_rounded,
              label: l10n.fieldFrom,
              hint: l10n.selectAction,
              value: _routeValue(_originCtrl),
              readOnly: true,
              onTap: _pickOrigin,
            ),
          ),
          _SwapRouteButton(onTap: _swapRoute, tooltip: l10n.swapRoute),
          Expanded(
            child: SearchFieldInput(
              icon: Icons.flight_land_rounded,
              label: l10n.fieldTo,
              hint: l10n.selectAction,
              value: _routeValue(_destCtrl),
              readOnly: true,
              onTap: _pickDestination,
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      Row(
        children: [
          Expanded(
            child: SearchFieldInput(
              icon: Icons.calendar_today_outlined,
              label: l10n.fieldDeparture,
              hint: l10n.pickDateHint,
              value: _departureCtrl.text,
              readOnly: true,
              onTap: _pickDepartureDate,
            ),
          ),
          // A one-way trip has exactly one date: no dead "return" card.
          if (_roundTrip) ...[
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: SearchFieldInput(
                icon: Icons.calendar_today_outlined,
                label: l10n.fieldReturn,
                hint: l10n.pickDateHint,
                value: _returnCtrl.text,
                readOnly: true,
                onTap: _pickReturnDate,
              ),
            ),
          ],
        ],
      ),
    ];
  }

  /// The multi-city itinerary: one card per leg, plus a way to add another.
  List<Widget> _buildMultiCity(AppLocalizations l10n) {
    return <Widget>[
      for (int i = 0; i < _legs.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: _buildLegCard(l10n, i),
        ),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          onPressed: _addLeg,
          icon: const Icon(Icons.add_rounded, size: 20),
          label: Text(l10n.flightAddLeg),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.brand,
            minimumSize: const Size(48, 44),
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.md),
    ];
  }

  Widget _buildLegCard(AppLocalizations l10n, int index) {
    final _LegDraft leg = _legs[index];
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgBorder,
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l10n.flightLegLabel(index + 1),
                  style: AppTypography.forLight().label.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              if (_legs.length > 2)
                IconButton(
                  onPressed: () => _removeLeg(index),
                  iconSize: 20,
                  color: AppColors.textSecondary,
                  tooltip: l10n.flightRemoveLeg,
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SearchFieldInput(
            icon: Icons.flight_takeoff_rounded,
            label: l10n.fieldFrom,
            hint: l10n.selectAction,
            value: _routeValue(leg.origin),
            readOnly: true,
            onTap: () => _pickLegAirport(leg.origin, l10n.pickerFromTitle),
          ),
          const SizedBox(height: AppSpacing.sm),
          SearchFieldInput(
            icon: Icons.flight_land_rounded,
            label: l10n.fieldTo,
            hint: l10n.selectAction,
            value: _routeValue(leg.destination),
            readOnly: true,
            onTap: () => _pickLegAirport(leg.destination, l10n.searchHint),
          ),
          const SizedBox(height: AppSpacing.sm),
          SearchFieldInput(
            icon: Icons.calendar_today_outlined,
            label: l10n.fieldDeparture,
            hint: l10n.pickDateHint,
            value: localizedMediumDate(context, leg.date),
            readOnly: true,
            onTap: () => _pickLegDate(leg),
          ),
        ],
      ),
    );
  }

  void _pickLegAirport(TextEditingController controller, String title) {
    showPickerSheet(
      context,
      title: title,
      entries: kAirports,
      onSelected: (entry) => setState(() => controller.text = entry.code),
    );
  }

  Future<void> _pickLegDate(_LegDraft leg) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: leg.date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => leg.date = picked);
    }
  }

  Widget _buildPassengersRow(AppLocalizations l10n) {
    // The cabin shown is the cabin actually sent with the search.
    final label = '${l10n.passengersCount(_passengers)} · ${l10n.cabinEconomy}';
    return SearchStepperInput(
      icon: Icons.people_outline_rounded,
      label: label,
      count: _passengers,
      onDecrement: () => setState(() {
        if (_passengers > 1) _passengers--;
      }),
      onIncrement: () => setState(() {
        if (_passengers < 9) _passengers++;
      }),
    );
  }

  // ── Results ─────────────────────────────────────────────────────────────
  Widget _buildResults(
    FlightSearchState state,
    SearchFilters filters,
    AppLocalizations l10n,
  ) {
    switch (state.status) {
      case SearchStatus.idle:
        return SearchStatesView.idle(
          icon: Icons.flight_takeoff_rounded,
          title: l10n.flightIdleTitle,
          body: l10n.flightIdleBody,
        );
      case SearchStatus.loading:
        return const SearchStatesView.loading(
          skeleton: Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: FlightSearchCard.loading(),
          ),
        );
      case SearchStatus.success:
        return _buildResultsList(state, filters, l10n);
      case SearchStatus.empty:
        return SearchStatesView.empty(
          icon: Icons.search_off_rounded,
          title: l10n.flightEmptyTitle,
          body: l10n.flightEmptyBody,
        );
      case SearchStatus.error:
        return SearchStatesView.error(
          title: l10n.searchErrorTitle,
          body: state.errorMessage ?? l10n.searchErrorBody,
          actionLabel: l10n.retry,
          onAction: _retry,
        );
    }
  }

  Widget _buildResultsList(
    FlightSearchState state,
    SearchFilters filters,
    AppLocalizations l10n,
  ) {
    // Phase 3C — unified provider-safe post-processing: filter then sort the
    // returned list. "Recommended" keeps the provider (registry) order.
    var items = applyFlightFilters(state.results, filters);
    items = _applySort(items);

    if (items.isEmpty && state.results.isNotEmpty) {
      return SearchStatesView.empty(
        icon: Icons.filter_alt_off_outlined,
        title: l10n.searchFilteredEmptyTitle,
        body: l10n.searchFilteredEmptyBody,
      );
    }

    return Column(
      children: [
        for (final offer in items)
          FlightSearchCard(
            offer: offer,
            onTap: () => context.push('/offer-details', extra: offer),
          ),
      ],
    );
  }
}

/// Swap control sitting between the origin and destination fields.
class _SwapRouteButton extends StatelessWidget {
  const _SwapRouteButton({required this.onTap, required this.tooltip});

  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: AppColors.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.pill)),
            side: BorderSide(color: AppColors.outline),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: const SizedBox(
              width: 40,
              height: 40,
              child: Icon(
                Icons.swap_horiz_rounded,
                size: 20,
                color: AppColors.brand,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One leg of a multi-city itinerary, as the form holds it.
class _LegDraft {
  _LegDraft({
    TextEditingController? origin,
    TextEditingController? destination,
    required this.date,
  }) : origin = origin ?? TextEditingController(),
       destination = destination ?? TextEditingController();

  final TextEditingController origin;
  final TextEditingController destination;
  DateTime date;

  void dispose() {
    origin.dispose();
    destination.dispose();
  }
}
