import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/network/user_facing_message.dart';
import 'package:tokigo/core/ui/app_button.dart';
import 'package:tokigo/core/ui/app_message_state.dart';
import 'package:tokigo/core/ui/localized_date.dart';
import 'package:tokigo/core/widgets/ai_entrance_animation.dart';
import 'package:tokigo/core/widgets/cards/card_image.dart';
import 'package:tokigo/core/widgets/page_header.dart';
import 'package:tokigo/core/widgets/step_progress.dart' show StatusChip;
import 'package:tokigo/features/bag/application/bag_controller.dart';
import 'package:tokigo/features/booking/application/booking_providers.dart';
import 'package:tokigo/features/bag/domain/trip.dart';
import 'package:tokigo/features/bag/presentation/trip_labels.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Trip details — the deep-dive surface of one trip in the Bag.
///
/// **Honesty rules:** every row is a fact the confirmed booking carries — the
/// booked item, its own dates, the traveller count, the provider's total, the
/// supplier and the provider's reference. The page used to render a placeholder
/// ("Trip trip-bk_1", status "confirmed", provider "TokiGo"); a trip that is not
/// in the Bag now says so instead of describing a trip it cannot see.
class TripDetailsPage extends ConsumerWidget {
  const TripDetailsPage({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bag = ref.watch(bagControllerProvider);
    final l10n = AppLocalizations.of(context)!;
    final all = <TripSummary>[...bag.currentTrips, ...bag.pastTrips];
    final matches = all.where((trip) => trip.tripId == tripId);
    final trip = matches.isEmpty ? null : matches.first;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: AiEntranceAnimation(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AppPageHeader(
                title: l10n.tripDetails,
                backFallbackLocation: '/bag',
              ),
              Expanded(
                child: trip == null
                    ? SingleChildScrollView(
                        child: AppMessageState(
                          icon: Icons.luggage_outlined,
                          title: l10n.tripNotFoundTitle,
                          body: l10n.tripNotFoundBody,
                          actionLabel: l10n.myTrips,
                          onAction: () => context.go('/bag'),
                        ),
                      )
                    : _TripBody(trip: trip),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TripBody extends StatelessWidget {
  const _TripBody({required this.trip});

  final TripSummary trip;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final typography = AppTypography.forLight();
    final typeLabel = tripTypeLabel(l10n, trip.type);
    final place = trip.destination.trim();
    final title = trip.title?.trim();
    final hasTitle = title != null && title.isNotEmpty;
    // With no name and no place, the vertical label above is the identity —
    // the card does not repeat "Hotel" as its own headline.
    final headline = hasTitle ? title : (place.isNotEmpty ? place : null);
    final showPlace = hasTitle && place.isNotEmpty;
    final (startLabel, endLabel) = tripDateLabels(l10n, trip.type);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xxxl,
      ),
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.outline),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: CardImage(
                    url: trip.imageUrl,
                    fallbackIcon: tripTypeIcon(trip.type),
                    semanticLabel: headline ?? typeLabel,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(
                          tripTypeIcon(trip.type),
                          size: 13,
                          color: AppColors.brand,
                        ),
                        const SizedBox(width: AppSpacing.xxs),
                        Flexible(
                          child: Text(
                            typeLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: typography.captionSemibold.copyWith(
                              color: AppColors.brand,
                            ),
                          ),
                        ),
                        const Spacer(),
                        StatusChip(
                          label: tripStatusLabel(l10n, trip.status),
                          color: tripStatusColor(trip.status),
                        ),
                      ],
                    ),
                    if (headline != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        headline,
                        style: typography.bodyLargeMedium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                    if (showPlace) ...<Widget>[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        place,
                        style: typography.caption.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.outline),
          ),
          child: Column(
            children: <Widget>[
              // The trip's own dates, labelled for its vertical.
              if (startLabel != null && trip.startDate != null)
                _FactRow(
                  label: startLabel,
                  value: localizedMediumDate(context, trip.startDate!),
                ),
              if (endLabel != null && trip.endDate != null)
                _FactRow(
                  label: endLabel,
                  value: localizedMediumDate(context, trip.endDate!),
                ),
              if (trip.travelersCount != null)
                _FactRow(
                  label: l10n.bookingTravellersLabel,
                  value: '${trip.travelersCount}',
                ),
              _FactRow(
                label: l10n.total,
                value: '${trip.currency} ${trip.total.toStringAsFixed(2)}',
              ),
              if (trip.providerName.trim().isNotEmpty)
                _FactRow(label: l10n.offerProvider, value: trip.providerName),
              if (trip.bookingReference.trim().isNotEmpty)
                _FactRow(
                  label: l10n.bookingReferenceLabel,
                  // A provider reference is an LTR token: isolate it so it
                  // cannot swap ends inside an Arabic paragraph.
                  value: trip.bookingReference,
                  ltrValue: true,
                ),
            ],
          ),
        ),
        if (_canCancel(trip)) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          _CancelBookingAction(trip: trip),
        ],
      ],
    );
  }
}

/// Whether the trip still offers a cancellation.
///
/// The app does not guess the provider's rules: it offers the action while
/// the booking is live, and the **backend** decides — if the provider refuses,
/// its own words are shown.
bool _canCancel(TripSummary trip) {
  final String status = trip.status.toLowerCase();
  return status == 'confirmed' || status == 'pending' || status == 'prepared';
}

/// The "Cancel booking" action — a `danger` ghost button (doc 22 §1.4).
class _CancelBookingAction extends ConsumerStatefulWidget {
  const _CancelBookingAction({required this.trip});

  final TripSummary trip;

  @override
  ConsumerState<_CancelBookingAction> createState() =>
      _CancelBookingActionState();
}

class _CancelBookingActionState extends ConsumerState<_CancelBookingAction> {
  bool _working = false;

  Future<void> _cancel() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l10n.tripCancelTitle),
        content: Text(l10n.tripCancelBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.tripCancelKeep),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              l10n.tripCancelConfirm,
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _working = true);
    final result = await ref
        .read(bookingRepositoryProvider)
        .cancelBooking(widget.trip.bookingId);
    if (!mounted) return;
    setState(() => _working = false);

    result.when(
      success: (_) {
        ref
            .read(bagControllerProvider.notifier)
            .markCancelled(widget.trip.tripId);
        messenger
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(l10n.tripCancelled)));
      },
      failure: (Object error) {
        // The provider's own words, never a made-up excuse.
        messenger
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(userFacingMessage(error, subject: 'booking')),
            ),
          );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppButton(
      label: l10n.tripCancelBooking,
      type: AppButtonType.ghost,
      leadingIcon: Icons.close_rounded,
      onPressed: _working ? null : _cancel,
      expanded: false,
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({
    required this.label,
    required this.value,
    this.ltrValue = false,
  });

  final String label;
  final String value;

  /// Wraps the value in an LTR run (provider tokens, references).
  final bool ltrValue;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final text = Text(
      value,
      textAlign: TextAlign.end,
      style: typography.bodyMedium.copyWith(color: AppColors.textPrimary),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: typography.caption.copyWith(color: AppColors.textTertiary),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: ltrValue
                ? Directionality(textDirection: TextDirection.ltr, child: text)
                : text,
          ),
        ],
      ),
    );
  }
}
