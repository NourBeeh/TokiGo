import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:tokigo/core/domain/models/search/car_search_params.dart';
import 'package:tokigo/core/domain/models/offers/car_offer.dart';
import 'package:tokigo/features/search/application/providers/hotel_car_providers.dart';
import 'package:tokigo/features/search/application/controllers/car_search_controller.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/ui/app_button.dart';
import 'package:tokigo/features/search/presentation/widgets/search_scaffold.dart';
import 'package:tokigo/features/search/presentation/widgets/search_states_view.dart';
import 'package:tokigo/features/search/presentation/widgets/destination_picker_sheet.dart';
import 'package:tokigo/features/search/presentation/widgets/car_search_card.dart';
import 'package:tokigo/features/search/domain/sort_option.dart';
import 'package:tokigo/features/search/application/search_facets.dart';
import 'package:tokigo/features/search/application/search_results_processing.dart';
import 'package:tokigo/features/search/domain/search_filters.dart';
import 'package:tokigo/features/search/presentation/widgets/filter_panel.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Phase 3C — per-vertical sort/filters state (cars).
final carSortProvider = StateProvider<SortOption>(
  (ref) => SortOption.recommended,
);
final carFiltersProvider = StateProvider<SearchFilters>(
  (ref) => const SearchFilters(),
);

class CarSearchPage extends ConsumerStatefulWidget {
  const CarSearchPage({super.key});

  @override
  ConsumerState<CarSearchPage> createState() => _CarSearchPageState();
}

class _CarSearchPageState extends ConsumerState<CarSearchPage> {
  final _pickupCtrl = TextEditingController();
  final _dropoffCtrl = TextEditingController();
  final _pickupDateCtrl = TextEditingController();
  final _dropoffDateCtrl = TextEditingController();

  DateTime _pickupDate = DateTime.now().add(const Duration(days: 1));
  DateTime _dropoffDate = DateTime.now().add(const Duration(days: 2));
  String _transmission = 'Any';

  CarSearchParams? _lastParams;

  static const List<String> _transmissionOptions = [
    'Any',
    'Automatic',
    'Manual',
  ];
  bool _prefilled = false;

  @override
  void initState() {
    super.initState();
    _pickupDateCtrl.text = DateFormat('EEE, MMM d').format(_pickupDate);
    _dropoffDateCtrl.text = DateFormat('EEE, MMM d').format(_dropoffDate);
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
      _pickupCtrl.text = extra['pickupLocation']?.toString() ?? '';
      _dropoffCtrl.text = extra['dropoffLocation']?.toString() ?? '';
      final initialPickupDate = extra['pickupDate'] as DateTime?;
      if (initialPickupDate != null) {
        _pickupDate = initialPickupDate;
        _pickupDateCtrl.text = DateFormat('EEE, MMM d').format(_pickupDate);
      }
    }
  }

  @override
  void dispose() {
    _pickupCtrl.dispose();
    _dropoffCtrl.dispose();
    _pickupDateCtrl.dispose();
    _dropoffDateCtrl.dispose();
    super.dispose();
  }

  void _pickPickupLocation() {
    final l10n = AppLocalizations.of(context)!;
    showPickerSheet(
      context,
      title: l10n.carPickupLocation,
      entries: kCities,
      onSelected: (entry) => setState(() => _pickupCtrl.text = entry.name),
    );
  }

  void _pickDropoffLocation() {
    final l10n = AppLocalizations.of(context)!;
    showPickerSheet(
      context,
      title: l10n.carDropoffLocation,
      entries: kCities,
      onSelected: (entry) => setState(() => _dropoffCtrl.text = entry.name),
    );
  }

  Future<void> _pickPickupDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _pickupDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) {
      setState(() {
        _pickupDate = d;
        if (_dropoffDate.isBefore(_pickupDate)) {
          _dropoffDate = _pickupDate.add(const Duration(days: 1));
          _dropoffDateCtrl.text = DateFormat('EEE, MMM d').format(_dropoffDate);
        }
        _pickupDateCtrl.text = DateFormat('EEE, MMM d').format(_pickupDate);
      });
    }
  }

  Future<void> _pickDropoffDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _dropoffDate,
      firstDate: _pickupDate.add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) {
      setState(() {
        _dropoffDate = d;
        _dropoffDateCtrl.text = DateFormat('EEE, MMM d').format(_dropoffDate);
      });
    }
  }

  void _search() {
    final params = CarSearchParams(
      pickupLocation: _pickupCtrl.text,
      dropoffLocation: _dropoffCtrl.text,
      pickupDateTime: _pickupDate,
      dropoffDateTime: _dropoffDate,
      transmission: _transmission == 'Any' ? null : _transmission.toLowerCase(),
    );
    _lastParams = params;
    ref.read(carSearchControllerProvider.notifier).search(params);
  }

  void _retry() {
    final params = _lastParams;
    if (params != null) {
      ref.read(carSearchControllerProvider.notifier).search(params);
    }
  }

  /// Phase 3C — shared sort/filter controls (same visual language as
  /// flights/hotels).
  static const List<String> _sortLabels = [
    'Recommended',
    'Cheapest',
    'Top rated',
  ];
  String _sortLabel = 'Recommended';

  SortOption get _sortOption => switch (_sortLabel) {
    'Cheapest' => SortOption.priceLowHigh,
    'Top rated' => SortOption.rating,
    _ => SortOption.recommended,
  };

  void _showFilters() {
    final results = ref.read(carSearchControllerProvider).results;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FilterPanel(
        filters: ref.read(carFiltersProvider),
        onChanged: (f) => ref.read(carFiltersProvider.notifier).state = f,
        // Only what these results really contain.
        priceFacet: priceFacetOf(results),
        transmissions: transmissionsOf(results),
        showSeats: true,
        showTransmission: true,
      ),
    );
  }

  Widget _buildSortAndFilters() {
    final filters = ref.watch(carFiltersProvider);
    return SortChipsRow(
      options: _sortLabels,
      selected: _sortLabel,
      onSelected: (label) {
        setState(() => _sortLabel = label);
        ref.read(carSortProvider.notifier).state = _sortOption;
      },
      filtersLabel: 'Filters',
      filtersActive: !filters.isEmpty,
      onFilters: _showFilters,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // ── Honest gate (owner decision, 2026-10-18/19) ────────────────────────
    // The app must never display a fabricated price or image. The car vendor is
    // deliberately not chosen yet, and the only adapter behind the CarProvider
    // contract (the backend's `mock.car.provider.ts`) now answers every search
    // with an explicit "no provider connected" and ZERO vehicles — the invented
    // catalogue it used to return was removed on 2026-10-19. Since there is no
    // real inventory to search, this surface states the truth instead — and the
    // whole search flow below (form, controller, results, sort/filters) is kept
    // intact for the day a real vendor adapter is configured: flip
    // [_carRentalLive] and it returns.
    if (!_carRentalLive) {
      return SearchScaffold(
        title: l10n.searchCars,
        subtitle: l10n.carsSubtitle,
        form: const SizedBox.shrink(),
        body: Column(
          children: <Widget>[
            SearchStatesView.idle(
              icon: Icons.directions_car_outlined,
              title: l10n.carsUnavailableTitle,
              body: l10n.carsUnavailableBody,
            ),
            // Two real destinations instead of a dead end. Inset + a clear gap:
            // two full-bleed tinted bars stacked edge-to-edge read as one blob.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Column(
                children: <Widget>[
                  AppButton(
                    label: l10n.findFlights,
                    type: AppButtonType.secondary,
                    onPressed: () => context.push('/flights'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: l10n.findHotels,
                    type: AppButtonType.secondary,
                    onPressed: () => context.push('/hotels'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final state = ref.watch(carSearchControllerProvider);
    final List<CarOffer> visible = state.status == CarSearchStatus.success
        ? _visibleCars(state)
        : const <CarOffer>[];
    // Same guard as hotels/flights: a long live inventory must not build every
    // card (and every photo) before the user scrolls.
    final bool lazyResults = visible.length > kSearchLazyResultsThreshold;

    return SearchScaffold(
      title: l10n.searchCars,
      subtitle: l10n.carsLiveSubtitle,
      form: _buildForm(),
      bottomContent: _buildSortAndFilters(),
      body: lazyResults ? const SizedBox.shrink() : _buildResults(state),
      bodySlivers: lazyResults
          ? <Widget>[
              SliverList.builder(
                itemCount: visible.length,
                itemBuilder: (context, index) {
                  final offer = visible[index];
                  return CarSearchCard(
                    offer: offer,
                    onTap: () => context.push('/offer-details', extra: offer),
                  );
                },
              ),
            ]
          : null,
    );
  }

  /// Filter + sort the returned cars once, shared by the eager and lazy paths.
  List<CarOffer> _visibleCars(CarSearchState state) {
    if (state.status != CarSearchStatus.success) return const <CarOffer>[];
    return sortCarResults(
      applyCarFilters(state.results, ref.watch(carFiltersProvider)),
      ref.read(carSortProvider),
    );
  }

  /// Whether the car-rental vertical is backed by a REAL vendor adapter.
  ///
  /// A getter, not a `const`, on purpose: a constant condition would make the
  /// whole search flow below look like dead code to the analyzer.
  static bool get _carRentalLive => false;

  // ── Form ────────────────────────────────────────────────────────────────
  Widget _buildForm() {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SearchFieldInput(
          icon: Icons.location_on_outlined,
          hint: l10n.carPickupHint,
          controller: _pickupCtrl,
          readOnly: true,
          onTap: _pickPickupLocation,
        ),
        const SizedBox(height: AppSpacing.md),
        SearchFieldInput(
          icon: Icons.flag_outlined,
          hint: l10n.carDropoffHint,
          controller: _dropoffCtrl,
          readOnly: true,
          onTap: _pickDropoffLocation,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: SearchFieldInput(
                icon: Icons.calendar_today_outlined,
                hint: l10n.carPickUpShort,
                controller: _pickupDateCtrl,
                readOnly: true,
                onTap: _pickPickupDate,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: SearchFieldInput(
                icon: Icons.calendar_today_outlined,
                hint: l10n.carDropOffShort,
                controller: _dropoffDateCtrl,
                readOnly: true,
                onTap: _pickDropoffDate,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _buildTransmissionChips(),
        const SizedBox(height: AppSpacing.lg),
        SearchSubmitButton(label: l10n.carSearchCta, onPressed: _search),
      ],
    );
  }

  Widget _buildTransmissionChips() {
    return Row(
      children: [
        for (final (index, option) in _transmissionOptions.indexed) ...[
          if (index > 0) const SizedBox(width: AppSpacing.sm),
          SearchChoiceChip(
            label: option,
            selected: option == _transmission,
            onTap: () => setState(() => _transmission = option),
          ),
        ],
      ],
    );
  }

  // ── Results ─────────────────────────────────────────────────────────────
  Widget _buildResults(CarSearchState state) {
    final l10n = AppLocalizations.of(context)!;
    switch (state.status) {
      case CarSearchStatus.idle:
        return SearchStatesView.idle(
          icon: Icons.directions_car_outlined,
          title: l10n.carFindYourRide,
          body: l10n.carIdleBody,
        );
      case CarSearchStatus.loading:
        return const SearchStatesView.loading(
          skeleton: Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: CarSearchCard.loading(),
          ),
        );
      case CarSearchStatus.success:
        // Phase 3C — provider-safe post-processing (filter then sort the
        // returned list; provider order = "recommended").
        final filters = ref.watch(carFiltersProvider);
        final visible = sortCarResults(
          applyCarFilters(state.results, filters),
          ref.read(carSortProvider),
        );
        if (visible.isEmpty && state.results.isNotEmpty) {
          return SearchStatesView.empty(
            icon: Icons.filter_alt_off_outlined,
            title: l10n.carNoMatchesTitle,
            body: l10n.carNoMatchesBody,
          );
        }
        return Column(
          children: [
            for (final offer in visible)
              CarSearchCard(
                offer: offer,
                onTap: () => context.push('/offer-details', extra: offer),
              ),
          ],
        );
      case CarSearchStatus.empty:
        return SearchStatesView.empty(
          icon: Icons.search_off_rounded,
          title: l10n.carNoCarsTitle,
          body: l10n.carNoCarsBody,
        );
      case CarSearchStatus.error:
        return SearchStatesView.error(
          title: l10n.carConnectionErrorTitle,
          body: state.errorMessage ?? 'Something went wrong. Please try again.',
          onAction: _retry,
        );
    }
  }
}
