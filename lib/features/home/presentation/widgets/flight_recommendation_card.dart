import 'package:flutter/material.dart';
import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/widgets/cards/card.dart';
import 'package:tokigo/core/widgets/cards/badge_config.dart';
import 'package:tokigo/features/home/presentation/home_card_dimensions.dart';
import 'package:tokigo/features/search/presentation/widgets/flight_route_line.dart';

/// Flight recommendation card — Home discovery product card.
///
/// This is NOT a search-result card: it is a compact, image-light
/// recommendation tile (~280×240 via [HomeCardDimensions]) surfacing one
/// recommended flight from [HomeItem] metadata:
///
/// - header: airline logo + name + recommendation badge
/// - route strip: prominent departure/arrival times over airport codes
/// - metadata: cabin/baggage chips
/// - price anchored bottom-end
///
/// Navigation is owned by the parent via [onTap]/[onFavorite].
class FlightRecommendationCard extends StatelessWidget {
  const FlightRecommendationCard({
    super.key,
    required this.item,
    this.onTap,
    this.onFavorite,
    this.loading = false,
  });

  final HomeItem item;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onFavorite;

  /// Skeleton state — renders the same tile geometry with no data.
  final bool loading;

  DateTime? _parseTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  String _calculateDuration(DateTime? dep, DateTime? arr) {
    if (dep == null || arr == null) return '';
    final diff = arr.difference(dep);
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    if (hours > 0 && minutes > 0) return '${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h';
    return '${minutes}m';
  }

  String _buildStopsText(dynamic stops, String? stopAirport) {
    final s = stops is int ? stops : int.tryParse(stops?.toString() ?? '0') ?? 0;
    if (s == 0) return 'Non-stop';
    if (s == 1) {
      return stopAirport != null && stopAirport.isNotEmpty
          ? '1 stop ($stopAirport)'
          : '1 stop';
    }
    return '$s stops';
  }

  CardBadge? _buildRecommendationBadge(String? recommendation) {
    final rec = recommendation?.toString().toLowerCase();
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final targetWidth =
        HomeCardDimensions.cardWidthForType(HomeCardType.flight);
    final targetHeight =
        HomeCardDimensions.cardHeightForType(HomeCardType.flight);

    if (loading) {
      return BaseCard(
        onTap: null,
        enabled: false,
        loading: true,
        semanticsLabel: 'Loading recommended flight',
        padding: EdgeInsets.all(AppSpacing.md),
        child: cardLoadingSemantics(_LoadingSkeleton(width: targetWidth)),
      );
    }

    final depTime = _parseTime(item.metadata['departureTime']);
    final arrTime = _parseTime(item.metadata['arrivalTime']);
    final origin = item.metadata['origin']?.toString() ?? '';
    final destination = item.metadata['destination']?.toString() ?? '';
    final stops = item.metadata['stops'];
    final stopAirport = item.metadata['stopAirport']?.toString();
    final cabin = item.metadata['cabinClass']?.toString();
    final baggage = item.metadata['baggage']?.toString();
    final airline = item.metadata['airline']?.toString() ?? item.title;
    final flightNumber = item.metadata['flightNumber']?.toString();
    final duration = _calculateDuration(depTime, arrTime);
    final stopsText = _buildStopsText(stops, stopAirport);
    final recommendation = item.metadata['recommendation']?.toString();
    final recommendationBadge = _buildRecommendationBadge(recommendation);
    final seatsLeft = item.metadata['seatsLeft'];
    final seats =
        seatsLeft is int ? seatsLeft : int.tryParse(seatsLeft?.toString() ?? '');
    final isFavorite = item.metadata['isWishlisted'] == true;

    final semanticParts = <String>[
      'Recommended flight',
      if (recommendation != null) recommendation,
      airline,
      if (flightNumber != null && flightNumber.isNotEmpty) 'Flight $flightNumber',
      '$origin to $destination',
      if (depTime != null) 'Departs at ${depTime.hour.toString().padLeft(2, '0')}:${depTime.minute.toString().padLeft(2, '0')}',
      if (arrTime != null) 'Arrives at ${arrTime.hour.toString().padLeft(2, '0')}:${arrTime.minute.toString().padLeft(2, '0')}',
      if (duration.isNotEmpty) 'Duration $duration',
      if (stopsText.isNotEmpty) stopsText,
      if (cabin != null && cabin.isNotEmpty) cabin,
      if (baggage != null && baggage.isNotEmpty) baggage,
      if (item.price != null) 'Price ${item.price!.toStringAsFixed(0)} ${item.currency ?? ''}',
      if (isFavorite) 'Saved',
    ];
    final semanticLabel = semanticParts.join(', ');

    return BaseCard(
      onTap: onTap,
      semanticsLabel: semanticLabel,
      padding: EdgeInsets.all(AppSpacing.md),
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: targetWidth, minHeight: targetHeight),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header: airline + badge + favorite ────────────────────
            Row(
              children: [
                Builder(builder: (context) {
                  final bg = CardImage.providerFor(item.imageUrl);
                  return CircleAvatar(
                    radius: 16,
                    backgroundColor: scheme.primaryContainer,
                    backgroundImage: bg,
                    onBackgroundImageError: bg != null ? (_, __) {} : null,
                    child: bg == null
                        ? Icon(Icons.flight, size: 16, color: scheme.onPrimaryContainer)
                        : null,
                  );
                }),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    airline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                if (recommendationBadge != null) ...[
                  Flexible(child: recommendationBadge),
                  const SizedBox(width: AppSpacing.xs),
                ],
                if (onFavorite != null)
                  CardFavorite(
                    value: isFavorite,
                    onChanged: onFavorite,
                  ),
              ],
            ),
            // ── Route strip — the visual anchor ───────────────────────
            const SizedBox(height: AppSpacing.md),
            Center(
              child: FlightRouteLine(
                departureTime:
                    depTime ?? DateTime.fromMillisecondsSinceEpoch(0),
                arrivalTime:
                    arrTime ?? DateTime.fromMillisecondsSinceEpoch(0),
                origin: origin.isNotEmpty ? origin : '—',
                destination: destination.isNotEmpty ? destination : '—',
                stops: stops is int ? stops : 0,
                stopAirport: stopAirport,
                duration: duration,
                compact: true,
              ),
            ),
            // ── Metadata row: stops + cabin/baggage chips ──────────────
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
              ],
            ),
            if ((cabin != null && cabin.isNotEmpty) ||
                (baggage != null && baggage.isNotEmpty)) ...[
              const SizedBox(height: AppSpacing.xs),
              CardFeatureList(
                features: [
                  if (cabin != null && cabin.isNotEmpty) cabin,
                  if (baggage != null && baggage.isNotEmpty) baggage,
                ],
                direction: Axis.horizontal,
              ),
            ],
            // ── Footer: seats-left badge + PRICE ──────────────────────
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (seats != null && seats > 0 && seats <= 9) ...[
                  Flexible(
                    child: CardBadge(
                      label: '$seats seat${seats > 1 ? 's' : ''} left',
                      icon: Icons.event_seat,
                      variant: CardBadgeVariant.tinted,
                      type: BadgeType.limitedRooms,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                const Spacer(),
                Flexible(
                  child: CardPrice(
                    price: item.price,
                    currency: item.currency,
                    rawPrice: item.rawPrice,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for [FlightRecommendationCard] — same tile geometry
/// (header, route strip, metadata, price) with no fake data.
class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: avatar + airline + badge
          Row(
            children: [
              CardSkeleton.avatar(size: 32),
              CardSkeleton.hGap(width: AppSpacing.sm),
              Expanded(child: CardSkeleton.title(width: 120, height: 16)),
              CardSkeleton.chip(width: 72),
            ],
          ),
          CardSkeleton.gap(height: AppSpacing.md),
          // Route strip
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CardSkeleton.title(width: 56, height: 18),
                    CardSkeleton.gap(height: AppSpacing.xxs),
                    CardSkeleton.text(width: 40),
                  ],
                ),
              ),
              CardSkeleton.hGap(width: AppSpacing.sm),
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CardSkeleton.text(height: 2),
                    const SizedBox(height: AppSpacing.xxs),
                    CardSkeleton.chip(width: 52, height: 16),
                  ],
                ),
              ),
              CardSkeleton.hGap(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CardSkeleton.title(width: 56, height: 18),
                    CardSkeleton.gap(height: AppSpacing.xxs),
                    CardSkeleton.text(width: 40),
                  ],
                ),
              ),
            ],
          ),
          CardSkeleton.gap(height: AppSpacing.md),
          // Metadata row
          Row(
            children: [
              CardSkeleton.text(width: 76),
              CardSkeleton.hGap(width: AppSpacing.xs),
              CardSkeleton.chip(width: 60),
            ],
          ),
          CardSkeleton.gap(height: AppSpacing.sm),
          // Footer price
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              CardSkeleton.price(width: 80),
            ],
          ),
        ],
      ),
    );
  }
}
