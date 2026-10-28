import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/widgets/sticky_cta_bar.dart';

/// The pinned dark bar at the bottom of the details page (doc 18 §8).
///
/// The first line is always a REAL value the offer carries (a stay's dates and
/// night count, a flight's route, a car's window, a package's length) — never
/// filler. The price is the provider's exact total, and when there is no price
/// there is no amount: the bar says "check availability" instead of showing a
/// zero.
class OfferDetailsCtaBar extends StatelessWidget {
  const OfferDetailsCtaBar({
    super.key,
    required this.price,
    required this.currency,
    required this.contextLine,
    required this.label,
    required this.onPressed,
  });

  final double price;
  final String currency;

  /// The offer's own timing (dates / route / window).
  final String contextLine;

  /// "Book now", "Add to trip", or "Check availability".
  final String label;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    return StickyCtaBar(
      variant: StickyCtaBarVariant.dark,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (contextLine.isNotEmpty)
                  Text(
                    contextLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: typography.caption.copyWith(
                      color: AppColors.onCtaBarVariant,
                    ),
                  ),
                // Doc 18 §8 — no price, no amount. Never a zero.
                if (price > 0)
                  Text(
                    // Exact provider amount, two decimals — the same rendering
                    // the funnel uses. One line: the bar is a fixed 72pt slab,
                    // never a growing block.
                    '$currency ${price.toStringAsFixed(2)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: typography.titleMedium.copyWith(
                      color: AppColors.onCtaBar,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: _CtaButton(label: label, onPressed: onPressed),
          ),
        ],
      ),
    );
  }
}

/// The white slab inside the dark bar (doc 18 §2.6).
class _CtaButton extends StatelessWidget {
  const _CtaButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    return Material(
      color: AppColors.ctaBarButton,
      borderRadius: AppRadius.smBorder,
      child: InkWell(
        onTap: onPressed,
        borderRadius: AppRadius.smBorder,
        child: Container(
          // `alignment:` on a Container makes it fill the incoming (loose)
          // constraints — inside the bar's Row that would stretch the slab to
          // the full screen height. `Center` with factors shrink-wraps instead.
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: typography.bodyLargeMedium.copyWith(
                color: AppColors.onCtaBarButton,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
