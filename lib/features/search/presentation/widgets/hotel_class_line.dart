import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_spacing.dart';

/// The hotel's identity line: its own star class and where it is — an outline
/// star, the class, a dot, then the place (for example `5 · Cairo, Egypt`).
///
/// ONE widget for the result card and the details page so the two readings of
/// the same offer cannot drift. The outline star means the hotel's **class**
/// (the provider's classification); a filled star always means the guest review
/// score. Only the parts the provider sent are rendered — a hotel with no
/// reported class shows its location alone, and one with neither shows nothing.
///
/// A `★` text glyph is never used: the bundled fonts have no U+2605 and render
/// a tofu box.
class HotelClassLocationLine extends StatelessWidget {
  const HotelClassLocationLine({
    super.key,
    required this.stars,
    required this.city,
    required this.country,
    this.style,
    this.iconSize = 14,
    this.maxLines = 1,
    this.starColor = AppColors.textSecondary,
  });

  /// The provider's star classification (1–5), or null when it sent none.
  final int? stars;
  final String city;
  final String country;
  final TextStyle? style;
  final double iconSize;
  final int maxLines;

  /// The class star's ink. The details sheet asks for bronze (`accent`);
  /// result cards keep the neutral default.
  final Color starColor;

  @override
  Widget build(BuildContext context) {
    final stars = this.stars;
    final place = <String>[
      if (city.trim().isNotEmpty) city.trim(),
      if (country.trim().isNotEmpty) country.trim(),
    ].join(', ');
    if (stars == null && place.isEmpty) return const SizedBox.shrink();

    final typography =
        style ??
        Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary);

    return Row(
      children: <Widget>[
        if (stars != null) ...<Widget>[
          Icon(Icons.star_outline_rounded, size: iconSize, color: starColor),
          const SizedBox(width: AppSpacing.xxs),
          Text('$stars', style: typography),
        ],
        if (stars != null && place.isNotEmpty) ...<Widget>[
          const SizedBox(width: AppSpacing.sm),
          Text('·', style: typography),
          const SizedBox(width: AppSpacing.sm),
        ],
        if (place.isNotEmpty) ...<Widget>[
          Icon(
            Icons.location_on_outlined,
            size: iconSize,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              place,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: typography,
            ),
          ),
        ],
      ],
    );
  }
}
