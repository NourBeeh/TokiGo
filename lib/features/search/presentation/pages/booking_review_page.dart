import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/ui/app_button.dart';
import 'package:tokigo/core/widgets/step_progress.dart';
import 'package:tokigo/core/widgets/sticky_cta_bar.dart';
import 'package:tokigo/features/booking/application/providers/checkout_flow_providers.dart';
import 'package:tokigo/features/booking/application/services/offer_revalidation_service.dart';
import 'package:tokigo/features/booking/domain/booking_record.dart';
import 'package:tokigo/features/booking/application/booking_state.dart';
import 'package:tokigo/features/booking/application/booking_providers.dart';
import 'package:tokigo/features/search/application/providers/offer_selection_provider.dart';
import 'package:tokigo/features/bag/domain/trip.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Premium booking review — step 1 of the checkout funnel.
///
/// Shows the selected offer as a summary card, runs the prepare/revalidate
/// state machine transparently through a status timeline, and gates the
/// Continue CTA on `readyToConfirm`. All phase logic of the previous debug
/// page is preserved; only the surface is redesigned.
class BookingReviewPage extends ConsumerWidget {
  final BookingRecord? booking;
  final BookingState? state;
  final void Function()? onPrepare;
  final void Function()? onRevalidate;
  final void Function()? onAcceptPrice;
  final void Function()? onConfirm;
  final TripSummary? trip;
  final VoidCallback? onViewTrip;

  const BookingReviewPage({
    super.key,
    this.booking,
    this.state,
    this.onPrepare,
    this.onRevalidate,
    this.onAcceptPrice,
    this.onConfirm,
    this.trip,
    this.onViewTrip,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedOffer = ref.watch(selectedOfferProvider);
    final bookingState = state ?? ref.watch(bookingControllerProvider);
    final bookingNotifier = ref.read(bookingControllerProvider.notifier);
    final typography = AppTypography.forLight();
    final l10n = AppLocalizations.of(context)!;

    if (booking == null && bookingState?.record == null && selectedOffer == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: Text(
              'No booking selected',
              style: typography.body.copyWith(color: AppColors.textTertiary),
            ),
          ),
        ),
      );
    }
    final record = booking ?? bookingState?.record;
    final phase = bookingState?.phase ?? BookingPhase.idle;

    final effectivePrepare = onPrepare ??
        (selectedOffer != null
            ? () {
                bookingNotifier.prepare(
                  offerId: selectedOffer.offerId,
                  providerId: selectedOffer.providerId,
                  searchId: selectedOffer.searchId,
                );
              }
            : null);

    final effectiveRevalidate = onRevalidate ??
        (record != null
            ? () {
                bookingNotifier.revalidate(
                  bookingId: record.bookingReference,
                  oldPrice: record.authoritativePrice,
                );
              }
            : null);

    final effectiveAcceptPrice = onAcceptPrice ??
        () {
          bookingNotifier.acceptNewPrice();
        };

    final effectiveConfirm = onConfirm ??
        () {
          bookingNotifier.confirm();
        };

    final effectiveViewTrip = onViewTrip ??
        () {
          context.go('/bag');
        };

    final providerName = record?.providerName ?? selectedOffer?.providerName;
    final price = record?.authoritativePrice ?? selectedOffer?.price ?? 0;
    final currency = record?.currency ?? selectedOffer?.currency ?? 'USD';
    final offerType = selectedOffer?.offerType ?? record?.type ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Seamless merged header.
            Padding(
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
                    onPressed: () => context.canPop() ? context.pop() : context.go('/'),
                    tooltip: l10n.back,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    l10n.reviewBooking,
                    style: typography.title.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg + 44,
                AppSpacing.sm,
                AppSpacing.lg,
                0,
              ),
              child: StepProgress(current: 0, total: 3),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: <Widget>[
                  // Offer summary card.
                  _OfferSummaryCard(
                    providerName: providerName ?? '',
                    price: price,
                    currency: currency,
                    offerType: offerType,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // Phase timeline card.
                  _PhaseTimelineCard(
                    phase: phase,
                    state: bookingState,
                    onRetryPrepare: effectivePrepare,
                    onRevalidate: effectiveRevalidate,
                    onAcceptPrice: effectiveAcceptPrice,
                  ),
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
                  '$currency ${price.toStringAsFixed(2)}',
                  style: typography.title.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: _PrimaryActionForPhase(
                phase: phase,
                state: bookingState,
                onPrepare: effectivePrepare,
                onRevalidate: effectiveRevalidate,
                onAcceptPrice: effectiveAcceptPrice,
                onConfirm: effectiveConfirm,
                onViewTrip: effectiveViewTrip,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Offer summary
// ---------------------------------------------------------------------------

class _OfferSummaryCard extends StatelessWidget {
  const _OfferSummaryCard({
    required this.providerName,
    required this.price,
    required this.currency,
    required this.offerType,
  });

  final String providerName;
  final double price;
  final String currency;
  final String offerType;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.brandContainer,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              switch (offerType) {
                'flight' => Icons.flight_rounded,
                'hotel' => Icons.hotel_rounded,
                'car' => Icons.directions_car_rounded,
                'package' => Icons.card_travel_rounded,
                _ => Icons.receipt_long_rounded,
              },
              size: 24,
              color: AppColors.brand,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  offerType.isEmpty ? 'Offer' : offerType.toUpperCase(),
                  style: typography.label,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  providerName,
                  style: typography.bodyLargeMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                '$currency ${price.toStringAsFixed(2)}',
                style: typography.bodyLargeMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Phase timeline
// ---------------------------------------------------------------------------

class _PhaseTimelineCard extends StatelessWidget {
  const _PhaseTimelineCard({
    required this.phase,
    required this.state,
    required this.onRetryPrepare,
    required this.onRevalidate,
    required this.onAcceptPrice,
  });

  final BookingPhase phase;
  final BookingState? state;
  final VoidCallback? onRetryPrepare;
  final VoidCallback? onRevalidate;
  final VoidCallback? onAcceptPrice;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Status',
            style: typography.bodyLargeMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _TimelineStep(
            label: 'Preparing booking',
            state: _stepState(BookingPhase.preparing, BookingPhase.prepared),
          ),
          _TimelineStep(
            label: 'Validating price',
            state:
                _stepState(BookingPhase.revalidating, BookingPhase.readyToConfirm),
          ),
          _TimelineStep(
            label: 'Ready to confirm',
            state: phase == BookingPhase.confirmed
                ? _StepState.done
                : (phase == BookingPhase.readyToConfirm
                    ? _StepState.active
                    : _StepState.idle),
          ),
          if (phase == BookingPhase.unavailable ||
              phase == BookingPhase.failed ||
              phase == BookingPhase.error) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            _ErrorBanner(message: state?.errorMessage ?? 'Something went wrong'),
            if (phase == BookingPhase.unavailable && onRetryPrepare != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: AppButton(
                  label: 'Retry',
                  type: AppButtonType.secondary,
                  size: AppButtonSize.sm,
                  expanded: false,
                  onPressed: onRetryPrepare,
                ),
              ),
          ],
          if (phase == BookingPhase.priceChanged) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            _PriceChangedBanner(
              oldPrice: state!.preparation!.revalidation.oldPrice,
              newPrice: state!.preparation!.revalidation.authoritativePrice,
              currency: state!.preparation!.revalidation.currency,
              onAccept: onAcceptPrice,
            ),
          ],
        ],
      ),
    );
  }

  /// Maps the machine phase onto the generic prepare/validate timeline steps.
  _StepState _stepState(BookingPhase activePhase, BookingPhase donePhase) {
    if (phase == activePhase) return _StepState.active;
    if (phase.index >= donePhase.index &&
        phase != BookingPhase.unavailable &&
        phase != BookingPhase.error &&
        phase != BookingPhase.failed) {
      return _StepState.done;
    }
    return _StepState.idle;
  }
}

enum _StepState { idle, active, done }

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({required this.label, required this.state});

  final String label;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final color = switch (state) {
      _StepState.done => AppColors.success,
      _StepState.active => AppColors.brand,
      _StepState.idle => AppColors.textTertiary,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 22,
            height: 22,
            child: switch (state) {
              _StepState.done => Icon(
                  Icons.check_circle_rounded,
                  size: 22,
                  color: color,
                ),
              _StepState.active => const SizedBox(
                  width: 22,
                  height: 22,
                  child: Padding(
                    padding: EdgeInsets.all(4.5),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              _StepState.idle => Icon(
                  Icons.radio_button_unchecked_rounded,
                  size: 22,
                  color: color,
                ),
            },
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            label,
            style: typography.bodyMedium.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.dangerContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.error_outline_rounded,
              size: 18, color: AppColors.danger),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: typography.caption.copyWith(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceChangedBanner extends StatelessWidget {
  const _PriceChangedBanner({
    required this.oldPrice,
    required this.newPrice,
    required this.currency,
    this.onAccept,
  });

  final double? oldPrice;
  final double? newPrice;
  final String currency;
  final VoidCallback? onAccept;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warningContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.trending_up_rounded,
                  size: 18, color: AppColors.warning),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Price changed',
                style: typography.bodyMedium.copyWith(
                  color: AppColors.warning,
                  fontWeight: AppTypography.weightSemibold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${oldPrice?.toStringAsFixed(2)} → ${newPrice?.toStringAsFixed(2)} $currency',
            style: typography.body.copyWith(color: AppColors.onAccentContainer),
          ),
          if (onAccept != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Accept new price',
              size: AppButtonSize.sm,
              expanded: false,
              onPressed: onAccept,
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Phase CTA
// ---------------------------------------------------------------------------

class _PrimaryActionForPhase extends ConsumerWidget {
  const _PrimaryActionForPhase({
    required this.phase,
    required this.state,
    this.onPrepare,
    this.onRevalidate,
    this.onAcceptPrice,
    this.onConfirm,
    this.onViewTrip,
  });

  final BookingPhase phase;
  final BookingState? state;
  final VoidCallback? onPrepare;
  final VoidCallback? onRevalidate;
  final VoidCallback? onAcceptPrice;
  final VoidCallback? onConfirm;
  final VoidCallback? onViewTrip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    switch (phase) {
      case BookingPhase.idle:
        return AppButton(
          label: 'Prepare booking',
          onPressed: onPrepare,
        );
      case BookingPhase.preparing:
      case BookingPhase.revalidating:
        return const _ProcessingButton(label: 'Validating...');
      case BookingPhase.prepared:
        return AppButton(
          label: 'Validate price',
          onPressed: onRevalidate,
        );
      case BookingPhase.priceChanged:
        return AppButton(
          label: 'Accept new price',
          onPressed: onAcceptPrice,
        );
      case BookingPhase.readyToConfirm:
        return AppButton(
          label: l10n.continueAction,
          trailingIcon: Icons.chevron_right_rounded,
          onPressed: () async {
            // Final provider-side revalidation right before the funnel
            // (spec point 8): the frozen quote must still be live.
            final selected = ref.read(selectedOfferProvider);
            final revalidationService =
                ref.read(offerRevalidationServiceProvider);
            final outcome = await revalidationService.revalidate(
              offerId: selected?.offerId ?? state?.record?.offerId ?? '',
              providerId:
                  selected?.providerId ?? state?.record?.providerId ?? '',
              offerType: selected?.offerType ??
                  state?.record?.type ??
                  'flight',
              knownPrice: state?.record?.authoritativePrice ??
                  selected?.price,
            );

            if (!context.mounted) return;
            switch (outcome.status) {
              case RevalidationStatus.ok:
                // Seed the funnel with the live authoritative price.
                ref.read(checkoutBasePriceProvider.notifier).state =
                    outcome.price ??
                        state?.record?.authoritativePrice ??
                        selected?.price ??
                        0;
                ref.read(checkoutCurrencyProvider.notifier).state =
                    outcome.currency ??
                        state?.record?.currency ??
                        selected?.currency ??
                        'USD';
                context.push('/booking/review/passengers');
              case RevalidationStatus.priceChanged:
                // Structured PRICE_CHANGED (spec point 8): block checkout
                // until the customer accepts the new amount.
                ref.read(bookingControllerProvider.notifier).revalidate(
                      bookingId:
                          state?.record?.bookingReference ?? selected?.offerId ?? '',
                      oldPrice: outcome.oldPrice ??
                          state?.record?.authoritativePrice ??
                          selected?.price ??
                          0,
                    );
              case RevalidationStatus.unavailable:
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'This offer is no longer available. Please pick another.',
                    ),
                  ),
                );
              case RevalidationStatus.error:
                // Backend unreachable — proceed with the last validated
                // machine price rather than blocking the funnel forever.
                ref.read(checkoutBasePriceProvider.notifier).state =
                    state?.record?.authoritativePrice ??
                        selected?.price ??
                        0;
                ref.read(checkoutCurrencyProvider.notifier).state =
                    state?.record?.currency ?? selected?.currency ?? 'USD';
                context.push('/booking/review/passengers');
            }
          },
        );
      case BookingPhase.confirming:
        return const _ProcessingButton(label: 'Confirming...');
      case BookingPhase.confirmed:
        return AppButton(
          label: 'View trip',
          leadingIcon: Icons.luggage_rounded,
          onPressed: onViewTrip,
        );
      case BookingPhase.unavailable:
      case BookingPhase.failed:
      case BookingPhase.error:
        return AppButton(
          label: 'Retry',
          onPressed: onConfirm,
        );
    }
  }
}

class _ProcessingButton extends StatelessWidget {
  const _ProcessingButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 52,
      child: Center(child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      )),
    );
  }
}
