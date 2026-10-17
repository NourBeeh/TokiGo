import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:tokigo/features/search/application/providers/search_providers.dart';
import 'package:tokigo/features/search/application/controllers/flight_search_controller.dart';
import 'package:tokigo/core/domain/models/search/flight_search_params.dart';
import 'package:tokigo/features/search/presentation/widgets/search_scaffold.dart';
import 'package:tokigo/features/search/presentation/widgets/search_states_view.dart';
import 'package:tokigo/features/search/presentation/widgets/destination_picker_sheet.dart';
import 'package:tokigo/features/search/presentation/widgets/flight_search_card.dart';
import 'package:tokigo/core/domain/models/offers/flight_offer.dart';
import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/features/search/domain/sort_option.dart';
import 'package:tokigo/features/search/application/search_results_processing.dart';
import 'package:tokigo/features/search/domain/search_filters.dart';
import 'package:tokigo/features/search/presentation/widgets/filter_panel.dart';

final flightSortProvider = StateProvider<SortOption>((ref) => SortOption.recommended);
final flightFiltersProvider = StateProvider<SearchFilters>((ref) => const SearchFilters());

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
  bool _roundTrip = false;
  int _passengers = 1;

  static const List<String> _sortLabels = ['Recommended', 'Cheapest', 'Fastest', 'Longest'];
  String _sortLabel = 'Recommended';

  FlightSearchParams? _lastParams;
  bool _prefilled = false;

  @override
  void initState() {
    super.initState();
    _departureCtrl.text = DateFormat('EEE, MMM d').format(_departure);
    // Sync chip label from the existing sort provider (kept wiring).
    _sortLabel = ref.read(flightSortProvider) == SortOption.recommended
        ? 'Recommended'
        : 'Cheapest';
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
      _originCtrl.text = extra['origin']?.toString() ?? '';
      _destCtrl.text = extra['destination']?.toString() ?? '';
      final initialDeparture = extra['departureDate'] as DateTime?;
      if (initialDeparture != null) {
        _departure = initialDeparture;
        _departureCtrl.text = DateFormat('EEE, MMM d').format(_departure);
      }
    }
  }

  @override
  void dispose() {
    _originCtrl.dispose();
    _destCtrl.dispose();
    _departureCtrl.dispose();
    _returnCtrl.dispose();
    super.dispose();
  }

  String get _routeLabel => [_originCtrl.text, _destCtrl.text]
      .where((s) => s.trim().isNotEmpty)
      .join(' → ');

  SortOption get _sortOption {
    switch (_sortLabel) {
      case 'Cheapest':
        return SortOption.priceLowHigh;
      case 'Fastest':
      case 'Longest':
        return SortOption.duration;
      default:
        return SortOption.recommended;
    }
  }

  List<FlightOffer> _applySort(List<FlightOffer> items) {
    if (_sortLabel == 'Longest') {
      final sorted = List<FlightOffer>.from(items)
        ..sort((a, b) => b.arrivalTime
            .difference(b.departureTime)
            .inMinutes
            .compareTo(a.arrivalTime.difference(a.departureTime).inMinutes));
      return sorted;
    }
    return sortFlightResults(items, _sortOption);
  }

  void _pickOrigin() {
    showPickerSheet(
      context,
      title: 'From where?',
      entries: kAirports,
      onSelected: (entry) => setState(() => _originCtrl.text = entry.code),
    );
  }

  void _pickDestination() {
    showPickerSheet(
      context,
      title: 'Where to?',
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
        _departureCtrl.text = DateFormat('EEE, MMM d').format(_departure);
        if (_returnDate != null && _returnDate!.isBefore(_departure)) {
          _returnDate = null;
          _returnCtrl.clear();
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
        _returnCtrl.text = DateFormat('EEE, MMM d').format(_returnDate!);
      });
    }
  }

  void _search() {
    final params = FlightSearchParams(
      origin: _originCtrl.text.trim(),
      destination: _destCtrl.text.trim(),
      departureDate: _departure,
      returnDate: _roundTrip ? _returnDate : null,
      tripType: _roundTrip ? 'roundtrip' : 'oneway',
      adults: _passengers,
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

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      builder: (_) => FilterPanel(
        filters: ref.read(flightFiltersProvider),
        onChanged: (f) => ref.read(flightFiltersProvider.notifier).state = f,
        showStops: true,
        showAirlines: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(flightSearchControllerProvider);
    final filters = ref.watch(flightFiltersProvider);

    return SearchScaffold(
      hue: AppColors.flightHue,
      title: 'Flights',
      subtitle: 'Search flights across providers',
      collapsedTitle: _routeLabel.isEmpty ? 'Flights' : 'Flights · $_routeLabel',
      form: _buildForm(),
      bottomContent: SortChipsRow(
        options: _sortLabels,
        selected: _sortLabel,
        onSelected: (label) {
          setState(() => _sortLabel = label);
          // Keep the existing sort provider in sync (kept wiring).
          ref.read(flightSortProvider.notifier).state = switch (label) {
            'Cheapest' => SortOption.priceLowHigh,
            'Fastest' || 'Longest' => SortOption.duration,
            _ => SortOption.recommended,
          };
        },
        filtersLabel: 'Filters',
        filtersActive: !filters.isEmpty,
        onFilters: _showFilters,
      ),
      body: _buildResults(state, filters),
    );
  }

  // ── Form ────────────────────────────────────────────────────────────────
  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTripTypeChips(),
        const SizedBox(height: AppSpacing.md),
        SearchFieldInput(
          icon: Icons.flight_takeoff_rounded,
          hint: 'From where?',
          controller: _originCtrl,
          readOnly: true,
          onTap: _pickOrigin,
        ),
        const SizedBox(height: AppSpacing.md),
        SearchFieldInput(
          icon: Icons.flight_land_rounded,
          hint: 'Where to?',
          controller: _destCtrl,
          readOnly: true,
          onTap: _pickDestination,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: SearchFieldInput(
                icon: Icons.calendar_today_outlined,
                hint: 'Departure',
                controller: _departureCtrl,
                readOnly: true,
                onTap: _pickDepartureDate,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _roundTrip
                  ? SearchFieldInput(
                      icon: Icons.calendar_today_outlined,
                      hint: 'Return',
                      controller: _returnCtrl,
                      readOnly: true,
                      onTap: _pickReturnDate,
                    )
                  : SearchFieldInput(
                      icon: Icons.calendar_today_outlined,
                      hint: 'One-way',
                      readOnly: true,
                      onTap: () => setState(() => _roundTrip = true),
                    ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _buildPassengersRow(),
        const SizedBox(height: AppSpacing.lg),
        SearchSubmitButton(
          label: 'Search flights',
          onPressed: _search,
          hue: AppColors.flightHue,
        ),
      ],
    );
  }

  Widget _buildTripTypeChips() {
    return Row(
      children: [
        _tripTypeChip('One-way', !_roundTrip, () => setState(() => _roundTrip = false)),
        const SizedBox(width: AppSpacing.sm),
        _tripTypeChip('Round-trip', _roundTrip, () => setState(() => _roundTrip = true)),
      ],
    );
  }

  Widget _tripTypeChip(String label, bool selected, VoidCallback onTap) {
    final typography = AppTypography.forLight();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.sm + 2),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
              color: selected ? Colors.white : Colors.white.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          style: typography.captionSemibold.copyWith(
            color: selected ? AppColors.flightHue : Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildPassengersRow() {
    final typography = AppTypography.forLight();
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm + 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(Icons.people_outline_rounded, size: 20, color: AppColors.brand),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              '$_passengers passenger${_passengers > 1 ? 's' : ''}',
              style: typography.bodyLarge.copyWith(color: AppColors.textPrimary),
            ),
          ),
          _stepperButton(Icons.remove_rounded,
              () => setState(() { if (_passengers > 1) _passengers--; })),
          const SizedBox(width: AppSpacing.md),
          Text('$_passengers',
              style: typography.bodyLargeMedium
                  .copyWith(color: AppColors.textPrimary)),
          const SizedBox(width: AppSpacing.md),
          _stepperButton(Icons.add_rounded,
              () => setState(() { if (_passengers < 9) _passengers++; })),
        ],
      ),
    );
  }

  Widget _stepperButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppColors.brandContainer,
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
        child: Icon(icon, size: 18, color: AppColors.brand),
      ),
    );
  }

  // ── Results ─────────────────────────────────────────────────────────────
  Widget _buildResults(FlightSearchState state, SearchFilters filters) {
    switch (state.status) {
      case SearchStatus.idle:
        return const SearchStatesView.idle(
          icon: Icons.flight_takeoff_rounded,
          title: 'Find your flight',
          body: 'Compare fares across airlines for your next trip',
        );
      case SearchStatus.loading:
        return const SearchStatesView.loading(
          skeleton: Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: FlightSearchCard.loading(),
          ),
        );
      case SearchStatus.success:
        return _buildResultsList(state, filters);
      case SearchStatus.empty:
        return const SearchStatesView.empty(
          icon: Icons.search_off_rounded,
          title: 'No flights found',
          body: 'Try different dates or nearby airports',
        );
      case SearchStatus.error:
        return SearchStatesView.error(
          title: 'Connection error',
          body: state.errorMessage ?? 'Something went wrong. Please try again.',
          onAction: _retry,
        );
    }
  }

  Widget _buildResultsList(FlightSearchState state, SearchFilters filters) {
    // Phase 3C — unified provider-safe post-processing: filter then sort the
    // returned list. "Recommended" keeps the provider (registry) order.
    var items = applyFlightFilters(state.results, filters);
    items = _applySort(items);

    if (items.isEmpty && state.results.isNotEmpty) {
      return const SearchStatesView.empty(
        icon: Icons.filter_alt_off_outlined,
        title: 'No matches for your filters',
        body: 'Try widening the price range or clearing filters',
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
