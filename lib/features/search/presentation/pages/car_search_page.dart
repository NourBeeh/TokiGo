import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:tokigo/core/domain/models/search/car_search_params.dart';
import 'package:tokigo/features/search/application/providers/hotel_car_providers.dart';
import 'package:tokigo/features/search/application/controllers/car_search_controller.dart';
import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/features/search/presentation/widgets/search_scaffold.dart';
import 'package:tokigo/features/search/presentation/widgets/search_states_view.dart';
import 'package:tokigo/features/search/presentation/widgets/destination_picker_sheet.dart';
import 'package:tokigo/features/search/presentation/widgets/car_search_card.dart';
import 'package:tokigo/features/search/domain/sort_option.dart';
import 'package:tokigo/features/search/application/search_results_processing.dart';
import 'package:tokigo/features/search/domain/search_filters.dart';
import 'package:tokigo/features/search/presentation/widgets/filter_panel.dart';

/// Phase 3C — per-vertical sort/filters state (cars).
final carSortProvider = StateProvider<SortOption>((ref) => SortOption.recommended);
final carFiltersProvider = StateProvider<SearchFilters>((ref) => const SearchFilters());

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

  String _pickupLabel = '';
  DateTime _pickupDate = DateTime.now().add(const Duration(days: 1));
  DateTime _dropoffDate = DateTime.now().add(const Duration(days: 2));
  String _transmission = 'Any';

  CarSearchParams? _lastParams;

  static const List<String> _transmissionOptions = ['Any', 'Automatic', 'Manual'];
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
      _pickupLabel = extra['pickupLocation']?.toString() ?? '';
      _pickupCtrl.text = _pickupLabel;
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
    showPickerSheet(
      context,
      title: 'Pickup location',
      entries: kCities,
      onSelected: (entry) => setState(() {
        _pickupLabel = entry.name;
        _pickupCtrl.text = entry.name;
      }),
    );
  }

  void _pickDropoffLocation() {
    showPickerSheet(
      context,
      title: 'Dropoff location',
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
  static const List<String> _sortLabels = ['Recommended', 'Cheapest', 'Top rated'];
  String _sortLabel = 'Recommended';

  SortOption get _sortOption => switch (_sortLabel) {
        'Cheapest' => SortOption.priceLowHigh,
        'Top rated' => SortOption.rating,
        _ => SortOption.recommended,
      };

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      builder: (_) => FilterPanel(
        filters: ref.read(carFiltersProvider),
        onChanged: (f) => ref.read(carFiltersProvider.notifier).state = f,
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
    final state = ref.watch(carSearchControllerProvider);

    return SearchScaffold(
      hue: AppColors.carHue,
      title: 'Cars',
      subtitle: 'Rental cars at your destination',
      collapsedTitle: _pickupLabel.isEmpty ? 'Cars' : 'Cars · $_pickupLabel',
      form: _buildForm(),
      bottomContent: _buildSortAndFilters(),
      body: _buildResults(state),
    );
  }

  // ── Form ────────────────────────────────────────────────────────────────
  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SearchFieldInput(
          icon: Icons.location_on_outlined,
          hint: 'Pickup location',
          controller: _pickupCtrl,
          readOnly: true,
          onTap: _pickPickupLocation,
        ),
        const SizedBox(height: AppSpacing.md),
        SearchFieldInput(
          icon: Icons.flag_outlined,
          hint: 'Dropoff location',
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
                hint: 'Pick-up',
                controller: _pickupDateCtrl,
                readOnly: true,
                onTap: _pickPickupDate,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: SearchFieldInput(
                icon: Icons.calendar_today_outlined,
                hint: 'Drop-off',
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
        SearchSubmitButton(
          label: 'Search cars',
          onPressed: _search,
          hue: AppColors.carHue,
        ),
      ],
    );
  }

  Widget _buildTransmissionChips() {
    return Row(
      children: [
        for (final (index, option) in _transmissionOptions.indexed) ...[
          if (index > 0) const SizedBox(width: AppSpacing.sm),
          _transmissionChip(option),
        ],
      ],
    );
  }

  Widget _transmissionChip(String label) {
    final selected = label == _transmission;
    final typography = AppTypography.forLight();
    return GestureDetector(
      onTap: () => setState(() => _transmission = label),
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
            color: selected ? AppColors.carHue : Colors.white,
          ),
        ),
      ),
    );
  }

  // ── Results ─────────────────────────────────────────────────────────────
  Widget _buildResults(CarSearchState state) {
    switch (state.status) {
      case CarSearchStatus.idle:
        return const SearchStatesView.idle(
          icon: Icons.directions_car_outlined,
          title: 'Find your ride',
          body: 'Compare car rentals at pickup points worldwide',
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
          return const SearchStatesView.empty(
            icon: Icons.filter_alt_off_outlined,
            title: 'No matches for your filters',
            body: 'Try widening the price range or clearing filters',
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
        return const SearchStatesView.empty(
          icon: Icons.search_off_rounded,
          title: 'No cars found',
          body: 'Try a different location or dates',
        );
      case CarSearchStatus.error:
        return SearchStatesView.error(
          title: 'Connection error',
          body: state.errorMessage ?? 'Something went wrong. Please try again.',
          onAction: _retry,
        );
    }
  }
}
