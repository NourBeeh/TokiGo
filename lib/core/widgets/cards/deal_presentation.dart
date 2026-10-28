import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/widgets/cards/card_badge.dart';
import 'package:tokigo/core/widgets/cards/badge_config.dart';

/// Reusable deal presentation component.
///
/// Shows deal badges (discount %, savings amount), validity date.
/// Does NOT show original/strikethrough price.
/// Does NOT show countdown.
/// Intended to be composed into existing product cards (Flight, Hotel, Car, Package)
/// in both Search and Home contexts.
class DealPresentation extends StatelessWidget {
  const DealPresentation({
    super.key,
    this.discountPercent,
    this.savingsAmount,
    this.validUntil,
    this.currency,
    this.showDiscountBadge = true,
    this.showSavingsChip = true,
    this.showValidity = true,
  });

  /// Discount percentage (e.g., 30 for 30%)
  final int? discountPercent;

  /// Savings amount in the deal currency
  final double? savingsAmount;

  /// Validity date (ISO string or DateTime)
  final dynamic validUntil;

  /// Currency code for formatting savings amount
  final String? currency;

  /// Whether to show the discount % badge
  final bool showDiscountBadge;

  /// Whether to show the savings amount chip
  final bool showSavingsChip;

  /// Whether to show the validity date
  final bool showValidity;

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try {
      final parsed = DateTime.tryParse(value.toString());
      if (parsed == null) return null;
      return parsed.isUtc ? parsed.toLocal() : parsed;
    } catch (_) {
      return null;
    }
  }

  String? _buildValidityText(DateTime? validUntil) {
    if (validUntil == null) return null;
    final now = DateTime.now();
    if (validUntil.isBefore(now)) return null;
    return 'Valid until ${DateFormat.MMMd().format(validUntil)}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final validityText = _buildValidityText(_parseDateTime(validUntil));
    final hasSavings = savingsAmount != null && savingsAmount! > 0;
    final hasDiscount = discountPercent != null && discountPercent! > 0;
    final hasValidity = validityText != null;

    if (!showDiscountBadge && !showSavingsChip && !showValidity) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Discount % badge
        if (showDiscountBadge && hasDiscount) ...[
          CardBadge(
            label: '$discountPercent% OFF',
            icon: Icons.local_offer,
            variant: CardBadgeVariant.tinted,
            type: BadgeType.discount,
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        // Savings amount chip
        if (showSavingsChip && hasSavings) ...[
          _SavingsChip(
            label:
                'Save ${NumberFormat.currency(symbol: '', locale: 'en_US').format(savingsAmount!)} ${currency ?? ''}',
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        // Validity date
        if (showValidity && hasValidity) ...[
          Row(
            children: [
              Icon(Icons.schedule, size: 12, color: scheme.onSurfaceVariant),
              const SizedBox(width: AppSpacing.xxs),
              Text(
                validityText,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Private savings chip used by DealPresentation
class _SavingsChip extends StatelessWidget {
  const _SavingsChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check, size: 10, color: AppColors.success),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.success,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
