import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:tokigo/core/domain/models/offers/hotel_offer.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/theme/tokigo_colors.dart';

/// A hotel result that carries a usable provider position.
class PlacedHotel {
  const PlacedHotel({required this.offer, required this.position});

  final HotelOffer offer;
  final LatLng position;
}

/// The hotel results on a REAL map: OpenStreetMap tiles and one marker per
/// geolocated result.
///
/// * Coordinates come ONLY from the provider's own metadata. A result with no
///   valid coordinates gets NO marker — none is ever invented.
/// * The map receives the SAME active (filtered, sorted) result set the list
///   uses, so the two views can never disagree.
/// * Tapping a marker identifies the hotel and shows a card that links to the
///   matching result's details.
/// * Tile failures and an empty geolocated set are stated honestly.
class HotelMapView extends StatefulWidget {
  const HotelMapView({
    super.key,
    required this.offers,
    required this.selectedOfferId,
    required this.onOfferSelected,
    required this.onOpenDetails,
  });

  /// The active result set (already filtered and sorted).
  final List<HotelOffer> offers;

  /// The currently selected offer, highlighted on the map.
  final String? selectedOfferId;

  /// Called when a marker is tapped.
  final ValueChanged<HotelOffer> onOfferSelected;

  /// Opens the selected hotel's details page.
  final ValueChanged<HotelOffer> onOpenDetails;

  @override
  State<HotelMapView> createState() => _HotelMapViewState();
}

class _HotelMapViewState extends State<HotelMapView> {
  final MapController _mapController = MapController();
  List<PlacedHotel> _placed = <PlacedHotel>[];
  bool _tilesFailed = false;

  @override
  void initState() {
    super.initState();
    _placed = _placeOffers(widget.offers);
  }

  @override
  void didUpdateWidget(covariant HotelMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final List<PlacedHotel> placed = _placeOffers(widget.offers);
    final bool resultsChanged =
        placed.length != _placed.length ||
        (placed.isNotEmpty &&
            _placed.isNotEmpty &&
            placed.first.position != _placed.first.position);
    _placed = placed;

    final String? selected = widget.selectedOfferId;
    if (selected != null && selected != oldWidget.selectedOfferId) {
      final PlacedHotel? match = _placed
          .where((PlacedHotel p) => p.offer.id == selected)
          .firstOrNull;
      if (match != null) _mapController.move(match.position, 14);
    } else if (resultsChanged && placed.isNotEmpty) {
      // A new search landed while the map is open: recenter on it.
      _mapController.move(placed.first.position, 11);
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  /// Keeps only the results whose provider coordinates are real and in range.
  List<PlacedHotel> _placeOffers(List<HotelOffer> offers) {
    final List<PlacedHotel> placed = <PlacedHotel>[];
    for (final HotelOffer offer in offers) {
      final double? lat = _coordinate(
        offer.metadata,
        const <String>['latitude', 'lat'],
      );
      final double? lng = _coordinate(
        offer.metadata,
        const <String>['longitude', 'lng', 'long'],
      );
      if (lat == null || lng == null) continue;
      if (!_validLat(lat) || !_validLng(lng)) continue;
      placed.add(PlacedHotel(offer: offer, position: LatLng(lat, lng)));
    }
    return placed;
  }

  static double? _coordinate(
    Map<String, dynamic> metadata,
    List<String> keys,
  ) {
    for (final String key in keys) {
      final Object? value = metadata[key];
      if (value is num) return value.toDouble();
      if (value is String) {
        final double? parsed = double.tryParse(value.trim());
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  static bool _validLat(double value) =>
      value.isFinite && value >= -90 && value <= 90;

  static bool _validLng(double value) =>
      value.isFinite && value >= -180 && value <= 180;

  LatLng get _initialCenter =>
      _placed.isEmpty ? const LatLng(30.0444, 31.2357) : _placed.first.position;

  @override
  Widget build(BuildContext context) {
    final colors = context.tokigoColors;
    final String? selected = widget.selectedOfferId;
    final HotelOffer? selectedOffer = selected == null
        ? null
        : widget.offers
              .where((HotelOffer offer) => offer.id == selected)
              .firstOrNull;

    return Stack(
      children: <Widget>[
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _initialCenter,
            initialZoom: _placed.length == 1 ? 13 : 9,
            minZoom: 3,
            maxZoom: 18,
          ),
          children: <Widget>[
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.tokigo.tokigo',
              errorTileCallback: (_, _, _) {
                if (!_tilesFailed) {
                  setState(() => _tilesFailed = true);
                }
              },
            ),
            MarkerLayer(
              markers: <Marker>[
                for (final PlacedHotel placed in _placed)
                  Marker(
                    point: placed.position,
                    width: 40,
                    height: 40,
                    child: _HotelPin(
                      selected: placed.offer.id == selected,
                      label: placed.offer.title,
                      onTap: () => widget.onOfferSelected(placed.offer),
                    ),
                  ),
              ],
            ),
          ],
        ),
        // The required OSM attribution, drawn by us so it always fits.
        Positioned(
          right: AppSpacing.xs,
          bottom: AppSpacing.xs,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: 2,
            ),
            color: colors.surface.withValues(alpha: 0.85),
            child: Text(
              '© OpenStreetMap contributors',
              style: AppTypography.forLight().caption.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
        ),
        if (_tilesFailed)
          Positioned(
            top: AppSpacing.md,
            left: AppSpacing.md,
            right: AppSpacing.md,
            child: _MapBanner(
              icon: Icons.wifi_off_rounded,
              message: 'Map tiles could not be loaded. Check your connection.',
            ),
          ),
        if (_placed.isEmpty)
          Positioned.fill(
            child: Center(
              child: _MapBanner(
                icon: Icons.location_off_outlined,
                message:
                    'No stay in these results has a mappable location. '
                    'Try a different destination or filters.',
              ),
            ),
          ),
        if (selectedOffer != null)
          Positioned(
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: AppSpacing.lg,
            child: _SelectedHotelCard(
              offer: selectedOffer,
              onOpen: () => widget.onOpenDetails(selectedOffer),
            ),
          ),
      ],
    );
  }
}

/// A single hotel marker. The selected marker is larger and filled.
class _HotelPin extends StatelessWidget {
  const _HotelPin({
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.tokigoColors;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Icon(
          selected ? Icons.location_on_rounded : Icons.location_on_outlined,
          size: selected ? 40 : 32,
          color: selected ? colors.danger : colors.brand,
        ),
      ),
    );
  }
}

/// A quiet, dismissible notice over the map (tile failure / empty results).
class _MapBanner extends StatelessWidget {
  const _MapBanner({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.tokigoColors;
    final typography = AppTypography.forLight();
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.mdBorder,
        border: Border.all(color: colors.outline),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colors.textPrimary.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 18, color: colors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              message,
              style: typography.caption.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The selected hotel's card: it identifies the hotel and links to the
/// matching result's details page.
class _SelectedHotelCard extends StatelessWidget {
  const _SelectedHotelCard({required this.offer, required this.onOpen});

  final HotelOffer offer;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.tokigoColors;
    final typography = AppTypography.forLight();
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.lgBorder,
        border: Border.all(color: colors.outline),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colors.textPrimary.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  offer.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.bodyLargeMedium.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${offer.city}, ${offer.country}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilledButton(
            onPressed: onOpen,
            style: FilledButton.styleFrom(
              backgroundColor: colors.brand,
              foregroundColor: colors.onBrand,
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            ),
            child: const Text('View details'),
          ),
        ],
      ),
    );
  }
}
