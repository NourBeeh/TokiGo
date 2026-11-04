import 'package:flutter/material.dart';

import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/core/widgets/cards/card.dart';
import 'package:tokigo/features/home/presentation/home_card_dimensions.dart';
import 'package:tokigo/features/search/presentation/widgets/flight_route_line.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Flight recommendation card — Home discovery product card.
///
/// This is NOT a search-result card: it is a compact comparison tile
/// (~300×252 via [HomeCardDimensions]) surfacing one recommended flight:
///
/// - header: airline mark, name and flight number, recommendation badge
/// - route line: the visual anchor, without a nested panel
/// - metadata: one line of stops · cabin · baggage
/// - footer: limited-seat signal on the start, price at the end
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

  String _buildStopsText(
    dynamic stops,
    String? stopAirport,
    AppLocalizations? l10n,
  ) {
    final s = stops is int
        ? stops
        : int.tryParse(stops?.toString() ?? '0') ?? 0;
    if (s == 1 && stopAirport != null && stopAirport.isNotEmpty) {
      return l10n?.offerStopsWithAirport(stopAirport) ??
          '1 stop ($stopAirport)';
    }
    return l10n?.offerStopsCount(s) ??
        (s == 0
            ? 'Non-stop'
            : s == 1
            ? '1 stop'
            : '$s stops');
  }

  CardBadge? _buildRecommendationBadge(
    String? recommendation,
    AppLocalizations? l10n,
  ) {
    final rec = recommendation?.toString().toLowerCase();
    if (rec == 'cheapest' ||
        rec == 'fastest' ||
        rec == 'best_value' ||
        rec == 'best value') {
      String label;
      IconData icon;
      BadgeType? badgeType;

      switch (rec) {
        case 'cheapest':
          label = l10n?.offerBadgeCheapest ?? 'Cheapest';
          icon = Icons.attach_money;
          badgeType = BadgeType.cheapest;
          break;
        case 'fastest':
          label = l10n?.offerBadgeFastest ?? 'Fastest';
          icon = Icons.speed;
          badgeType = BadgeType.fastest;
          break;
        case 'best_value':
        case 'best value':
          label = l10n?.offerBadgeBestValue ?? 'Best Value';
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
    final targetWidth = HomeCardDimensions.cardWidthForType(
      HomeCardType.flight,
    );
    final targetHeight = HomeCardDimensions.cardHeightForType(
      HomeCardType.flight,
    );
    final AppLocalizations? l10n = AppLocalizations.of(context);

    if (loading) {
      return BaseCard(
        onTap: null,
        enabled: false,
        loading: true,
        showBorder: true,
        borderColor: TravelCardStyle.borderColor(context),
        showShadow: false,
        semanticsLabel: l10n?.offerLoadingFlight ?? 'Loading flight',
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: cardLoadingSemantics(
          _LoadingSkeleton(width: targetWidth, height: targetHeight),
        ),
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
    final stopsText = _buildStopsText(stops, stopAirport, l10n);
    final recommendation = item.metadata['recommendation']?.toString();
    final recommendationBadge = _buildRecommendationBadge(recommendation, l10n);
    final recommendationLabel = switch (recommendation?.toLowerCase()) {
      'cheapest' => l10n?.offerBadgeCheapest,
      'fastest' => l10n?.offerBadgeFastest,
      'best_value' || 'best value' => l10n?.offerBadgeBestValue,
      _ => null,
    };
    final seatsLeft = item.metadata['seatsLeft'];
    final seats = seatsLeft is int
        ? seatsLeft
        : int.tryParse(seatsLeft?.toString() ?? '');
    final isFavorite = item.metadata['isWishlisted'] == true;

    final semanticParts = <String>[
      ?recommendationLabel,
      airline,
      if (flightNumber != null && flightNumber.isNotEmpty)
        l10n?.offerSemanticsFlightNumber(flightNumber) ??
            'Flight $flightNumber',
      l10n?.offerSemanticsFlightRoute(origin, destination) ??
          '$origin to $destination',
      if (depTime != null)
        l10n?.offerSemanticsDeparts(
              '${depTime.hour.toString().padLeft(2, '0')}:${depTime.minute.toString().padLeft(2, '0')}',
            ) ??
            'Departs at ${depTime.hour.toString().padLeft(2, '0')}:${depTime.minute.toString().padLeft(2, '0')}',
      if (arrTime != null)
        l10n?.offerSemanticsArrives(
              '${arrTime.hour.toString().padLeft(2, '0')}:${arrTime.minute.toString().padLeft(2, '0')}',
            ) ??
            'Arrives at ${arrTime.hour.toString().padLeft(2, '0')}:${arrTime.minute.toString().padLeft(2, '0')}',
      if (duration.isNotEmpty)
        l10n?.offerSemanticsDuration(duration) ?? 'Duration $duration',
      if (stopsText.isNotEmpty) stopsText,
      if (cabin != null && cabin.isNotEmpty) cabin,
      if (baggage != null && baggage.isNotEmpty) baggage,
      if (item.price != null)
        l10n?.offerSemanticsPrice(
              '${item.price!.toStringAsFixed(0)} ${item.currency ?? ''}'.trim(),
            ) ??
            'Price ${item.price!.toStringAsFixed(0)} ${item.currency ?? ''}',
      if (isFavorite) l10n?.offerSaved ?? 'Saved',
    ];

    final metadataParts = <String>[
      stopsText,
      if (cabin != null && cabin.isNotEmpty) cabin,
      if (baggage != null && baggage.isNotEmpty) baggage,
    ];

    return BaseCard(
      onTap: onTap,
      semanticsLabel: semanticParts.join(', '),
      showBorder: true,
      borderColor: TravelCardStyle.borderColor(context),
      showShadow: false,
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: targetWidth,
          minHeight: targetHeight,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // ── Header: airline mark + identity + recommendation ─────────
              Row(
                children: <Widget>[
                  _AirlineMark(url: item.imageUrl),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          airline,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.forLight().bodyLargeMedium
                              .copyWith(
                                color: context.tokigoColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        if (flightNumber != null &&
                            flightNumber.isNotEmpty) ...<Widget>[
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            flightNumber,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.forLight().caption.copyWith(
                              color: context.tokigoColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (recommendationBadge != null) ...<Widget>[
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(child: recommendationBadge),
                  ],
                  if (onFavorite != null) ...<Widget>[
                    const SizedBox(width: AppSpacing.xxs),
                    CardFavorite(value: isFavorite, onChanged: onFavorite),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              // ── Route strip — the visual anchor ─────────────────────────
              FlightRouteLine(
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
              const SizedBox(height: AppSpacing.sm),
              // ── One calm metadata line ──────────────────────────────────
              _MetadataLine(parts: metadataParts),
              const SizedBox(height: AppSpacing.sm),
              Divider(
                height: 1,
                thickness: 1,
                color: context.tokigoColors.hairline,
              ),
              const SizedBox(height: AppSpacing.sm),
              // ── Footer: scarcity on the start, price at the end ─────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  if (seats != null && seats > 0 && seats <= 9)
                    Flexible(
                      child: CardBadge(
                        label:
                            l10n?.offerSeatsLeft(seats) ??
                            '$seats seat${seats > 1 ? 's' : ''} left',
                        icon: Icons.event_seat_outlined,
                        variant: CardBadgeVariant.tinted,
                        type: BadgeType.limitedRooms,
                      ),
                    )
                  else
                    const Spacer(),
                  const SizedBox(width: AppSpacing.sm),
                  _FlightPrice(price: item.price, currency: item.currency),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The airline identity mark: the provider's logo when it sent one, otherwise
/// a quiet flight glyph. It is a rounded tile, not a coloured avatar, so it
/// belongs to the monochrome card family.
class _AirlineMark extends StatelessWidget {
  const _AirlineMark({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final ImageProvider? bg = CardImage.providerFor(
      url,
      cacheWidth: 128,
      cacheHeight: 128,
    );
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: context.tokigoColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: context.tokigoColors.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: bg == null
          ? Icon(
              Icons.flight_takeoff_rounded,
              size: 18,
              color: context.tokigoColors.textSecondary,
            )
          : Image(
              image: bg,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Icon(
                Icons.flight_takeoff_rounded,
                size: 18,
                color: context.tokigoColors.textSecondary,
              ),
            ),
    );
  }
}

class _MetadataLine extends StatelessWidget {
  const _MetadataLine({required this.parts});

  final List<String> parts;

  @override
  Widget build(BuildContext context) {
    if (parts.isEmpty) return const SizedBox.shrink();
    final typography = AppTypography.forLight();
    return Row(
      children: <Widget>[
        Icon(
          Icons.schedule_rounded,
          size: 14,
          color: context.tokigoColors.textTertiary,
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            parts.join('  ·  '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: typography.caption.copyWith(
              color: context.tokigoColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _FlightPrice extends StatelessWidget {
  const _FlightPrice({required this.price, required this.currency});

  final double? price;
  final String? currency;

  @override
  Widget build(BuildContext context) {
    final value = price;
    if (value == null) return const SizedBox.shrink();
    final typography = AppTypography.forLight();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          value.toStringAsFixed(0),
          maxLines: 1,
          style: typography.titleMedium.copyWith(
            color: context.tokigoColors.textPrimary,
            fontWeight: FontWeight.w800,
            height: 1.05,
            letterSpacing: -0.3,
          ),
        ),
        if ((currency ?? '').isNotEmpty) ...<Widget>[
          const SizedBox(width: AppSpacing.xs),
          Text(
            currency!,
            maxLines: 1,
            style: typography.caption.copyWith(
              color: context.tokigoColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

/// Skeleton for [FlightRecommendationCard] — the header, route, metadata
/// line and price footer with no fake data.
class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                CardSkeleton.avatar(size: 38),
                CardSkeleton.hGap(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      CardSkeleton.title(width: 120, height: 16),
                      CardSkeleton.gap(height: AppSpacing.xxs),
                      CardSkeleton.text(width: 64, height: 12),
                    ],
                  ),
                ),
                CardSkeleton.chip(width: 72),
              ],
            ),
            CardSkeleton.gap(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
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
                    children: <Widget>[
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
                    children: <Widget>[
                      CardSkeleton.title(width: 56, height: 18),
                      CardSkeleton.gap(height: AppSpacing.xxs),
                      CardSkeleton.text(width: 40),
                    ],
                  ),
                ),
              ],
            ),
            CardSkeleton.gap(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                CardSkeleton.text(width: 76),
                CardSkeleton.hGap(width: AppSpacing.xs),
                CardSkeleton.chip(width: 60),
              ],
            ),
            CardSkeleton.gap(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[CardSkeleton.price(width: 88)],
            ),
          ],
        ),
      ),
    );
  }
}
