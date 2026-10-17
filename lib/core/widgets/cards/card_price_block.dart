import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/widgets/cards/card_price.dart';

/// Price block with comprehensive pricing display support.
///
/// Supports current price, original price for discounts, unit pricing,
/// per-night/per-day/per-traveler, total, savings, and tax info.
/// All fields are optional; only provided fields are displayed.
class CardPriceBlock extends StatelessWidget {
  const CardPriceBlock({
    super.key,
    required this.currentPrice,
    this.currency = 'USD',
    this.color,
    this.originalColor,
    this.showCurrency = true,
    this.loading = false,

    // Original price for strikethrough
    this.originalPrice,

    // Savings
    this.savingsAmount,
    this.savingsPercentage,

    // Unit pricing
    this.unit,
    this.perNight,
    this.perDay,
    this.perTraveler,

    // Total price
    this.total,

    // Tax info
    this.taxesIncluded,
    this.taxesExcluded,

    // From price
    this.fromPrice,
  });

  /// The primary price to display
  final double currentPrice;

  /// Currency code (e.g., 'USD', 'EGP')
  final String currency;

  /// Optional color override for the primary price text
  final Color? color;

  /// Color for the strikethrough original price
  final Color? originalColor;

  /// Whether to show the currency symbol
  final bool showCurrency;

  /// Whether to show loading skeleton instead of price
  final bool loading;

  /// Original price shown as strikethrough when higher than currentPrice
  final double? originalPrice;

  /// Savings amount (e.g., 50.00)
  final double? savingsAmount;

  /// Savings percentage (e.g., 20 for 20%)
  final double? savingsPercentage;

  /// Unit label (e.g., 'night', 'day', 'person')
  final String? unit;

  /// Price per night
  final double? perNight;

  /// Price per day
  final double? perDay;

  /// Price per traveler/person
  final double? perTraveler;

  /// Total price (shown when different from currentPrice)
  final double? total;

  /// Whether taxes are included
  final bool? taxesIncluded;

  /// Whether taxes are excluded (extra)
  final bool? taxesExcluded;

  /// Starting from price (e.g., "from EGP 500")
  final String? fromPrice;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const _PriceSkeleton();
    }

    final scheme = Theme.of(context).colorScheme;
    final hasDiscount = originalPrice != null && originalPrice! > currentPrice;
    final hasSavingsAmount = savingsAmount != null && savingsAmount! > 0;
    final hasSavingsPercentage = savingsPercentage != null && savingsPercentage! > 0;

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        // From price
        if (fromPrice != null && fromPrice!.isNotEmpty) ...[
          Text(
            'from ',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          Text(
            formatCardPrice(price: double.tryParse(fromPrice!), currency: currency, showCurrency: showCurrency),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
          ),
        ] else ...[
          // Primary price
          Text(
            formatCardPrice(price: currentPrice, currency: currency, showCurrency: showCurrency),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
          ),
        ],

        // Unit (e.g., /night, /day, /person)
        if (unit != null && unit!.isNotEmpty)
          Text(
            '/${unit!}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),

        // Per night / day / person (shown as secondary price lines)
        if (perNight != null && perNight! > 0)
          _SecondaryPriceLine(label: '/night', value: perNight!, currency: currency),
        if (perDay != null && perDay! > 0)
          _SecondaryPriceLine(label: '/day', value: perDay!, currency: currency),
        if (perTraveler != null && perTraveler! > 0)
          _SecondaryPriceLine(label: '/person', value: perTraveler!, currency: currency),

        // Total price
        if (total != null && total! > 0 && total! != currentPrice)
          _SecondaryPriceLine(
            label: 'total',
            value: total!,
            currency: currency,
            isTotal: true,
          ),

        // Original price (strikethrough)
        if (hasDiscount) ...[
          const SizedBox(width: AppSpacing.xs),
          Text(
            formatCardPrice(price: originalPrice, currency: currency, showCurrency: showCurrency),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  decoration: TextDecoration.lineThrough,
                  color: originalColor ?? scheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
          ),
        ],

        // Savings amount
        if (hasSavingsAmount)
          _SavingsChip(label: 'Save ${formatCardPrice(price: savingsAmount, currency: currency, showCurrency: showCurrency)}'),

        // Savings percentage
        if (hasSavingsPercentage)
          _SavingsChip(label: 'Save ${savingsPercentage!.toInt()}%'),

        // Tax info
        if (taxesIncluded == true)
          _TaxInfoChip(label: 'Taxes included', isIncluded: true),
        if (taxesExcluded == true)
          _TaxInfoChip(label: 'Taxes extra', isIncluded: false),
      ],
    );
  }
}

/// Secondary price line (e.g., /night, /day, total)
class _SecondaryPriceLine extends StatelessWidget {
  const _SecondaryPriceLine({
    required this.label,
    required this.value,
    required this.currency,
    this.isTotal = false,
  });

  final String label;
  final double value;
  final String currency;
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: isTotal ? scheme.onSurface : scheme.onSurfaceVariant,
          fontWeight: isTotal ? FontWeight.w600 : FontWeight.w400,
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        const SizedBox(width: AppSpacing.xxs),
        Flexible(
          child: Text(
            formatCardPrice(price: value, currency: currency),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }
}

/// Savings chip (green for positive savings)
class _SavingsChip extends StatelessWidget {
  const _SavingsChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
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

/// Tax info chip
class _TaxInfoChip extends StatelessWidget {
  const _TaxInfoChip({required this.label, required this.isIncluded});

  final String label;
  final bool isIncluded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = isIncluded ? AppColors.success : scheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
      ),
    );
  }
}

class _PriceSkeleton extends StatefulWidget {
  const _PriceSkeleton();

  @override
  State<_PriceSkeleton> createState() => _PriceSkeletonState();
}

class _PriceSkeletonState extends State<_PriceSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 0.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          height: 24,
          width: 80,
          decoration: BoxDecoration(
            color: AppColors.surfaceTertiary.withValues(alpha: 0.3 * _animation.value),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      },
    );
  }
}