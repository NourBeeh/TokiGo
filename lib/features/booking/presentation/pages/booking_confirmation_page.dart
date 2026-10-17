import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:wetravellers/core/theme/app_colors.dart';
import 'package:wetravellers/core/theme/app_radius.dart';
import 'package:wetravellers/core/theme/app_spacing.dart';
import 'package:wetravellers/core/theme/app_typography.dart';
import 'package:wetravellers/core/ui/app_button.dart';
import 'package:wetravellers/features/booking/application/providers/checkout_flow_providers.dart';
import 'package:wetravellers/features/home/providers/home_providers.dart'
    show eventsTrackerProvider;
import 'package:wetravellers/features/bag/application/bag_controller.dart';
import 'package:wetravellers/features/bag/domain/trip.dart';
import 'package:wetravellers/l10n/app_localizations.dart';

/// Final step of the booking funnel — confirmation.
///
/// A stroke-drawn checkmark success animation, booking reference, trip
/// summary and the two exit CTAs (view trip / back home). The booking is
/// also synced into the Bag controller so "My Trips" reflects it.
class BookingConfirmationPage extends ConsumerStatefulWidget {
  const BookingConfirmationPage({super.key});

  @override
  ConsumerState<BookingConfirmationPage> createState() =>
      _BookingConfirmationPageState();
}

class _BookingConfirmationPageState extends ConsumerState<BookingConfirmationPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _checkController;

  static final math.Random _random = math.Random(7842);
  late final String _reference;

  @override
  void initState() {
    super.initState();
    _reference = 'WT-${_random.nextInt(900000) + 100000}';
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    // Sync the confirmed booking into the unified Bag.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(bagControllerProvider.notifier).addCurrent(
            TripSummary(
              tripId: 'trip-$_reference',
              bookingId: _reference,
              type: 'booking',
              destination: 'See details',
              startDate: DateTime.now(),
              endDate:
                  DateTime.now().add(const Duration(days: 3)),
              status: 'confirmed',
              total: ref.read(checkoutBasePriceProvider),
              currency: 'USD',
              bookingReference: _reference,
              providerName: 'TokiGo',
            ),
          );
      // Phase 1C — behavioral signal (fire-and-forget, guests skipped).
      // The destination is the checkout context when known; the backend
      // folds `upcomingDestination` into the derived profile.
      ref.read(eventsTrackerProvider).bookingConfirmed(
            destination: 'See details',
          );
    });
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
    final travelers = ref.watch(checkoutTravelersProvider);
    final total = ref.watch(checkoutBasePriceProvider) +
        ref
            .watch(checkoutAddOnsProvider)
            .fold<double>(0, (s, a) => s + a.total);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Row(
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => context.canPop() ? context.pop() : context.go('/booking/review'),
                    tooltip: 'Back',
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // Stroke-drawn checkmark.
                    AnimatedBuilder(
                      animation: _checkController,
                      builder: (context, _) {
                        return Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: AppColors.successContainer,
                            shape: BoxShape.circle,
                          ),
                          child: CustomPaint(
                            painter: _CheckPainter(_checkController.value),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'Booking confirmed',
                      style: typography.headline.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Reference $_reference',
                      style: typography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _SummaryCard(
                      travelersCount: travelers.length,
                      total: total,
                    ),
                  ],
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
              child: Column(
                children: <Widget>[
                  AppButton(
                    label: 'View my trip',
                    leadingIcon: Icons.luggage_rounded,
                    onPressed: () => context.go('/bag'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'Back to ${l10n.navHome.toLowerCase()}',
                    type: AppButtonType.ghost,
                    onPressed: () => context.go('/'),
                  ),
                ],
              ),
            ),
          ],
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
    // First half draws the short stroke, second half the long one.
    final shortStart = center + const Offset(-16, 2);
    final shortEnd = center + const Offset(-3, 15);
    final longEnd = center + const Offset(18, -14);

    if (progress <= 0.5) {
      final t = progress / 0.5;
      canvas.drawLine(
        shortStart,
        Offset.lerp(shortStart, shortEnd, t)!,
        paint,
      );
    } else {
      canvas.drawLine(shortStart, shortEnd, paint);
      final t = (progress - 0.5) / 0.5;
      canvas.drawLine(
        shortEnd,
        Offset.lerp(shortEnd, longEnd, t)!,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.travelersCount,
    required this.total,
  });

  final int travelersCount;
  final double total;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        children: <Widget>[
          _Row(
            label: 'Travellers',
            value: '$travelersCount',
            typography: typography,
          ),
          _Row(
            label: 'Status',
            value: 'Confirmed',
            typography: typography,
          ),
          _Row(
            label: 'Total paid',
            value: '\$${total.toStringAsFixed(2)}',
            typography: typography,
          ),
        ],
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
            style: typography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
