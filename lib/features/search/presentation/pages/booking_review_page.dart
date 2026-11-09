import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/theme/app_colors.dart';
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
    final tc = context.tokigoColors;
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
                        color: context.tokigoColors.textTertiary,
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
                bookingNotifier.revalidate(
                  bookingId: record.bookingId,
                  oldPrice: record.authoritativePrice,
                );
              }
            : null);

    final effectiveAcceptPrice =
        onAcceptPrice ??
        () {
          bookingNotifier.acceptNewPrice();
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
    final tc = context.tokigoColors;
    final typography = AppTypography.forLight();
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
            width: 48,
            height: 48,
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
                style: typography.bodyLargeMedium.copyWith(
                  color: context.tokigoColors.textPrimary,
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
    final tc = context.tokigoColors;
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
                onRetryPrepare != null)
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
    final tc = context.tokigoColors;
    final typography = AppTypography.forLight();
    final color = switch (state) {
      _StepState.done => context.tokigoColors.success,
      _StepState.active => context.tokigoColors.brand,
      _StepState.idle => context.tokigoColors.textTertiary,
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
          Text(label, style: typography.bodyMedium.copyWith(color: color)),
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
    final tc = context.tokigoColors;
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
              style: typography.caption.copyWith(color: context.tokigoColors.danger),
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
    final tc = context.tokigoColors;
    final typography = AppTypography.forLight();
    final l10n = AppLocalizations.of(context)!;
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
                Icons.trending_up_rounded,
                size: 18,
                color: context.tokigoColors.warning,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                l10n.bookingPriceChanged,
                style: typography.bodyMedium.copyWith(
                  color: context.tokigoColors.warning,
                  fontWeight: AppTypography.weightSemibold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${oldPrice?.toStringAsFixed(2)} → ${newPrice?.toStringAsFixed(2)} $currency',
            style: typography.body.copyWith(color: context.tokigoColors.textPrimary),
          ),
          if (onAccept != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: l10n.bookingAcceptNewPrice,
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

class _PrimaryActionForPhase extends ConsumerStatefulWidget {
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
          label: l10n.bookingAcceptNewPrice,
          onPressed: widget.onAcceptPrice,
        );
      case BookingPhase.readyToConfirm:
        if (_checkingOffer) {
          return _ProcessingButton(label: l10n.bookingValidating);
        }
        return AppButton(
          label: l10n.continueAction,
          trailingIcon: Icons.chevron_right_rounded,
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
      case BookingPhase.error:
        // The offer is not in a confirmable state — the Continue action is
        // replaced by a retry of the review revalidation.
        return AppButton(label: l10n.retry, onPressed: widget.onRevalidate);
      case BookingPhase.failed:
        return AppButton(label: l10n.retry, onPressed: widget.onConfirm);
    }
  }

  Future<void> _checkOfferAndContinue() async {
    if (_checkingOffer) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _checkingOffer = true);
    try {
      // Final provider-side revalidation right before the funnel
      // (spec point 8): the frozen quote must still be live.
      final selected = ref.read(selectedOfferProvider);
      final revalidationService = ref.read(offerRevalidationServiceProvider);
      final outcome = await revalidationService.revalidate(
        offerId: selected?.offerId ?? widget.state?.record?.offerId ?? '',
        providerId:
            selected?.providerId ?? widget.state?.record?.providerId ?? '',
        offerType:
            selected?.offerType ?? widget.state?.record?.type ?? 'flight',
        knownPrice:
            widget.state?.record?.authoritativePrice ?? selected?.price,
      );

      if (!mounted) return;
      switch (outcome.status) {
        case RevalidationStatus.ok:
          // Seed the funnel with the live authoritative price.
          ref.read(checkoutBasePriceProvider.notifier).state =
              outcome.price ??
              widget.state?.record?.authoritativePrice ??
              selected?.price ??
              0;
          ref.read(checkoutCurrencyProvider.notifier).state =
              outcome.currency ??
              widget.state?.record?.currency ??
              selected?.currency ??
              'USD';
          context.push('/booking/review/passengers');
        case RevalidationStatus.priceChanged:
          // Structured PRICE_CHANGED (spec point 8): block checkout until the
          // customer accepts the new amount.
          ref.read(bookingControllerProvider.notifier).revalidate(
                bookingId: widget.state?.record?.bookingId ?? '',
                oldPrice:
                    outcome.oldPrice ??
                    widget.state?.record?.authoritativePrice ??
                    selected?.price ??
                    0,
              );
        case RevalidationStatus.unavailable:
          // The offer is gone or expired — block the funnel. Retrying the
          // same offerId cannot help when the provider reports expiry.
          final String message = outcome.expired
              ? l10n.bookingOfferExpired
              : (outcome.reason?.isNotEmpty ?? false)
                  ? outcome.reason!
                  : l10n.bookingOfferUnavailable;
          if (outcome.expired) {
            ref
                .read(bookingControllerProvider.notifier)
                .markOfferExpired(message);
          } else {
            ref
                .read(bookingControllerProvider.notifier)
                .markOfferUnavailable(message);
          }
        case RevalidationStatus.error:
          // Revalidation failure blocks Continue: proceeding on an
          // unverified price would let a moved fare through silently.
          ref.read(bookingControllerProvider.notifier).markOfferCheckFailed(
                outcome.reason ?? l10n.bookingRevalidationFailed,
              );
      }
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
    return const SizedBox(
      height: 52,
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }
}
