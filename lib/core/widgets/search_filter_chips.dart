import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';

/// One pill in a [SearchFilterChips] row.
@immutable
class SearchFilterChipData {
  const SearchFilterChipData({
    required this.label,
    required this.selected,
    this.onTap,
    this.semanticLabel,
    this.icon,
  });

  /// Already-localised label.
  final String label;

  /// Whether the filter is applied. Multi-select — several may be true.
  final bool selected;

  final VoidCallback? onTap;

  /// Optional screen-reader label when the visual label is an abbreviation.
  final String? semanticLabel;

  /// Optional leading glyph. The bundled fonts have no star character, so a
  /// class chip renders a Material star instead of a tofu `★`.
  final IconData? icon;
}

/// The horizontal, multi-select filter pills under a search field.
///
/// Selected pills read as brand-on-brand-container; unselected pills are a
/// quiet neutral so the row never competes with the results below it.
class SearchFilterChips extends StatelessWidget {
  const SearchFilterChips({
    super.key,
    required this.chips,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
    this.spacing = AppSpacing.sm,
  });

  final List<SearchFilterChipData> chips;

  /// Outer padding of the scrollable row.
  final EdgeInsetsGeometry padding;

  /// Gap between pills.
  final double spacing;

  /// Pill height. 40 is the reference; it keeps a 48pt touch target with
  /// vertical padding applied by the parent.
  static const double height = 40;

  @override
  Widget build(BuildContext context) {
    if (chips.isEmpty) return const SizedBox.shrink();
    final typography = AppTypography.forLight();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: <Widget>[
          for (int i = 0; i < chips.length; i++) ...<Widget>[
            if (i > 0) SizedBox(width: spacing),
            _Chip(chip: chips[i], typography: typography),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.chip, required this.typography});

  final SearchFilterChipData chip;
  final AppTypography typography;

  @override
  Widget build(BuildContext context) {
    final bool selected = chip.selected;
    return Semantics(
      button: true,
      selected: selected,
      label: chip.semanticLabel ?? chip.label,
      child: ExcludeSemantics(
        child: Material(
          color: selected
              ? AppColors.brandContainer
              : AppColors.surfaceSecondary,
          borderRadius: AppRadius.pillBorder,
          child: InkWell(
            onTap: chip.onTap,
            borderRadius: AppRadius.pillBorder,
            child: Container(
              height: SearchFilterChips.height,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              decoration: BoxDecoration(
                borderRadius: AppRadius.pillBorder,
                border: Border.all(
                  color: selected ? AppColors.brand : AppColors.outline,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (chip.icon != null) ...<Widget>[
                    Icon(
                      chip.icon,
                      size: 14,
                      color: selected ? AppColors.brand : AppColors.textPrimary,
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                  ],
                  Text(
                    chip.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    // Doc 14 §3.2: 13/600, `brand` on `brandContainer`
                    // (4.98:1 — AA at this size).
                    style: typography.captionSemibold.copyWith(
                      color: selected ? AppColors.brand : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
