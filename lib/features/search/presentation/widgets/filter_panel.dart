import 'package:flutter/material.dart';
import 'package:tokigo/features/search/domain/search_filters.dart';
import 'package:tokigo/core/theme/app_spacing.dart';

/// Phase 3C — the shared filter panel. Vertical-agnostic core (price range)
/// plus optional sections the host page enables (stops/airlines for
/// flights, rating/amenities for hotels, seats/transmission for cars).
///
/// All filters are client-side post-filters on the provider-returned list —
/// they never re-request or alter provider truth.
class FilterPanel extends StatefulWidget {
  final SearchFilters filters;
  final ValueChanged<SearchFilters> onChanged;

  /// Which optional sections to show.
  final bool showStops;
  final bool showAirlines;
  final bool showRating;
  final bool showAmenities;
  final bool showSeats;
  final bool showTransmission;

  const FilterPanel({
    super.key,
    required this.filters,
    required this.onChanged,
    this.showStops = false,
    this.showAirlines = false,
    this.showRating = false,
    this.showAmenities = false,
    this.showSeats = false,
    this.showTransmission = false,
  });

  @override
  State<FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<FilterPanel> {
  late double _minPrice;
  late double _maxPrice;
  late int? _maxStops;
  late double? _minRating;
  late int? _minSeats;
  late String? _transmission;
  late List<String> _airlines;
  late List<String> _amenities;

  static const _airlineOptions = ['EgyptAir', 'Emirates', 'Qatar Airways', 'Turkish Airlines'];
  static const _amenityOptions = ['Pool', 'Wifi', 'Spa', 'Breakfast', 'Airport transfer'];

  @override
  void initState() {
    super.initState();
    _minPrice = widget.filters.priceMin ?? 0;
    _maxPrice = widget.filters.priceMax ?? 1000;
    _maxStops = widget.filters.maxStops;
    _minRating = widget.filters.minRating;
    _minSeats = widget.filters.minSeats;
    _transmission = widget.filters.transmission;
    _airlines = List.of(widget.filters.airlines ?? const []);
    _amenities = List.of(widget.filters.amenities ?? const []);
  }

  void _emit() {
    widget.onChanged(widget.filters.copyWith(
      priceMin: _minPrice <= 0 ? null : _minPrice,
      priceMax: _maxPrice >= 1000 ? null : _maxPrice,
      maxStops: _maxStops,
      minRating: _minRating,
      minSeats: _minSeats,
      transmission: _transmission,
      airlines: _airlines.isEmpty ? null : List.unmodifiable(_airlines),
      amenities: _amenities.isEmpty ? null : List.unmodifiable(_amenities),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _sectionLabel('Price Range'),
          Semantics(
            label:
                'Price range slider, minimum ${_minPrice.toStringAsFixed(0)}, maximum ${_maxPrice.toStringAsFixed(0)}',
            child: RangeSlider(
              min: 0,
              max: 1000,
              values: RangeValues(_minPrice, _maxPrice),
              onChanged: (v) {
                setState(() {
                  _minPrice = v.start;
                  _maxPrice = v.end;
                });
                _emit();
              },
            ),
          ),
          if (widget.showStops) ...[
            _sectionLabel('Max Stops'),
            SegmentedButton<int?>(
              segments: const [
                ButtonSegment(value: null, label: Text('Any')),
                ButtonSegment(value: 0, label: Text('Direct')),
                ButtonSegment(value: 1, label: Text('≤ 1')),
                ButtonSegment(value: 2, label: Text('≤ 2')),
              ],
              selected: {_maxStops},
              onSelectionChanged: (s) {
                setState(() => _maxStops = s.first);
                _emit();
              },
            ),
          ],
          if (widget.showAirlines) ...[
            _sectionLabel('Airlines'),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final airline in _airlineOptions)
                  FilterChip(
                    label: Text(airline),
                    selected: _airlines.contains(airline),
                    onSelected: (on) {
                      setState(() {
                        on ? _airlines.add(airline) : _airlines.remove(airline);
                      });
                      _emit();
                    },
                  ),
              ],
            ),
          ],
          if (widget.showRating) ...[
            _sectionLabel('Minimum Rating'),
            SegmentedButton<double?>(
              segments: const [
                ButtonSegment(value: null, label: Text('Any')),
                ButtonSegment(value: 3.0, label: Text('3+')),
                ButtonSegment(value: 4.0, label: Text('4+')),
                ButtonSegment(value: 4.5, label: Text('4.5+')),
              ],
              selected: {_minRating},
              onSelectionChanged: (s) {
                setState(() => _minRating = s.first);
                _emit();
              },
            ),
          ],
          if (widget.showAmenities) ...[
            _sectionLabel('Amenities'),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final amenity in _amenityOptions)
                  FilterChip(
                    label: Text(amenity),
                    selected: _amenities.contains(amenity),
                    onSelected: (on) {
                      setState(() {
                        on ? _amenities.add(amenity) : _amenities.remove(amenity);
                      });
                      _emit();
                    },
                  ),
              ],
            ),
          ],
          if (widget.showSeats) ...[
            _sectionLabel('Minimum Seats'),
            SegmentedButton<int?>(
              segments: const [
                ButtonSegment(value: null, label: Text('Any')),
                ButtonSegment(value: 2, label: Text('2+')),
                ButtonSegment(value: 4, label: Text('4+')),
                ButtonSegment(value: 7, label: Text('7+')),
              ],
              selected: {_minSeats},
              onSelectionChanged: (s) {
                setState(() => _minSeats = s.first);
                _emit();
              },
            ),
          ],
          if (widget.showTransmission) ...[
            _sectionLabel('Transmission'),
            SegmentedButton<String?>(
              segments: const [
                ButtonSegment(value: null, label: Text('Any')),
                ButtonSegment(value: 'Automatic', label: Text('Automatic')),
                ButtonSegment(value: 'Manual', label: Text('Manual')),
              ],
              selected: {_transmission},
              onSelectionChanged: (s) {
                setState(() => _transmission = s.first);
                _emit();
              },
            ),
          ],
          SizedBox(height: AppSpacing.sm),
          Semantics(
            button: true,
            label: 'Reset filters',
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _minPrice = 0;
                  _maxPrice = 1000;
                  _maxStops = null;
                  _minRating = null;
                  _minSeats = null;
                  _transmission = null;
                  _airlines = [];
                  _amenities = [];
                });
                widget.onChanged(const SearchFilters());
              },
              child: const Text('Reset Filters'),
            ),
          ),
          SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Text(
            text,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      );
}
