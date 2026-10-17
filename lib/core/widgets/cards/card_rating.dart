import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/widgets/cards/card_glass.dart';
import 'package:tokigo/core/widgets/cards/card_scrim_overlay.dart';

/// Star rating row. Inline by default; pass [onImage] to render as a
/// translucent dark glass pill for placement over a photo (this is the single
/// implementation the duplicated per-card rating pills should adopt).
class CardRating extends StatelessWidget {
  const CardRating({
    super.key,
    this.rating,
    this.reviewCount,
    this.onImage = false,
    this.textColor,
  });

  final double? rating;
  final int? reviewCount;

  /// Render as a dark glass pill (white text) for on-image placement.
  final bool onImage;

  /// Optional override for the value/count text colour (inline mode).
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    if (rating == null) return const SizedBox.shrink();

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star, size: 14, color: AppColors.warning),
        const SizedBox(width: 2),
        Text(
          rating!.toStringAsFixed(1),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: textColor ?? (onImage ? CardScrimColors.onScrim : null),
              ),
        ),
        if (reviewCount != null) ...[
          const SizedBox(width: 4),
          Text(
            '($reviewCount)',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: onImage
                      ? CardScrimColors.onScrimVariant
                      : (textColor ?? Theme.of(context).colorScheme.onSurfaceVariant),
                ),
          ),
        ],
      ],
    );

    if (!onImage) return content;

    return CardGlass(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      borderRadius: AppRadius.pillBorder,
      tint: const Color(0x73000000),
      borderColor: CardScrimColors.onScrimBorder,
      child: content,
    );
  }
}
