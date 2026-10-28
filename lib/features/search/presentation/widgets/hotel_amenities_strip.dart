import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';

/// The amenities strip of the hotel details page — the reference's icon row,
/// built from the provider's OWN amenity strings, verbatim.
///
/// Nothing is renamed and nothing is added: a label the provider did not send
/// does not appear, and an amenity whose words we do not recognize keeps its
/// own words under the neutral "listed fact" icon rather than being filed under
/// a category we guessed at.
class HotelAmenitiesStrip extends StatelessWidget {
  const HotelAmenitiesStrip({super.key, required this.amenities});

  final List<String> amenities;

  /// Doc 18 §2.5 — four equal columns, gap `sm`, icon over label.
  static const int _perRow = 4;

  @override
  Widget build(BuildContext context) {
    final visible = amenities
        .map((a) => a.trim())
        .where((a) => a.isNotEmpty)
        .toList(growable: false);
    if (visible.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = AppSpacing.sm;
        final tileWidth =
            (constraints.maxWidth - gap * (_perRow - 1)) / _perRow;
        return Wrap(
          spacing: gap,
          runSpacing: AppSpacing.md,
          children: <Widget>[
            for (final amenity in visible)
              SizedBox(
                width: tileWidth,
                child: _AmenityTile(label: amenity),
              ),
          ],
        );
      },
    );
  }
}

class _AmenityTile extends StatelessWidget {
  const _AmenityTile({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    return Column(
      children: <Widget>[
        // The sheet's own surface, no plate: the icon is the mark.
        Icon(hotelAmenityIcon(label), size: 22, color: AppColors.starFill),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: typography.caption.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

/// The icon a well-known amenity reads best with.
///
/// Provider amenities are free text, so the match is keyword-based and
/// case-insensitive; anything unrecognized keeps the neutral check — an honest
/// "this is a listed facility", never a guessed category.
IconData hotelAmenityIcon(String amenity) {
  final value = amenity.toLowerCase();
  bool has(List<String> keys) => keys.any(value.contains);

  if (has(<String>['wifi', 'wi-fi', 'internet'])) return Icons.wifi_rounded;
  if (has(<String>['pool', 'swim'])) return Icons.pool_rounded;
  if (has(<String>['restaurant', 'dining', 'bistro'])) {
    return Icons.restaurant_rounded;
  }
  if (has(<String>['breakfast'])) return Icons.free_breakfast_rounded;
  if (has(<String>['parking', 'garage', 'valet'])) {
    return Icons.local_parking_rounded;
  }
  if (has(<String>['shuttle', 'airport', 'transfer'])) {
    return Icons.airport_shuttle_rounded;
  }
  if (has(<String>['gym', 'fitness', 'workout'])) {
    return Icons.fitness_center_rounded;
  }
  if (has(<String>['spa', 'sauna', 'massage', 'steam'])) {
    return Icons.spa_rounded;
  }
  if (has(<String>['bar', 'lounge', 'nightclub'])) {
    return Icons.local_bar_rounded;
  }
  if (has(<String>['beach', 'seaside'])) return Icons.beach_access_rounded;
  if (has(<String>['air condition', 'air-condition', 'climate', 'a/c'])) {
    return Icons.ac_unit_rounded;
  }
  if (has(<String>['pet'])) return Icons.pets_rounded;
  if (has(<String>['laundry', 'dry clean'])) {
    return Icons.local_laundry_service_rounded;
  }
  if (has(<String>['business', 'meeting', 'conference'])) {
    return Icons.business_center_rounded;
  }
  if (has(<String>['room service', 'concierge', '24-hour'])) {
    return Icons.room_service_rounded;
  }
  if (has(<String>['tv', 'television'])) return Icons.tv_rounded;
  if (has(<String>['safe', 'security', 'surveillance'])) {
    return Icons.lock_rounded;
  }
  if (has(<String>['elevator', 'lift'])) return Icons.elevator_rounded;
  if (has(<String>['accessible', 'wheelchair'])) {
    return Icons.accessible_rounded;
  }
  if (has(<String>['kitchen', 'kitchenette', 'microwave'])) {
    return Icons.kitchen_rounded;
  }
  if (has(<String>['terrace', 'garden', 'balcony'])) return Icons.deck_rounded;
  if (has(<String>['family', 'child'])) return Icons.family_restroom_rounded;
  if (has(<String>['smoking'])) return Icons.smoking_rooms_rounded;
  return Icons.check_circle_outline_rounded;
}
