import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/ui/app_button.dart';
import 'package:tokigo/core/ui/app_message_state.dart';
import 'package:tokigo/core/widgets/ai_entrance_animation.dart';
import 'package:tokigo/core/widgets/page_header.dart';
import 'package:tokigo/core/widgets/step_progress.dart';
import 'package:tokigo/core/widgets/sticky_cta_bar.dart';
import 'package:tokigo/features/booking/application/providers/checkout_flow_providers.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Step 3 of the booking funnel — optional extras (bags, seats, meals).
///
/// **OWNER DECISION (2026-10-19): an add-on price is the PROVIDER's price.**
/// This step used to offer four invented extras with invented prices written
/// into the code (baggage 35, seat 18, insurance 26, meal 12) and added them to
/// a real, payable booking total — a fabricated price inside a real checkout.
/// Those numbers are gone. The step stays where it is (the funnel keeps its 3
/// steps and the checkout contract is untouched: it still consumes
/// [checkoutAddOnsProvider]) but it now states the truth — extras are priced by
/// the airline for the specific fare, and they will appear here with the
/// provider's own prices once that feed is connected. Until then it offers
/// nothing to select and adds nothing to the total, instead of guessing.
class AddOnsPage extends ConsumerWidget {
  const AddOnsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typography = AppTypography.forLight();
    final l10n = AppLocalizations.of(context)!;
    final basePrice = ref.watch(checkoutBasePriceProvider);
    final currency = ref.watch(checkoutCurrencyProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: AiEntranceAnimation(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AppPageHeader(
                title: l10n.addOns,
                steps: const StepProgress(current: 2, total: 4),
                backFallbackLocation: '/booking/review',
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: AppMessageState(
                    icon: Icons.luggage_outlined,
                    title: l10n.addOnsProviderTitle,
                    body: l10n.addOnsProviderBody,
                  ),
                ),
              ),
            ],
          ),
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
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  '$currency ${basePrice.toStringAsFixed(2)}',
                  maxLines: 1,
                  style: typography.titleMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
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
                  // No provider extras to carry: the selection is explicitly
                  // empty (the checkout keeps reading the same provider).
                  ref.read(checkoutAddOnsProvider.notifier).state =
                      <AddOnSelection>[];
                  context.push('/booking/review/checkout');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
