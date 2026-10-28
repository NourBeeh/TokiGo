import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/widgets/cards/base_card.dart';
import 'package:tokigo/core/widgets/step_progress.dart';

/// Card H — the booking status card (reference C-8).
///
/// One booked item: what it is, when, its live status and the provider's own
/// reference. No price and no membership badge — this card answers "is my
/// booking okay?", not "what did it cost?".
class BookingStatusCard extends StatelessWidget {
  const BookingStatusCard({
    super.key,
    required this.title,
    this.meta,
    this.statusLabel,
    this.tone = BookingStatusTone.confirmed,
    this.reference,
    this.leading,
    this.onTap,
    this.semanticsLabel,
  });

  final String title;

  /// "Barcelona · 7-9 Dec" — dates and place, already localised.
  final String? meta;

  /// The status word. The chip renders only when this is set.
  final String? statusLabel;
  final BookingStatusTone tone;

  /// The booking reference the backend returned. Never generated here.
  final String? reference;

  /// Optional 44pt leading visual (thumb or service glyph).
  final Widget? leading;

  final VoidCallback? onTap;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    return BaseCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      semanticsLabel: semanticsLabel ?? title,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (leading != null) ...<Widget>[
            SizedBox(width: 44, height: 44, child: leading),
            const SizedBox(width: AppSpacing.md),
          ],
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
                    color: AppColors.textPrimary,
                  ),
                ),
                if (meta != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    meta!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: typography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (statusLabel != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: StatusChip.forTone(label: statusLabel!, tone: tone),
                  ),
                ],
                if (reference != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    reference!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.ltr,
                    style: typography.caption.copyWith(
                      color: AppColors.textTertiary,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Icon(
            Icons.chevron_right,
            size: 20,
            color: AppColors.textTertiary,
          ),
        ],
      ),
    );
  }
}
