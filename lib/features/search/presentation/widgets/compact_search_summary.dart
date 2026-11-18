import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/core/widgets/cards/card.dart';

/// The compact "your search" summary shared by every search surface.
///
/// After a successful search the full form collapses into this single row:
/// the criteria, plus a clear edit action that reopens the form. Each page
/// owns its criteria text and its edit behaviour; this widget owns only the
/// shared presentation (leading glyph, title, meta line, edit affordance and
/// an optional page-specific trailing action), so the flight and hotel
/// summaries read as ONE control with the same dimensions and hierarchy.
///
/// The card is a single accessible button whose label names the edit action
/// and the current criteria, so a screen reader hears what a press does and
/// what will be edited.
class CompactSearchSummary extends StatelessWidget {
  const CompactSearchSummary({
    super.key,
    required this.leadingIcon,
    required this.title,
    required this.meta,
    required this.editLabel,
    required this.onEdit,
    this.trailing,
  });

  /// The leading glyph (a flight, a hotel, …).
  final IconData leadingIcon;

  /// The primary line: the route / destination.
  final String title;

  /// The secondary line: dates, travellers, cabin, …
  final String meta;

  /// The localized name of the edit action, used for the semantics label.
  final String editLabel;

  /// Reopens the full form. The page keeps its results, filters and sorting.
  final VoidCallback onEdit;

  /// Optional page-specific action (the hotel filter button), shown at the
  /// trailing edge. It must not be an edit action.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    // BaseCard owns the shared surface language: the hairline border, the
    // halo elevation and the single accessible button node.
    return BaseCard(
      onTap: onEdit,
      semanticsLabel: '$editLabel: $title, $meta',
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          Icon(
            leadingIcon,
            size: 20,
            color: context.tokigoColors.textPrimary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.bodyLargeMedium.copyWith(
                    color: context.tokigoColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.caption.copyWith(
                    color: context.tokigoColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: AppSpacing.sm),
            trailing!,
          ],
        ],
      ),
    );
  }
}
