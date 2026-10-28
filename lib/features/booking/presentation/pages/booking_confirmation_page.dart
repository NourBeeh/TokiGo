import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/domain/models/booking/booking.dart';
import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/ui/app_button.dart';
import 'package:tokigo/core/ui/app_message_state.dart';
import 'package:tokigo/core/ui/localized_date.dart';
import 'package:tokigo/core/widgets/ai_entrance_animation.dart';
import 'package:tokigo/core/widgets/cards/card_image.dart';
import 'package:tokigo/core/widgets/page_header.dart';
import 'package:tokigo/features/booking/application/booking_providers.dart';
import 'package:tokigo/features/booking/application/providers/checkout_flow_providers.dart';
import 'package:tokigo/features/booking/domain/booking_record.dart';
import 'package:tokigo/features/home/providers/home_providers.dart'
    show eventsTrackerProvider;
import 'package:tokigo/features/search/application/providers/offer_selection_provider.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Final step of the booking funnel — confirmation.
///
/// **OWNER DECISION (2026-10-19): real bookings only.** v1 invented the whole
/// screen: a random `WT-######` reference, a three-day trip built out of
/// `DateTime.now()`, and a hardcoded "Booking confirmed" regardless of what the
/// backend said. It now renders the booking the provider actually confirmed —
/// its reference, its status, its travellers and its price — and says so
/// honestly when no confirmed booking exists. The Bag sync happens in
/// [BookingController.confirm] against the same real record.
class BookingConfirmationPage extends ConsumerStatefulWidget {
  const BookingConfirmationPage({super.key, this.record});

  /// Render seam (mirrors [BookingReviewPage.state]): when supplied, this
  /// record is rendered instead of the booking controller's. The app never
  /// passes it — it always shows the real confirmed booking from the backend.
  final BookingRecord? record;

  @override
  ConsumerState<BookingConfirmationPage> createState() =>
      _BookingConfirmationPageState();
}

class _BookingConfirmationPageState
    extends ConsumerState<BookingConfirmationPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _checkController;

  @override
  void initState() {
    super.initState();
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    // Phase 1C — behavioural signal (fire-and-forget, guests skipped).
    // Only fired for a REAL confirmed booking with a REAL destination: the
    // derived profile must never be fed a placeholder.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final record = ref.read(bookingControllerProvider).record;
      if (record == null || record.status != BookingStatus.confirmed) return;
      final destination = _realDestination();
      if (destination == null) return;
      ref
          .read(eventsTrackerProvider)
          .bookingConfirmed(destination: destination);
    });
  }

  /// The destination the search context really carried — or nothing.
  String? _realDestination() {
    final metadata = ref.read(selectedOfferProvider)?.metadata;
    if (metadata == null) return null;
    for (final key in const <String>['destination', 'city', 'to']) {
      final value = metadata[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  @override
  void dispose() {
    _checkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final l10n = AppLocalizations.of(context)!;
    final record = widget.record ?? ref.watch(bookingControllerProvider).record;
    final confirmed =
        record != null && record.status == BookingStatus.confirmed;

    // Nothing was confirmed → never claim otherwise.
    if (!confirmed) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: AiEntranceAnimation(
            child: Column(
              children: <Widget>[
                AppPageHeader(backFallbackLocation: '/booking/review'),
                Expanded(
                  child: SingleChildScrollView(
                    child: AppMessageState(
                      icon: Icons.receipt_long_outlined,
                      title: l10n.confirmationNoneTitle,
                      body: l10n.confirmationNoneBody,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.lg + MediaQuery.of(context).padding.bottom,
                  ),
                  child: AppButton(
                    label: l10n.bookingBackHome,
                    type: AppButtonType.ghost,
                    onPressed: () => context.go('/'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final travelers = ref.watch(checkoutTravelersProvider);
    final selectedOffer = ref.watch(selectedOfferProvider);
    final addOnsTotal = ref
        .watch(checkoutAddOnsProvider)
        .fold<double>(0, (s, a) => s + a.total);
    // Real provider price + real add-ons, in the provider's currency.
    final total = record.authoritativePrice + addOnsTotal;
    final currency = record.currency.isEmpty ? 'USD' : record.currency;
    final reference = record.bookingReference;
    final travelersCount = record.travelers.isNotEmpty
        ? record.travelers.length
        : travelers.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: AiEntranceAnimation(
          child: Column(
            children: <Widget>[
              // The success mark in the body is this page's heading, so the
              // header carries the control row alone — same geometry, same back
              // contract, no duplicated title.
              AppPageHeader(backFallbackLocation: '/booking/review'),
              Expanded(
                // Scrollable: the recap card is real content of variable height
                // (a long hotel name, a photo, two dates), and a large text scale
                // must not clip it. Short content centres in the free space
                // instead of hugging the header with a void beneath it.
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg,
                            AppSpacing.lg,
                            AppSpacing.lg,
                            AppSpacing.lg,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              // Stroke-drawn checkmark.
                              AnimatedBuilder(
                                animation: _checkController,
                                builder: (context, _) {
                                  return Container(
                                    width: 96,
                                    height: 96,
                                    decoration: const BoxDecoration(
                                      color: AppColors.successContainer,
                                      shape: BoxShape.circle,
                                    ),
                                    child: CustomPaint(
                                      painter: _CheckPainter(
                                        _checkController.value,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              Text(
                                l10n.bookingConfirmedTitle,
                                textAlign: TextAlign.center,
                                style: typography.headline.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              // The reference promises "a confirmation email has
                              // been sent". We send none — so the line says what
                              // this screen really is: the reference the provider
                              // confirmed, kept for the customer.
                              Text(
                                l10n.confirmationSubtitle,
                                textAlign: TextAlign.center,
                                style: typography.body.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              _BookingRecapCard(
                                offer: selectedOffer,
                                type: selectedOffer?.offerType ?? record.type,
                                reference: reference,
                                travelersCount: travelersCount,
                                total: total,
                                currency: currency,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.lg + MediaQuery.of(context).padding.bottom,
                ),
                child: Column(
                  children: <Widget>[
                    AppButton(
                      label: l10n.bookingViewTrip,
                      leadingIcon: Icons.luggage_rounded,
                      onPressed: () => context.go('/bag'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppButton(
                      label: l10n.bookingBackHome,
                      type: AppButtonType.ghost,
                      onPressed: () => context.go('/'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.success
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    // First half draws the short stroke, second half the long one. The mark is
    // sized to read inside the 96 disc (the reference's check fills its circle;
    // the old 34px stroke read as a speck).
    final shortStart = center + const Offset(-21, 3);
    final shortEnd = center + const Offset(-4, 19);
    final longEnd = center + const Offset(23, -18);

    if (progress <= 0.5) {
      final t = progress / 0.5;
      canvas.drawLine(shortStart, Offset.lerp(shortStart, shortEnd, t)!, paint);
    } else {
      canvas.drawLine(shortStart, shortEnd, paint);
      final t = (progress - 0.5) / 0.5;
      canvas.drawLine(shortEnd, Offset.lerp(shortEnd, longEnd, t)!, paint);
    }
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// The reference's confirmation card: what was booked, when, for whom, for how
/// much, and the provider's own reference.
///
/// **Honesty rules:** every block comes from real data — the offer the funnel
/// booked ([offer], only when the funnel really carried one), the confirmed
/// record's traveller count, price and reference. No offer ⇒ no invented title,
/// photo or dates: the card simply states fewer facts.
class _BookingRecapCard extends StatelessWidget {
  const _BookingRecapCard({
    required this.offer,
    required this.type,
    required this.reference,
    required this.travelersCount,
    required this.total,
    required this.currency,
  });

  final SelectedOffer? offer;
  final String type;
  final String reference;
  final int travelersCount;
  final double total;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final l10n = AppLocalizations.of(context)!;
    final title = offer?.title?.trim();
    final subtitle = offer?.subtitle?.trim();
    final startsAt = offer?.startsAt;
    final endsAt = offer?.endsAt;
    final (startLabel, endLabel) = _dateLabels(l10n, type);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (title != null && title.isNotEmpty) ...<Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: CardImage(
                      url: offer?.imageUrl,
                      fallbackIcon: _typeIcon(type),
                      semanticLabel: title,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: typography.bodyLargeMedium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (subtitle != null && subtitle.isNotEmpty) ...<Widget>[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
            const SizedBox(height: AppSpacing.md),
          ],
          // The offer's own dates, labelled by vertical — never a range we
          // computed for a vertical that has no such pair.
          if (startLabel != null && startsAt != null)
            _Row(
              label: startLabel,
              value: localizedMediumDate(context, startsAt),
              typography: typography,
            ),
          if (endLabel != null && endsAt != null)
            _Row(
              label: endLabel,
              value: localizedMediumDate(context, endsAt),
              typography: typography,
            ),
            // Sandbox simulated booking (4B/4E — no real Stripe/PSP yet)
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Sandbox simulated booking — no real charge',
              style: typography.caption.copyWith(
                color: AppColors.info,
              ),
            ),
          // Simplified sandbox passenger info (4D — simplified passenger data)
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Passenger: Test Guest (ADT) — simplified sandbox data',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          _Row(
            label: l10n.bookingTravellersLabel,
            value: '$travelersCount',
            typography: typography,
          ),
          _Row(
            // "Total paid" would be a lie on pay-at-hotel bookings, where the
            // amount is settled at the property.
            label: l10n.total,
            value: '$currency ${total.toStringAsFixed(2)}',
            typography: typography,
          ),
          if (reference.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1, thickness: 1, color: AppColors.outline),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        l10n.bookingReferenceLabel,
                        style: typography.caption.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      // A provider reference is an LTR token: isolate it so a
                      // leading "#" cannot jump to the other end in Arabic.
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          reference,
                          style: typography.bodyLargeMedium.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                _CopyReferenceButton(reference: reference),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Date labels per vertical. A package has no such pair, so it gets none.
  (String?, String?) _dateLabels(AppLocalizations l10n, String type) {
    return switch (type) {
      'hotel' => (l10n.offerCheckIn, l10n.offerCheckOut),
      'car' => (l10n.offerPickup, l10n.offerDropOff),
      'flight' => (l10n.confirmationDeparture, l10n.confirmationArrival),
      _ => (null, null),
    };
  }

  IconData _typeIcon(String type) {
    return switch (type) {
      'hotel' => Icons.hotel_rounded,
      'car' => Icons.directions_car_rounded,
      'package' => Icons.card_travel_rounded,
      _ => Icons.flight_takeoff_rounded,
    };
  }
}

/// Copies the REAL booking reference to the clipboard.
///
/// The reference screen shows a copy control here, and unlike a heart or a
/// share sheet this one has a real effect: the string written is exactly the
/// provider's reference the card displays. The icon confirms for two seconds.
class _CopyReferenceButton extends StatefulWidget {
  const _CopyReferenceButton({required this.reference});

  final String reference;

  @override
  State<_CopyReferenceButton> createState() => _CopyReferenceButtonState();
}

class _CopyReferenceButtonState extends State<_CopyReferenceButton> {
  Timer? _reset;
  bool _copied = false;

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.reference));
    if (!mounted) return;
    setState(() => _copied = true);
    _reset?.cancel();
    _reset = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final label = _copied
        ? l10n.confirmationCopied
        : l10n.confirmationCopyReference;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: InkWell(
          onTap: _copy,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondary,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.outline),
            ),
            child: Icon(
              _copied ? Icons.check_rounded : Icons.copy_rounded,
              size: 18,
              color: _copied ? AppColors.success : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    required this.typography,
  });

  final String label;
  final String value;
  final AppTypography typography;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: typography.body.copyWith(color: AppColors.textSecondary),
            ),
          ),
          Text(
            value,
            style: typography.bodyMedium.copyWith(color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
