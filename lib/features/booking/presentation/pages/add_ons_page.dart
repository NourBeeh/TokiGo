import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:wetravellers/core/theme/app_colors.dart';
import 'package:wetravellers/core/theme/app_radius.dart';
import 'package:wetravellers/core/theme/app_spacing.dart';
import 'package:wetravellers/core/theme/app_typography.dart';
import 'package:wetravellers/core/ui/app_button.dart';
import 'package:wetravellers/core/widgets/sticky_cta_bar.dart';
import 'package:wetravellers/features/booking/application/providers/checkout_flow_providers.dart';
import 'package:wetravellers/l10n/app_localizations.dart';

/// Step 3 of the booking funnel — optional extras (bags, seats, insurance).
///
/// Every add-on is a selectable card with quantity steppers; the sticky bar
/// shows a live running total.
class AddOnsPage extends ConsumerStatefulWidget {
  const AddOnsPage({super.key});

  @override
  ConsumerState<AddOnsPage> createState() => _AddOnsPageState();
}

class _AddOnsPageState extends ConsumerState<AddOnsPage> {
  static const List<_AddOnDef> _catalog = <_AddOnDef>[
    _AddOnDef(
      id: 'baggage',
      label: 'Extra baggage 20kg',
      description: 'Add a 20kg checked bag to your booking',
      price: 35,
      icon: Icons.luggage_rounded,
    ),
    _AddOnDef(
      id: 'seat',
      label: 'Preferred seat',
      description: 'Window or aisle seat selection',
      price: 18,
      icon: Icons.event_seat_rounded,
    ),
    _AddOnDef(
      id: 'insurance',
      label: 'Travel insurance',
      description: 'Full trip protection and cancellation cover',
      price: 26,
      icon: Icons.shield_rounded,
    ),
    _AddOnDef(
      id: 'meal',
      label: 'Premium meal',
      description: 'Chef-curated in-flight dining',
      price: 12,
      icon: Icons.restaurant_rounded,
    ),
  ];

  final Map<String, int> _quantities = <String, int>{};

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final l10n = AppLocalizations.of(context)!;
    final basePrice = ref.watch(checkoutBasePriceProvider);
    final currency = ref.watch(checkoutCurrencyProvider);
    final addOnsTotal = _quantities.entries.fold<double>(
      0,
      (sum, entry) =>
          sum +
          _catalog
              .firstWhere((a) => a.id == entry.key)
              .price *
          entry.value,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _AddOnsHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: <Widget>[
                  for (final addon in _catalog)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _AddOnCard(
                        def: addon,
                        quantity: _quantities[addon.id] ?? 0,
                        onChanged: (q) => setState(() {
                          if (q == 0) {
                            _quantities.remove(addon.id);
                          } else {
                            _quantities[addon.id] = q;
                          }
                        }),
                      ),
                    ),
                  const SizedBox(height: 140),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomSheet: StickyCtaBar(
        child: Row(
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  l10n.total,
                  style: typography.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                Text(
                  '$currency ${(basePrice + addOnsTotal).toStringAsFixed(2)}',
                  style: typography.title.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: AppButton(
                label: l10n.continueAction,
                trailingIcon: Icons.chevron_right_rounded,
                onPressed: () {
                  ref.read(checkoutAddOnsProvider.notifier).state = <AddOnSelection>[
                    for (final entry in _quantities.entries)
                      AddOnSelection(
                        id: entry.key,
                        label: _catalog
                            .firstWhere((a) => a.id == entry.key)
                            .label,
                        price: _catalog
                            .firstWhere((a) => a.id == entry.key)
                            .price,
                        quantity: entry.value,
                      ),
                  ];
                  context.push('/booking/checkout');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddOnsHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.canPop() ? context.pop() : context.go('/booking/review'),
            tooltip: 'Back',
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'Add-ons',
            style: typography.title.copyWith(color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _AddOnCard extends StatelessWidget {
  const _AddOnCard({
    required this.def,
    required this.quantity,
    required this.onChanged,
  });

  final _AddOnDef def;
  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final selected = quantity > 0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: selected ? AppColors.brand : AppColors.outline,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.brandContainer
                  : AppColors.surfaceSecondary,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              def.icon,
              size: 22,
              color: selected ? AppColors.brand : AppColors.textTertiary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  def.label,
                  style: typography.bodyLargeMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  def.description,
                  style: typography.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '\$${def.price.toStringAsFixed(0)} each',
                  style: typography.captionSemibold.copyWith(
                    color: AppColors.brand,
                  ),
                ),
              ],
            ),
          ),
          if (selected)
            _QuantityStepper(quantity: quantity, onChanged: onChanged)
          else
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded),
              color: AppColors.brand,
              onPressed: () => onChanged(1),
              tooltip: 'Add',
            ),
        ],
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({required this.quantity, required this.onChanged});

  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
          color: AppColors.textSecondary,
          onPressed: () => onChanged(quantity - 1),
          tooltip: 'Decrease',
        ),
        Text(
          '$quantity',
          style: AppTypography.forLight().bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
          color: AppColors.brand,
          onPressed: () => onChanged(quantity + 1),
          tooltip: 'Increase',
        ),
      ],
    );
  }
}

final class _AddOnDef {
  const _AddOnDef({
    required this.id,
    required this.label,
    required this.description,
    required this.price,
    required this.icon,
  });

  final String id;
  final String label;
  final String description;
  final double price;
  final IconData icon;
}
