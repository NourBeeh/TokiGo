import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/ui/app_button.dart';
import 'package:tokigo/core/widgets/ai_entrance_animation.dart';
import 'package:tokigo/core/widgets/page_header.dart';
import 'package:tokigo/core/widgets/step_progress.dart';
import 'package:tokigo/core/widgets/sticky_cta_bar.dart';
import 'package:tokigo/features/booking/application/providers/checkout_flow_providers.dart';
import 'package:tokigo/features/booking/domain/booking_record.dart';
import 'package:tokigo/features/booking/domain/price_change.dart';
import 'package:tokigo/features/booking/application/booking_state.dart';
import 'package:tokigo/features/booking/application/booking_providers.dart';
import 'package:tokigo/features/search/application/providers/offer_selection_provider.dart';
import 'package:tokigo/features/bag/domain/trip.dart';
import 'package:tokigo/l10n/app_localizations.dart';
import 'package:tokigo/core/ui/directional_icons.dart';

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
  final void Function()? onDeclinePriceChange;
  final void Function()? onChooseAnotherOffer;
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
    this.onDeclinePriceChange,
    this.onChooseAnotherOffer,
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

    if (booking == null &&
        bookingState?.record == null &&
        selectedOffer == null) {
      return Scaffold(
        backgroundColor: context.tokigoColors.background,
        body: SafeArea(
          bottom: false,
          child: AiEntranceAnimation(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // The empty state is still a pushed page: it keeps the same
                // header (and therefore the same back contract) as the loaded
                // one instead of stranding the user with no way back.
                AppPageHeader(subtitle: l10n.reviewBookingSubtitle),
                Expanded(
                  child: Center(
                    child: Text(
                      l10n.bookingNoSelection,
                      style: typography.body.copyWith(
                        color: context.tokigoColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final record = booking ?? bookingState?.record;
    final phase = bookingState?.phase ?? BookingPhase.idle;

    final effectivePrepare =
        onPrepare ??
        (selectedOffer != null
            ? () {
                bookingNotifier.prepare(
                  offerId: selectedOffer.offerId,
                  providerId: selectedOffer.providerId,
                  searchId: selectedOffer.searchId,
                );
              }
            : null);

    final effectiveRevalidate =
        onRevalidate ??
        (record != null
            ? () {
                bookingNotifier.revalidate(bookingId: record.bookingId);
              }
            : null);

    final effectiveAcceptPrice =
        onAcceptPrice ??
        () {
          bookingNotifier.acceptNewPrice();
        };

    final effectiveDeclinePriceChange =
        onDeclinePriceChange ??
        () async {
          final declined = await bookingNotifier.declinePriceChange();
          if (declined && context.mounted) {
            _leaveReview(context);
          }
        };

    final effectiveChooseAnotherOffer =
        onChooseAnotherOffer ??
        () {
          _leaveReview(context);
        };

    final effectiveConfirm =
        onConfirm ??
        () {
          bookingNotifier.confirm();
        };

    final effectiveViewTrip =
        onViewTrip ??
        () {
          context.go('/bag');
        };

    final providerName = record?.providerName ?? selectedOffer?.providerName;
    final price = record?.authoritativePrice ?? selectedOffer?.price ?? 0;
    final currency = record?.currency ?? selectedOffer?.currency ?? 'USD';
    final offerType = selectedOffer?.offerType ?? record?.type ?? '';

    return Scaffold(
      backgroundColor: context.tokigoColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Seamless merged header. The step bar lives in the header's own
            // slot (doc 21 §1.1), not in a hand-rolled row under it.
            AppPageHeader(
              subtitle: l10n.reviewBookingSubtitle,
              steps: const StepProgress(current: 0, total: 4),
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
                    onDeclinePriceChange: effectiveDeclinePriceChange,
                    onChooseAnotherOffer: effectiveChooseAnotherOffer,
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
                    color: context.tokigoColors.textSecondary,
                  ),
                ),
                Text(
                  '$currency ${price.toStringAsFixed(2)}',
                  maxLines: 1,
                  style: typography.titleMedium.copyWith(
                    color: context.tokigoColors.textPrimary,
                    fontWeight: FontWeight.w800,
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
                onDeclinePriceChange: effectiveDeclinePriceChange,
                onChooseAnotherOffer: effectiveChooseAnotherOffer,
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
    final typography = Theme.of(context).brightness == Brightness.dark
        ? AppTypography.forDark()
        : AppTypography.forLight();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.tokigoColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: context.tokigoColors.outline),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: AppSpacing.minimumTapTarget,
            height: AppSpacing.minimumTapTarget,
            decoration: BoxDecoration(
              color: context.tokigoColors.brandContainer,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              switch (offerType) {
                'flight' => Icons.flight_rounded,
                'hotel' => Icons.house_rounded,
                'car' => Icons.directions_car_rounded,
                'package' => Icons.card_travel_rounded,
                _ => Icons.receipt_long_rounded,
              },
              size: 24,
              color: context.tokigoColors.brand,
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
                    color: context.tokigoColors.textPrimary,
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
                style: typography.titleMedium.copyWith(
                  color: context.tokigoColors.textPrimary,
                  fontWeight: FontWeight.w800,
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
    required this.onDeclinePriceChange,
    required this.onChooseAnotherOffer,
  });

  final BookingPhase phase;
  final BookingState? state;
  final VoidCallback? onRetryPrepare;
  final VoidCallback? onRevalidate;
  final VoidCallback? onAcceptPrice;
  final VoidCallback? onDeclinePriceChange;
  final VoidCallback? onChooseAnotherOffer;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.tokigoColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: context.tokigoColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.bookingStatusTitle,
            style: typography.bodyLargeMedium.copyWith(
              color: context.tokigoColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _TimelineStep(
            label: l10n.bookingStepPreparing,
            state: _stepState(BookingPhase.preparing, BookingPhase.prepared),
          ),
          _TimelineStep(
            label: l10n.bookingStepValidatingPrice,
            state: _stepState(
              BookingPhase.revalidating,
              BookingPhase.readyToConfirm,
            ),
          ),
          _TimelineStep(
            label: l10n.bookingStepReady,
            state: phase == BookingPhase.confirmed
                ? _StepState.done
                : (phase == BookingPhase.readyToConfirm
                      ? _StepState.active
                      : _StepState.idle),
          ),
          if (phase == BookingPhase.unavailable ||
              phase == BookingPhase.expired ||
              phase == BookingPhase.failed ||
              phase == BookingPhase.error) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            _ErrorBanner(
              message: state?.errorMessage ?? 'Something went wrong',
            ),
            if ((phase == BookingPhase.unavailable ||
                    phase == BookingPhase.expired) &&
                onChooseAnotherOffer != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: AppButton(
                  label: l10n.bookingChooseAnotherOffer,
                  type: AppButtonType.secondary,
                  size: AppButtonSize.sm,
                  expanded: false,
                  onPressed: onChooseAnotherOffer,
                ),
              )
            else if (onRetryPrepare != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: AppButton(
                  label: l10n.retry,
                  type: AppButtonType.secondary,
                  size: AppButtonSize.sm,
                  expanded: false,
                  onPressed: onRetryPrepare,
                ),
              ),
          ],
          if (phase == BookingPhase.reconciliationPending) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            _PendingVerificationBanner(
              title: l10n.bookingOutcomePendingTitle,
              message: l10n.bookingOutcomePendingBody,
            ),
          ],
          if (phase == BookingPhase.priceChanged) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            if (state?.record?.priceChange != null)
              _PriceChangedBanner(
                change: state!.record!.priceChange!,
                onAccept: onAcceptPrice,
                onDecline: onDeclinePriceChange,
              )
            else
              _ErrorBanner(
                message: state?.errorMessage ?? l10n.bookingRevalidationFailed,
              ),
          ],
          if (phase == BookingPhase.priceChangeDeclined) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            _ErrorBanner(message: l10n.bookingPriceChangeDeclined),
            if (onChooseAnotherOffer != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: AppButton(
                  label: l10n.bookingChooseAnotherOffer,
                  type: AppButtonType.secondary,
                  size: AppButtonSize.sm,
                  expanded: false,
                  onPressed: onChooseAnotherOffer,
                ),
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
        phase != BookingPhase.expired &&
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
      _StepState.done => context.tokigoColors.onSuccessContainer,
      _StepState.active => context.tokigoColors.brand,
      _StepState.idle => context.tokigoColors.textSecondary,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: AppSpacing.xl,
            height: AppSpacing.xl,
            child: switch (state) {
              _StepState.done => Icon(
                Icons.check_circle_rounded,
                size: AppSpacing.xl,
                color: color,
              ),
              _StepState.active => const SizedBox(
                width: AppSpacing.xl,
                height: AppSpacing.xl,
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xs),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              _StepState.idle => Icon(
                Icons.radio_button_unchecked_rounded,
                size: AppSpacing.xl,
                color: color,
              ),
            },
          ),
          const SizedBox(width: AppSpacing.md),
          Text(label, style: typography.bodyMedium.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _PendingVerificationBanner extends StatelessWidget {
  const _PendingVerificationBanner({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.tokigoColors.warningContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.hourglass_top_rounded,
                size: 18,
                color: context.tokigoColors.onWarningContainer,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: typography.bodyMedium.copyWith(
                    color: context.tokigoColors.onWarningContainer,
                    fontWeight: AppTypography.weightSemibold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: typography.caption.copyWith(
              color: context.tokigoColors.onWarningContainer,
            ),
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
        color: context.tokigoColors.dangerContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: context.tokigoColors.danger,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: typography.caption.copyWith(
                color: context.tokigoColors.onDangerContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceChangedBanner extends StatelessWidget {
  const _PriceChangedBanner({
    required this.change,
    this.onAccept,
    this.onDecline,
  });

  final PriceChangeConfirmation change;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final l10n = AppLocalizations.of(context)!;
    final String currency = change.currency;
    final double? previous = change.previousPrice;
    final double difference = change.priceDifference;
    final double? percent = change.priceChangePercent;
    final String differenceSign = difference > 0 ? '+' : '';
    final String percentText = percent == null
        ? ''
        : ' (${percent > 0 ? '+' : ''}${percent.toStringAsFixed(2)}%)';
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.tokigoColors.warningContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                change.priceChanged
                    ? Icons.trending_up_rounded
                    : Icons.info_outline_rounded,
                size: 18,
                color: context.tokigoColors.onWarningContainer,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l10n.bookingPriceChanged,
                  style: typography.bodyMedium.copyWith(
                    color: context.tokigoColors.onWarningContainer,
                    fontWeight: AppTypography.weightSemibold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (previous != null) ...<Widget>[
            Text(
              '${l10n.bookingPreviousPrice}: '
              '${previous.toStringAsFixed(2)} $currency',
              style: typography.caption.copyWith(
                color: context.tokigoColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          Text(
            '${l10n.bookingUpdatedPrice}: '
            '${change.currentPrice.toStringAsFixed(2)} $currency',
            style: typography.bodyLargeMedium.copyWith(
              color: context.tokigoColors.textPrimary,
            ),
          ),
          if (change.priceChanged) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${l10n.bookingPriceDifference}: '
              '$differenceSign${difference.abs().toStringAsFixed(2)} '
              '$currency$percentText',
              style: typography.body.copyWith(
                color: context.tokigoColors.textPrimary,
              ),
            ),
          ],
          if (change.termsChanged) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.bookingConditionsChanged,
              style: typography.bodyMedium.copyWith(
                color: context.tokigoColors.onWarningContainer,
                fontWeight: AppTypography.weightSemibold,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final String term in change.changedTerms)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(
                  '• ${_termLabel(l10n, term)}',
                  style: typography.caption.copyWith(
                    color: context.tokigoColors.textPrimary,
                  ),
                ),
              ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.bookingNoChargeYet,
            style: typography.caption.copyWith(
              color: context.tokigoColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              if (onAccept != null)
                AppButton(
                  label: l10n.bookingUpdatePrice,
                  size: AppButtonSize.sm,
                  expanded: false,
                  onPressed: onAccept,
                ),
              if (onDecline != null)
                AppButton(
                  label: l10n.bookingDeclinePriceChange,
                  type: AppButtonType.secondary,
                  size: AppButtonSize.sm,
                  expanded: false,
                  onPressed: onDecline,
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Localized label for a changed terms key. Unknown provider keys are shown
  /// verbatim — a condition is never hidden because the client lacks a label.
  static String _termLabel(AppLocalizations l10n, String key) {
    return switch (key) {
      'conditions' => l10n.bookingTermFareConditions,
      'baggageAllowances' => l10n.bookingTermBaggage,
      'fareBrand' => l10n.bookingTermFareBrand,
      'cabinClass' => l10n.bookingTermCabin,
      'segments' => l10n.bookingTermItinerary,
      'cancellationChanged' => l10n.bookingTermCancellation,
      'boardChanged' => l10n.bookingTermBoard,
      _ => key,
    };
  }
}

// ---------------------------------------------------------------------------
// Phase CTA
// ---------------------------------------------------------------------------

class _PrimaryActionForPhase extends ConsumerStatefulWidget {
  const _PrimaryActionForPhase({
    required this.phase,
    required this.state,
    this.onPrepare,
    this.onRevalidate,
    this.onAcceptPrice,
    this.onDeclinePriceChange,
    this.onChooseAnotherOffer,
    this.onConfirm,
    this.onViewTrip,
  });

  final BookingPhase phase;
  final BookingState? state;
  final VoidCallback? onPrepare;
  final VoidCallback? onRevalidate;
  final VoidCallback? onAcceptPrice;
  final VoidCallback? onDeclinePriceChange;
  final VoidCallback? onChooseAnotherOffer;
  final VoidCallback? onConfirm;
  final VoidCallback? onViewTrip;

  @override
  ConsumerState<_PrimaryActionForPhase> createState() =>
      _PrimaryActionForPhaseState();
}

class _PrimaryActionForPhaseState
    extends ConsumerState<_PrimaryActionForPhase> {
  /// Guards the pre-checkout offer check against a double tap. A second tap
  /// while the check is in flight would fire a second provider call.
  bool _checkingOffer = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    switch (widget.phase) {
      case BookingPhase.idle:
        return AppButton(
          label: l10n.bookingPrepare,
          onPressed: widget.onPrepare,
        );
      case BookingPhase.preparing:
      case BookingPhase.revalidating:
        return _ProcessingButton(label: l10n.bookingValidating);
      case BookingPhase.prepared:
        return AppButton(
          label: l10n.bookingValidatePrice,
          onPressed: widget.onRevalidate,
        );
      case BookingPhase.priceChanged:
        return AppButton(
          label: l10n.bookingUpdatePrice,
          onPressed: widget.onAcceptPrice,
        );
      case BookingPhase.priceChangeDeclined:
        return AppButton(
          label: l10n.bookingChooseAnotherOffer,
          onPressed: widget.onChooseAnotherOffer,
        );
      case BookingPhase.readyToConfirm:
        if (_checkingOffer) {
          return _ProcessingButton(label: l10n.bookingValidating);
        }
        return AppButton(
          label: l10n.continueAction,
          trailingIcon: DirectionalIcons.chevron(context),
          onPressed: _checkOfferAndContinue,
        );
      case BookingPhase.confirming:
        return _ProcessingButton(label: l10n.bookingConfirming);
      case BookingPhase.confirmed:
        return AppButton(
          label: l10n.bookingViewTrip,
          leadingIcon: Icons.luggage_rounded,
          onPressed: widget.onViewTrip,
        );
      case BookingPhase.unavailable:
      case BookingPhase.expired:
        // The selected offer is gone. Another offer must be selected; retrying
        // the same expired offerId cannot help.
        return AppButton(
          label: l10n.bookingChooseAnotherOffer,
          onPressed: widget.onChooseAnotherOffer,
        );
      case BookingPhase.error:
        // The check itself failed — retrying the review revalidation is safe
        // and does not proceed on an unverified price.
        return AppButton(label: l10n.retry, onPressed: widget.onRevalidate);
      case BookingPhase.failed:
        return AppButton(label: l10n.retry, onPressed: widget.onConfirm);
      case BookingPhase.reconciliationPending:
        // No retry: the provider outcome is unknown and a resubmission could
        // double-book or double-charge. The only safe exit is leaving the
        // funnel; the pending state stays visible until reconciliation ends.
        return AppButton(
          label: l10n.bookingBackHome,
          onPressed: () => context.go('/'),
        );
    }
  }

  Future<void> _checkOfferAndContinue() async {
    if (_checkingOffer) return;
    final record = widget.state?.record;
    if (record == null) return;
    setState(() => _checkingOffer = true);
    try {
      // Single revalidation path: the booking endpoint revalidates the exact
      // prepared offer through its provider adapter (read-only for Duffel /
      // Nuitee flights, documented prebook for Nuitee hotels). The review page
      // must never call the generic offer endpoint in addition to this, or a
      // Nuitee hotel hold would be created twice.
      await ref
          .read(bookingControllerProvider.notifier)
          .revalidate(bookingId: record.bookingId);
      if (!mounted) return;

      final latest = ref.read(bookingControllerProvider);
      if (latest.phase == BookingPhase.readyToConfirm) {
        final live = latest.record ?? record;
        // Seed the funnel with the live authoritative price, never the stale
        // review snapshot.
        ref.read(checkoutBasePriceProvider.notifier).state =
            live.authoritativePrice;
        ref.read(checkoutCurrencyProvider.notifier).state = live.currency;
        context.push('/booking/review/passengers');
      }
      // priceChanged / priceChangeDeclined / unavailable / expired / error:
      // the controller state renders the correct banner and CTA. Nothing is
      // navigated and nothing is charged.
    } finally {
      if (mounted) setState(() => _checkingOffer = false);
    }
  }
}

class _ProcessingButton extends StatelessWidget {
  const _ProcessingButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tc = context.tokigoColors;
    final typography = Theme.of(context).brightness == Brightness.dark
        ? AppTypography.forDark()
        : AppTypography.forLight();
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        height: 52,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: typography.bodyMedium.copyWith(color: tc.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Returns to the previous offer selection. The review page is normally
/// pushed from search results / offer details; a deep link that has nothing
/// to pop falls back to Home instead of stranding the traveller.
void _leaveReview(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/');
  }
}
