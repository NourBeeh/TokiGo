import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/ui/app_button.dart';
import 'package:tokigo/core/widgets/cards/card_price.dart';
import 'package:tokigo/features/search/application/search_facets.dart';
import 'package:tokigo/features/search/domain/search_filters.dart';
import 'package:tokigo/features/search/presentation/widgets/search_scaffold.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// The shared filter sheet — reference screen 10 ("Filters").
///
/// Anatomy follows the reference: a title with a Reset action, sections for
/// price, hotel class, guest score, stops, seats, transmission, airlines and
/// amenities, and one Apply action at the bottom.
///
/// **Honesty rules (owner, 2026-10-19):**
/// - Every option is real: the price span, airlines, facilities and
///   transmission values are computed from the results the provider returned
///   ([priceFacetOf], [airlinesOf], [amenitiesOf], [transmissionsOf]). A section
///   whose result set has no values is omitted rather than filled with an
///   invented list.
/// - The price section only appears when the whole list is priced in one
///   currency: amounts in different currencies are not comparable, and a slider
///   spanning them would be a false scale.
/// - Edits are a draft. **Apply filters** commits them and closes the sheet, so
///   the button does the thing it says; **Reset** clears the draft.
///
/// All filters stay client-side post-filters on the provider-returned list —
/// they never re-request or alter provider truth.
class FilterPanel extends StatefulWidget {
  const FilterPanel({
    super.key,
    required this.filters,
    required this.onChanged,
    this.priceFacet,
    this.airlines = const <String>[],
    this.amenities = const <String>[],
    this.transmissions = const <String>[],
    this.showStops = false,
    this.showStars = false,
    this.showRating = false,
    this.showAirlines = false,
    this.showAmenities = false,
    this.showSeats = false,
    this.showTransmission = false,
  });

  final SearchFilters filters;

  /// Called once, when the customer commits the draft with "Apply filters".
  final ValueChanged<SearchFilters> onChanged;

  /// The real price span of the current results — `null` hides the section.
  final PriceFacet? priceFacet;

  /// The real option values of the current results.
  final List<String> airlines;
  final List<String> amenities;
  final List<String> transmissions;

  /// Which optional sections to show (subject to the data above).
  final bool showStops;
  final bool showStars;
  final bool showRating;
  final bool showAirlines;
  final bool showAmenities;
  final bool showSeats;
  final bool showTransmission;

  @override
  State<FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<FilterPanel> {
  double? _priceMin;
  double? _priceMax;
  int? _maxStops;
  int? _minStars;
  double? _minRating;
  int? _minSeats;
  String? _transmission;
  late List<String> _airlines;
  late List<String> _amenities;

  static const List<int?> _starOptions = <int?>[null, 5, 4, 3, 2];
  static const List<int?> _stopOptions = <int?>[null, 0, 1, 2];
  static const List<double?> _ratingOptions = <double?>[null, 3, 4, 4.5];
  static const List<int?> _seatOptions = <int?>[null, 2, 4, 7];

  @override
  void initState() {
    super.initState();
    _priceMin = widget.filters.priceMin;
    _priceMax = widget.filters.priceMax;
    _maxStops = widget.filters.maxStops;
    _minStars = widget.filters.minStars;
    _minRating = widget.filters.minRating;
    _minSeats = widget.filters.minSeats;
    _transmission = widget.filters.transmission;
    _airlines = List<String>.of(widget.filters.airlines ?? const <String>[]);
    _amenities = List<String>.of(widget.filters.amenities ?? const <String>[]);
  }

  /// A price bound sitting exactly on the facet edge is "no constraint".
  double? get _effectivePriceMin {
    final value = _priceMin;
    final facet = widget.priceFacet;
    if (value == null) return null;
    if (facet != null && value <= facet.min) return null;
    return value;
  }

  double? get _effectivePriceMax {
    final value = _priceMax;
    final facet = widget.priceFacet;
    if (value == null) return null;
    if (facet != null && value >= facet.max) return null;
    return value;
  }

  bool get _hasSelection =>
      _effectivePriceMin != null ||
      _effectivePriceMax != null ||
      _maxStops != null ||
      _minStars != null ||
      _minRating != null ||
      _minSeats != null ||
      _transmission != null ||
      _airlines.isNotEmpty ||
      _amenities.isNotEmpty;

  SearchFilters _draft() => SearchFilters(
    priceMin: _effectivePriceMin,
    priceMax: _effectivePriceMax,
    maxStops: _maxStops,
    minStars: _minStars,
    minRating: _minRating,
    minSeats: _minSeats,
    transmission: _transmission,
    airlines: _airlines.isEmpty ? null : List<String>.unmodifiable(_airlines),
    amenities: _amenities.isEmpty
        ? null
        : List<String>.unmodifiable(_amenities),
  );

  void _apply() {
    widget.onChanged(_draft());
    Navigator.of(context).maybePop();
  }

  void _reset() {
    setState(() {
      _priceMin = null;
      _priceMax = null;
      _maxStops = null;
      _minStars = null;
      _minRating = null;
      _minSeats = null;
      _transmission = null;
      _airlines = <String>[];
      _amenities = <String>[];
    });
  }

  void _toggle(List<String> values, String value) {
    setState(() {
      values.contains(value) ? values.remove(value) : values.add(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final typography = AppTypography.forLight();
    final facet = widget.priceFacet;

    final sections = <Widget>[
      if (facet != null) _priceSection(l10n, facet),
      if (widget.showStars)
        _section(
          l10n.filterHotelClass,
          _pills(<Widget>[
            for (final stars in _starOptions)
              SearchChoiceChip(
                label: stars == null ? l10n.hotelRatingAll : '$stars',
                icon: stars == null ? null : Icons.star_rounded,
                selected: _minStars == stars,
                onTap: () => setState(() => _minStars = stars),
              ),
          ]),
        ),
      if (widget.showRating)
        _section(
          l10n.filterGuestScore,
          _pills(<Widget>[
            for (final rating in _ratingOptions)
              SearchChoiceChip(
                label: rating == null
                    ? l10n.filterAny
                    : rating % 1 == 0
                    ? '${rating.toInt()}+'
                    : '$rating+',
                selected: _minRating == rating,
                onTap: () => setState(() => _minRating = rating),
              ),
          ]),
        ),
      if (widget.showStops)
        _section(
          l10n.filterStops,
          _pills(<Widget>[
            for (final stops in _stopOptions)
              SearchChoiceChip(
                label: switch (stops) {
                  null => l10n.filterAny,
                  0 => l10n.filterDirect,
                  _ => '≤ $stops',
                },
                selected: _maxStops == stops,
                onTap: () => setState(() => _maxStops = stops),
              ),
          ]),
        ),
      if (widget.showSeats)
        _section(
          l10n.offerSeats,
          _pills(<Widget>[
            for (final seats in _seatOptions)
              SearchChoiceChip(
                label: seats == null ? l10n.filterAny : '$seats+',
                selected: _minSeats == seats,
                onTap: () => setState(() => _minSeats = seats),
              ),
          ]),
        ),
      if (widget.showTransmission && widget.transmissions.isNotEmpty)
        _section(
          l10n.offerTransmission,
          _pills(<Widget>[
            SearchChoiceChip(
              label: l10n.filterAny,
              selected: _transmission == null,
              onTap: () => setState(() => _transmission = null),
            ),
            for (final value in widget.transmissions)
              SearchChoiceChip(
                label: value,
                selected: _transmission == value,
                onTap: () => setState(() => _transmission = value),
              ),
          ]),
        ),
      if (widget.showAirlines && widget.airlines.isNotEmpty)
        _section(
          l10n.filterAirlines,
          _pills(<Widget>[
            for (final airline in widget.airlines)
              SearchChoiceChip(
                label: airline,
                selected: _airlines.contains(airline),
                onTap: () => _toggle(_airlines, airline),
              ),
          ]),
        ),
      if (widget.showAmenities && widget.amenities.isNotEmpty)
        _section(
          l10n.offerAmenities,
          _pills(<Widget>[
            for (final amenity in widget.amenities)
              SearchChoiceChip(
                label: amenity,
                selected: _amenities.contains(amenity),
                onTap: () => _toggle(_amenities, amenity),
              ),
          ]),
        ),
    ];

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      child: Material(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // The sheet's own grab handle — the visual exit, next to the
              // barrier tap and system back.
              ExcludeSemantics(
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.outline,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        l10n.filtersAction,
                        style: typography.title.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    AppButton(
                      label: l10n.filtersReset,
                      type: AppButtonType.ghost,
                      size: AppButtonSize.sm,
                      expanded: false,
                      onPressed: _hasSelection ? _reset : null,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    0,
                  ),
                  child: Column(
                    children: <Widget>[
                      for (var i = 0; i < sections.length; i++) ...<Widget>[
                        if (i > 0)
                          const Divider(height: 1, color: AppColors.divider),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.lg,
                          ),
                          child: sections[i],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: AppButton(label: l10n.filtersApply, onPressed: _apply),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _priceSection(AppLocalizations l10n, PriceFacet facet) {
    final typography = AppTypography.forLight();
    final start = (_priceMin ?? facet.min).clamp(facet.min, facet.max);
    final end = (_priceMax ?? facet.max).clamp(facet.min, facet.max);
    return _section(
      l10n.filterPriceRange,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${formatCardPrice(price: start, currency: facet.currency)}'
            ' – '
            '${formatCardPrice(price: end, currency: facet.currency)}',
            style: typography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          RangeSlider(
            min: facet.min,
            max: facet.max,
            values: RangeValues(start, end),
            activeColor: AppColors.brand,
            labels: RangeLabels(
              formatCardPrice(price: start, currency: facet.currency),
              formatCardPrice(price: end, currency: facet.currency),
            ),
            onChanged: (values) => setState(() {
              _priceMin = values.start;
              _priceMax = values.end;
            }),
          ),
        ],
      ),
    );
  }

  Widget _section(String label, Widget child) {
    final typography = AppTypography.forLight();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: typography.bodyLargeMedium.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        child,
      ],
    );
  }

  Widget _pills(List<Widget> chips) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: chips,
    ),
  );
}
