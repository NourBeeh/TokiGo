import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tokigo/core/domain/models/offers/flight_offer.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/widgets/cards/card.dart';
import 'package:tokigo/core/widgets/cards/badge_config.dart';
import 'package:tokigo/features/search/presentation/widgets/flight_route_line.dart';

/// Flight search result card — professional booking-result layout.
///
/// Hierarchy (top → bottom):
/// 1. Header row: airline logo + name/flight-number + favorite … PRICE
/// 2. Route strip: large departure → arrival times over airport codes
///    with duration/stops on the connecting line
/// 3. Secondary row: stops text / cabin / baggage chips / seats availability
/// 4. Warning badges (self-transfer, airport change, risky connection)
///
/// The whole card is tappable → Flight Details (/booking/review).
class FlightSearchCard extends StatelessWidget {
  const FlightSearchCard({
    super.key,
    this.offer,
    this.onTap,
    this.onFavorite,
    this.isFavorite = false,
    this.enabled = true,
    this.loading = false,
  });

  /// Skeleton constructor — renders the card's loading state with no data.
  const FlightSearchCard.loading({super.key})
      : offer = null,
        onTap = null,
        onFavorite = null,
        isFavorite = false,
        enabled = false,
        loading = true;

  /// The flight offer. Null only in the skeleton/loading state.
  final FlightOffer? offer;
  final VoidCallback? onTap;

  /// Favorite toggle callback; null hides the favorite affordance.
  final ValueChanged<bool>? onFavorite;
  final bool isFavorite;
  final bool enabled;
  final bool loading;

  /// Non-null offer accessor — valid everywhere except the skeleton state,
  /// which never reads offer data.
  FlightOffer get data => offer!;

  String _formatFlightNumber() {
    if (data.airline.isNotEmpty && data.flightNumber.isNotEmpty) {
      final code = data.airline.length >= 2
          ? data.airline.substring(0, 2).toUpperCase()
          : data.airline.toUpperCase();
      return '$code ${data.flightNumber}';
    }
    return data.flightNumber;
  }

  String _calculateDuration() {
    final diff = data.arrivalTime.difference(data.departureTime);
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    if (hours > 0 && minutes > 0) {
      return '${hours}h ${minutes}m';
    } else if (hours > 0) {
      return '${hours}h';
    } else {
      return '${minutes}m';
    }
  }

  String _buildStopsText() {
    final stops = data.stops ?? 0;
    final stopAirport = data.metadata['stopAirport']?.toString();
    if (stops == 0) {
      return 'Non-stop';
    } else if (stops == 1) {
      return stopAirport != null && stopAirport.isNotEmpty
          ? '1 stop ($stopAirport)'
          : '1 stop';
    } else {
      return '$stops stops';
    }
  }

  List<String> _buildFeatures(BuildContext context) {
    final features = <String>[];
    if (data.cabinClass != null && data.cabinClass!.isNotEmpty) {
      features.add(data.cabinClass!);
    }
    final baggage = data.metadata['baggage']?.toString();
    if (baggage != null && baggage.isNotEmpty) {
      features.add(baggage);
    }
    return features;
  }

  List<CardBadge> _buildWarnings(BuildContext context) {
    final warningsList = data.metadata['warnings'] as List?;
    if (warningsList == null || warningsList.isEmpty) return [];

    return warningsList
        .whereType<String>()
        .map((warning) {
          final lower = warning.toLowerCase();
          BadgeType? badgeType;
          IconData icon;
          String label;

          if (lower.contains('self.transfer') ||
              lower.contains('self transfer') ||
              lower.contains('self_transfer')) {
            badgeType = BadgeType.selfTransfer;
            icon = Icons.swap_horiz;
            label = 'Self-transfer';
          } else if (lower.contains('airport.change') ||
              lower.contains('airport change') ||
              lower.contains('airport_change')) {
            badgeType = BadgeType.airportChange;
            icon = Icons.flight_land;
            label = 'Airport change';
          } else if (lower.contains('tight') ||
              lower.contains('risky') ||
              lower.contains('connection')) {
            badgeType = BadgeType.riskyConnection;
            icon = Icons.warning_amber;
            label = 'Risky connection';
          } else if (lower.contains('overnight')) {
            badgeType = null;
            icon = Icons.nightlight_round;
            label = 'Overnight';
          } else if (lower.contains('long.layover') ||
              lower.contains('long layover') ||
              lower.contains('long_layover')) {
            badgeType = null;
            icon = Icons.hourglass_top;
            label = 'Long layover';
          } else {
            badgeType = null;
            icon = Icons.warning_amber;
            label = warning;
          }

          return CardBadge(
            label: label,
            icon: icon,
            variant: CardBadgeVariant.tinted,
            type: badgeType,
          );
        })
        .toList();
  }

  CardBadge? _buildRecommendationBadge(BuildContext context) {
    final rec = data.metadata['recommendation']?.toString().toLowerCase();
    if (rec == 'cheapest' || rec == 'fastest' || rec == 'best_value' || rec == 'best value') {
      String label;
      IconData icon;
      BadgeType? badgeType;

      switch (rec) {
        case 'cheapest':
          label = 'Cheapest';
          icon = Icons.attach_money;
          badgeType = BadgeType.cheapest;
          break;
        case 'fastest':
          label = 'Fastest';
          icon = Icons.speed;
          badgeType = BadgeType.fastest;
          break;
        case 'best_value':
        case 'best value':
          label = 'Best Value';
          icon = Icons.star;
          badgeType = BadgeType.best;
          break;
        default:
          label = rec ?? '';
          icon = Icons.star;
          badgeType = null;
      }

      return CardBadge(
        label: label,
        icon: icon,
        variant: CardBadgeVariant.tinted,
        type: badgeType,
      );
    }
    return null;
  }

  double? _getSeatsLeft() {
    final metadata = data.metadata;
    final seats = metadata['seatsLeft'];
    if (seats is int) return seats.toDouble();
    if (seats is num) return seats.toDouble();
    final seatsStr = metadata['seats_left']?.toString() ?? metadata['remainingSeats']?.toString();
    if (seatsStr != null) {
      return double.tryParse(seatsStr);
    }
    return null;
  }

  Map<String, double?> _buildPriceInfo() {
    final metadata = data.metadata;
    final perTraveler = metadata['pricePerTraveler'];
    final total = metadata['totalPrice'];

    double? parsePrice(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    return {
      'perTraveler': parsePrice(perTraveler),
      'total': parsePrice(total),
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (loading) {
      return BaseCard(
        onTap: null,
        enabled: false,
        loading: true,
        semanticsLabel: 'Loading flight',
        margin: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: cardLoadingSemantics(const _LoadingSkeleton()),
      );
    }

    final duration = _calculateDuration();
    final stopsText = _buildStopsText();
    final features = _buildFeatures(context);
    final warnings = _buildWarnings(context);
    final priceInfo = _buildPriceInfo();
    final recommendationBadge = _buildRecommendationBadge(context);
    final seatsLeft = _getSeatsLeft();
    final hasPricePerTraveler = priceInfo['perTraveler'] != null && priceInfo['perTraveler']! > 0;
    final hasTotalPrice = priceInfo['total'] != null && priceInfo['total']! > 0;

    // Primary displayed price: per-traveler when present, else total, else base.
    final double primaryPrice = hasPricePerTraveler
        ? priceInfo['perTraveler']!
        : (hasTotalPrice ? priceInfo['total']! : data.price);

    final semanticParts = <String>[
      'Flight from ${data.origin} to ${data.destination}',
      data.airline,
      if (data.flightNumber.isNotEmpty) 'Flight ${_formatFlightNumber()}',
      'Departs at ${DateFormat.Hm().format(data.departureTime)}',
      'Arrives at ${DateFormat.Hm().format(data.arrivalTime)}',
      'Duration $duration',
      if (stopsText.isNotEmpty) stopsText,
      if (features.isNotEmpty) features.join(', '),
      'Price ${data.currency} ${primaryPrice.toStringAsFixed(0)}',
      if (hasTotalPrice && hasPricePerTraveler)
        'Total ${data.currency} ${priceInfo['total']!.toStringAsFixed(0)}',
      if (isFavorite) 'Saved',
      if (seatsLeft != null && seatsLeft > 0) 'Only ${seatsLeft.toInt()} seats left',
      if (recommendationBadge != null) recommendationBadge.label!,
      if (warnings.isNotEmpty) warnings.map((w) => w.label).join(', '),
    ];
    final semanticLabel = semanticParts.join(', ');

    return BaseCard(
      onTap: onTap,
      enabled: enabled,
      semanticsLabel: semanticLabel,
      margin: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── 1. Header: airline + favorite + PRICE ──────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Airline logo
                Builder(builder: (context) {
                  final bg = CardImage.providerFor(data.imageUrl);
                  return CircleAvatar(
                    radius: 20,
                    backgroundColor: scheme.primaryContainer,
                    backgroundImage: bg,
                    onBackgroundImageError: bg != null ? (_, __) {} : null,
                    child: bg == null
                        ? Icon(Icons.flight, size: 20, color: scheme.onPrimaryContainer)
                        : null,
                  );
                }),
                const SizedBox(width: AppSpacing.sm),
                // Airline name + flight number
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        data.airline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      Text(
                        _formatFlightNumber(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                // Recommendation badge (compact, next to price)
                if (recommendationBadge != null) ...[
                  recommendationBadge,
                  const SizedBox(width: AppSpacing.sm),
                ],
                // Price — visually prominent
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatCardPrice(
                        price: primaryPrice,
                        currency: data.currency,
                      ),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: scheme.primary,
                          ),
                    ),
                    if (hasTotalPrice && hasPricePerTraveler)
                      Text(
                        'total ${formatCardPrice(
                          price: priceInfo['total'],
                          currency: data.currency,
                        )}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                  ],
                ),
                // Favorite
                if (onFavorite != null) ...[
                  const SizedBox(width: AppSpacing.xs),
                  CardFavorite(
                    value: isFavorite,
                    onChanged: onFavorite,
                  ),
                ],
              ],
            ),
            // ── 2. Route strip — the visual anchor ─────────────────────
            const SizedBox(height: AppSpacing.lg),
            FlightRouteLine(
              departureTime: data.departureTime,
              arrivalTime: data.arrivalTime,
              origin: data.origin,
              destination: data.destination,
              stops: data.stops ?? 0,
              stopAirport: data.metadata['stopAirport']?.toString(),
              layoverDuration: data.metadata['layoverDuration']?.toString(),
              duration: duration,
            ),
            // ── 3. Secondary metadata row ─────────────────────────────
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 14,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    stopsText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                if (features.isNotEmpty) ...[
                  const SizedBox(width: AppSpacing.sm),
                  const _DotSeparator(),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: CardFeatureList(
                      features: features,
                      direction: Axis.horizontal,
                    ),
                  ),
                ],
              ],
            ),
            // ── 4. Availability + warnings ─────────────────────────────
            if (seatsLeft != null && seatsLeft > 0 && seatsLeft <= 9) ...[
              const SizedBox(height: AppSpacing.sm),
              CardAvailability(
                status: CardAvailabilityStatus.limited,
                label: 'Only ${seatsLeft.toInt()} seat${seatsLeft > 1 ? 's' : ''} left',
              ),
            ],
            if (warnings.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: warnings,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Small centered dot separating metadata items.
class _DotSeparator extends StatelessWidget {
  const _DotSeparator();

  @override
  Widget build(BuildContext context) {
    return Text(
      '·',
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
    );
  }
}

/// Skeleton for [FlightSearchCard] — mirrors the real card's geometry
/// (header row, route strip, metadata row, warnings) with no fake data.
class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header: avatar + airline + price
        Row(
          children: [
            CardSkeleton.avatar(size: 40),
            CardSkeleton.hGap(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CardSkeleton.title(width: 130, height: 16),
                  CardSkeleton.gap(height: AppSpacing.xxs),
                  CardSkeleton.text(width: 76),
                ],
              ),
            ),
            CardSkeleton.hGap(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                CardSkeleton.price(width: 96, height: 22),
                CardSkeleton.gap(height: AppSpacing.xxs),
                CardSkeleton.text(width: 64),
              ],
            ),
          ],
        ),
        CardSkeleton.gap(height: AppSpacing.lg),
        // Route strip: dep time | line+duration | arr time
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CardSkeleton.title(width: 64, height: 20),
                  CardSkeleton.gap(height: AppSpacing.xxs),
                  CardSkeleton.text(width: 44),
                ],
              ),
            ),
            CardSkeleton.hGap(width: AppSpacing.sm),
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  CardSkeleton.text(height: 2),
                  SizedBox(height: AppSpacing.xxs),
                  CardSkeleton.chip(width: 56, height: 16),
                ],
              ),
            ),
            CardSkeleton.hGap(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  CardSkeleton.title(width: 64, height: 20),
                  CardSkeleton.gap(height: AppSpacing.xxs),
                  CardSkeleton.text(width: 44),
                ],
              ),
            ),
          ],
        ),
        CardSkeleton.gap(height: AppSpacing.md),
        // Metadata row
        Row(
          children: [
            CardSkeleton.text(width: 80),
            CardSkeleton.hGap(width: AppSpacing.sm),
            CardSkeleton.chip(width: 64),
            CardSkeleton.hGap(width: AppSpacing.xs),
            CardSkeleton.chip(width: 72),
          ],
        ),
      ],
    );
  }
}
