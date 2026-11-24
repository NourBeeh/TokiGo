import 'package:flutter/material.dart';

import 'package:tokigo/core/domain/models/offers/flight_offer.dart';
import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/ui/localized_date.dart';
import 'package:tokigo/features/search/domain/flight_duration.dart';
import 'package:tokigo/features/search/presentation/widgets/flight_fare_facts.dart';
import 'package:tokigo/features/search/presentation/widgets/flight_route_line.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// The flight's route block: the date line, the route line, the stops + real
/// duration, and one chip per fact the provider actually sent.
///
/// A missing cabin is not "Economy" and a missing fare family is not "Standard"
/// — a fact the provider omitted simply has no chip.
class OfferDetailsFlightJourney extends StatelessWidget {
  const OfferDetailsFlightJourney({super.key, required this.flight});

  final FlightOffer flight;

  @override
  Widget build(BuildContext context) {
    final tc = context.tokigoColors;
    final typography = AppTypography.forLight();
    final l10n = AppLocalizations.of(context)!;
    final departure = flight.departureTime;
    final arrival = flight.arrivalTime;
    final duration = flightDurationBetween(departure, arrival);
    final stops = flight.stops ?? 0;
    final cabin = flight.cabinClass;
    final baggage = flightBaggageSummary(l10n, flight);
    final aircraft = flight.metadata['aircraft']?.toString();
    final fareBrand = flight.fareBrand;
    final refundable = flight.refundable;
    final codeshares = <String>{};
    for (final segment in flight.segments) {
      if (!segment.isCodeshare) continue;
      final name =
          segment.operatingCarrierName ?? segment.operatingCarrierCode ?? '';
      final designator = segment.operatingDesignator;
      if (name.isEmpty) continue;
      codeshares.add(designator.isEmpty ? name : '$name ($designator)');
    }

    final sameDay =
        departure.year == arrival.year &&
        departure.month == arrival.month &&
        departure.day == arrival.day;
    final dateLine = sameDay
        ? localizedMediumDate(context, departure)
        : '${localizedMediumDate(context, departure)} → '
              '${localizedMediumDate(context, arrival)}';

    // Only the facts the provider actually sent become chips.
    final chips = <Widget>[
      if (baggage != null)
        _FactChip(
          icon: Icons.luggage_rounded,
          label: l10n.offerBaggage,
          value: baggage,
        ),
      if (cabin != null && cabin.isNotEmpty)
        _FactChip(
          icon: Icons.event_seat_rounded,
          label: l10n.offerCabin,
          value: cabin,
        ),
      if (aircraft != null && aircraft.isNotEmpty)
        _FactChip(
          icon: Icons.flight_rounded,
          label: l10n.offerAircraft,
          value: aircraft,
        ),
      if (fareBrand != null && fareBrand.isNotEmpty)
        _FactChip(
          icon: Icons.sell_rounded,
          label: l10n.offerFare,
          value: fareBrand,
        ),
      // Tri-state: a known "no" is stated; an unknown condition has no chip.
      if (refundable != null)
        _FactChip(
          icon: Icons.task_alt_rounded,
          label: l10n.offerRefundable,
          value: refundable
              ? l10n.offerRefundableYes
              : l10n.offerNonRefundable,
        ),
    ];

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
            dateLine,
            style: typography.caption.copyWith(color: context.tokigoColors.textTertiary),
          ),
          const SizedBox(height: AppSpacing.md),
          FlightRouteLine(
            departureTime: departure,
            arrivalTime: arrival,
            origin: flight.origin,
            destination: flight.destination,
            stops: stops,
            stopAirport: flight.metadata['stopAirport']?.toString(),
            layoverDuration: flight.metadata['layoverDuration']?.toString(),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Icon(
                Icons.schedule_rounded,
                size: 14,
                color: context.tokigoColors.textTertiary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  '${l10n.offerStopsCount(stops)} · $duration',
                  style: typography.captionSemibold.copyWith(
                    color: context.tokigoColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (codeshares.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.offerOperatedBy(codeshares.join(', ')),
              style: typography.caption.copyWith(
                color: context.tokigoColors.textTertiary,
              ),
            ),
          ],
          if (chips.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: chips,
            ),
          ],
        ],
      ),
    );
  }
}

/// One provider fact as a bordered chip (reference: Baggage / Seats / Aircraft).
class _FactChip extends StatelessWidget {
  const _FactChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tc = context.tokigoColors;
    final typography = AppTypography.forLight();
    return Container(
      // The CardBadge chip recipe: pill radius, 8/4 padding.
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: context.tokigoColors.surface,
        borderRadius: AppRadius.pillBorder,
        border: Border.all(color: context.tokigoColors.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: context.tokigoColors.brand),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label,
                style: typography.caption.copyWith(
                  color: context.tokigoColors.textTertiary,
                ),
              ),
              Text(
                value,
                // Chip values are provider tokens ("1 × checked", "Economy").
                // Inside an Arabic paragraph bidi would reorder the mixed run
                // ("checked × 1"), so the value is isolated as LTR — a single
                // Arabic word still renders correctly under an LTR paragraph.
                textDirection: TextDirection.ltr,
                style: typography.captionSemibold.copyWith(
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
