import 'package:flutter/material.dart';
import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/core/domain/models/offers/display_price.dart';
import 'package:tokigo/core/domain/models/offers/flight_offer.dart';
import 'package:tokigo/core/theme/app_motion.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/ui/localized_date.dart';
import 'package:tokigo/core/widgets/cards/card.dart';
import 'package:tokigo/features/search/domain/flight_duration.dart';
import 'package:tokigo/features/search/presentation/widgets/flight_route_line.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Flight search result card — professional booking-result layout.
///
/// Hierarchy (top → bottom):
/// 1. Header row: airline logo + name/flight-number + favorite … PRICE
/// 2. Route strip: large departure → arrival times over airport codes
///    with duration/stops on the connecting line
/// 3. Secondary row: stops text / cabin / baggage chips / seats availability
/// 4. Warning badges (self-transfer, airport change, risky connection)
///
/// The whole card is tappable → it toggles the inline itinerary ([expanded]),
/// or collapses it again when it is already open. The expanded panel carries
/// the action that continues to Flight Details.
class FlightSearchCard extends StatelessWidget {
  const FlightSearchCard({
    super.key,
    this.offer,
    this.expanded = false,
    this.onToggleExpanded,
    this.onViewDetails,
    this.onFavorite,
    this.isFavorite = false,
    this.enabled = true,
    this.loading = false,
  });

  /// Skeleton constructor — renders the card's loading state with no data.
  const FlightSearchCard.loading({super.key})
    : offer = null,
      expanded = false,
      onToggleExpanded = null,
      onViewDetails = null,
      onFavorite = null,
      isFavorite = false,
      enabled = false,
      loading = true;

  /// The flight offer. Null only in the skeleton/loading state.
  final FlightOffer? offer;

  /// Whether the inline itinerary is revealed.
  final bool expanded;

  /// Toggles [expanded]. The page owns the flag, so only one card can be open
  /// at a time; null leaves the card display-only.
  final VoidCallback? onToggleExpanded;

  /// Continues to the existing offer-details route from the expanded panel.
  final VoidCallback? onViewDetails;

  /// Favorite toggle callback; null hides the favorite affordance.
  final ValueChanged<bool>? onFavorite;
  final bool isFavorite;
  final bool enabled;
  final bool loading;

  /// Non-null offer accessor — valid everywhere except the skeleton state,
  /// which never reads offer data.
  FlightOffer get data => offer!;

  String _formatFlightNumber() => _flightNumberText(data.flightNumber);

  /// Reveals [child] by animating its height; under reduce motion the panel
  /// swaps immediately instead. The effect is stripped, never slowed down.
  Widget _reveal(Widget child, {required bool reduceMotion}) {
    if (reduceMotion) return child;
    return AnimatedSize(
      duration: AppMotion.normal,
      curve: AppMotion.standard,
      alignment: Alignment.topCenter,
      clipBehavior: Clip.hardEdge,
      child: child,
    );
  }

  String _calculateDuration() =>
      flightDurationBetween(data.departureTime, data.arrivalTime);

  static String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';

  String _buildStopsText(AppLocalizations? l10n) {
    final stops = data.stops ?? 0;
    final stopAirport = data.metadata['stopAirport']?.toString();
    if (stops == 1 && stopAirport != null && stopAirport.isNotEmpty) {
      return l10n?.offerStopsWithAirport(stopAirport) ??
          '1 stop ($stopAirport)';
    }
    return l10n?.offerStopsCount(stops) ??
        (stops == 0 ? 'Non-stop' : '$stops stops');
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

    final l10n = AppLocalizations.of(context);
    return warningsList.whereType<String>().map((warning) {
      final lower = warning.toLowerCase();
      BadgeType? badgeType;
      IconData icon;
      String label;

      if (lower.contains('self.transfer') ||
          lower.contains('self transfer') ||
          lower.contains('self_transfer')) {
        badgeType = BadgeType.selfTransfer;
        icon = Icons.swap_horiz;
        label = l10n?.offerWarningSelfTransfer ?? 'Self-transfer';
      } else if (lower.contains('airport.change') ||
          lower.contains('airport change') ||
          lower.contains('airport_change')) {
        badgeType = BadgeType.airportChange;
        icon = Icons.flight_land;
        label = l10n?.offerWarningAirportChange ?? 'Airport change';
      } else if (lower.contains('tight') ||
          lower.contains('risky') ||
          lower.contains('connection')) {
        badgeType = BadgeType.riskyConnection;
        icon = Icons.warning_amber;
        label = l10n?.offerWarningRiskyConnection ?? 'Risky connection';
      } else if (lower.contains('overnight')) {
        badgeType = null;
        icon = Icons.nightlight_round;
        label = l10n?.offerWarningOvernight ?? 'Overnight';
      } else if (lower.contains('long.layover') ||
          lower.contains('long layover') ||
          lower.contains('long_layover')) {
        badgeType = null;
        icon = Icons.hourglass_top;
        label = l10n?.offerWarningLongLayover ?? 'Long layover';
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
    }).toList();
  }

  CardBadge? _buildRecommendationBadge(BuildContext context) {
    final rec = data.metadata['recommendation']?.toString().toLowerCase();
    if (rec == 'cheapest' ||
        rec == 'fastest' ||
        rec == 'best_value' ||
        rec == 'best value') {
      final l10n = AppLocalizations.of(context);
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
          label = l10n?.offerBadgeBestValue ?? 'Best value';
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
    final seatsStr =
        metadata['seats_left']?.toString() ??
        metadata['remainingSeats']?.toString();
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

    return {'perTraveler': parsePrice(perTraveler), 'total': parsePrice(total)};
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.tokigoColors;
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    // Reduce motion strips the reveal entirely (the same rule the cover-flow
    // carousel applies to its 3D transforms) rather than slowing it down.
    final bool reduceMotion = MediaQuery.reduceMotionOf(context);

    if (loading) {
      return BaseCard(
        onTap: null,
        enabled: false,
        loading: true,
        semanticsLabel: l10n?.offerLoadingFlight ?? 'Loading flight',
        margin: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: cardLoadingSemantics(const _LoadingSkeleton()),
      );
    }

    final duration = _calculateDuration();
    final stopsText = _buildStopsText(l10n);
    final features = _buildFeatures(context);
    final warnings = _buildWarnings(context);
    final priceInfo = _buildPriceInfo();
    final recommendationBadge = _buildRecommendationBadge(context);
    final seatsLeft = _getSeatsLeft();
    final hasPricePerTraveler =
        priceInfo['perTraveler'] != null && priceInfo['perTraveler']! > 0;
    final hasTotalPrice = priceInfo['total'] != null && priceInfo['total']! > 0;

    // Primary displayed price: per-traveler when present, else total, else base.
    final double primaryPrice = hasPricePerTraveler
        ? priceInfo['perTraveler']!
        : (hasTotalPrice ? priceInfo['total']! : data.price);

    // The card must state the SAME money the sort/filter compare: the backend
    // quote's customer currency when attached, never the raw provider amount
    // in a currency the traveller was not quoted.
    final DisplayMoney displayPrice = displayMoneyFor(
      primaryPrice,
      data.currency,
      data.customerPrice,
    );
    final DisplayMoney? displayTotal = hasTotalPrice && hasPricePerTraveler
        ? displayMoneyFor(
            priceInfo['total']!,
            data.currency,
            data.customerPrice,
          )
        : null;

    final semanticParts = <String>[
      l10n?.offerSemanticsFlightRoute(data.origin, data.destination) ??
          'Flight from ${data.origin} to ${data.destination}',
      data.airline,
      if (data.flightNumber.isNotEmpty)
        l10n?.offerSemanticsFlightNumber(_formatFlightNumber()) ??
            'Flight ${_formatFlightNumber()}',
      l10n?.offerSemanticsDeparts(_formatTime(data.departureTime)) ??
          'Departs at ${_formatTime(data.departureTime)}',
      l10n?.offerSemanticsArrives(_formatTime(data.arrivalTime)) ??
          'Arrives at ${_formatTime(data.arrivalTime)}',
      l10n?.offerSemanticsDuration(duration) ?? 'Duration $duration',
      if (stopsText.isNotEmpty) stopsText,
      if (features.isNotEmpty) features.join(', '),
      l10n?.offerSemanticsPrice(
            formatCardPrice(
              price: displayPrice.amount,
              currency: displayPrice.currency,
            ),
          ) ??
          'Price ${displayPrice.currency} ${displayPrice.amount.toStringAsFixed(0)}',
      if (displayTotal != null)
        l10n?.offerSemanticsTotal(
              formatCardPrice(
                price: displayTotal.amount,
                currency: displayTotal.currency,
              ),
            ) ??
            'Total ${displayTotal.currency} ${displayTotal.amount.toStringAsFixed(0)}',
      if (isFavorite) l10n?.offerSaved ?? 'Saved',
      if (seatsLeft != null && seatsLeft > 0)
        l10n?.offerSeatsLeft(seatsLeft.toInt()) ??
            'Only ${seatsLeft.toInt()} seats left',
      if (recommendationBadge != null) recommendationBadge.label!,
      if (warnings.isNotEmpty) warnings.map((w) => w.label).join(', '),
      // The card itself is the expand/collapse control, so its state is part
      // of what a screen reader announces.
      if (onToggleExpanded != null)
        expanded
            ? (l10n?.flightCardHideDetails ?? 'Hide details')
            : (l10n?.flightCardShowDetails ?? 'Flight details'),
    ];
    final semanticLabel = semanticParts.join(', ');

    return BaseCard(
      onTap: onToggleExpanded,
      enabled: enabled,
      semanticsLabel: semanticLabel,
      margin: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
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
                Builder(
                  builder: (context) {
                    final bg = CardImage.providerFor(
                      data.imageUrl,
                      cacheWidth: 128,
                      cacheHeight: 128,
                    );
                    return CircleAvatar(
                      radius: 20,
                      backgroundColor: scheme.primaryContainer,
                      backgroundImage: bg,
                      onBackgroundImageError: bg != null ? (_, _) {} : null,
                      child: bg == null
                          ? Icon(
                              Icons.flight,
                              size: 20,
                              color: scheme.onPrimaryContainer,
                            )
                          : null,
                    );
                  },
                ),
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
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
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
                        price: displayPrice.amount,
                        currency: displayPrice.currency,
                      ),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        // A price is content, not a call to action: it takes the
                        // primary text ink, never the CTA red.
                        color: tc.textPrimary,
                      ),
                    ),
                    if (displayTotal != null)
                      Text(
                        l10n?.offerCardTotal(
                              formatCardPrice(
                                price: displayTotal.amount,
                                currency: displayTotal.currency,
                              ),
                            ) ??
                            'total ${formatCardPrice(price: displayTotal.amount, currency: displayTotal.currency)}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                // Favorite
                if (onFavorite != null) ...[
                  const SizedBox(width: AppSpacing.xs),
                  CardFavorite(value: isFavorite, onChanged: onFavorite),
                ],
                // Expansion affordance. It turns with the state so the control
                // reads as "open" without a label competing with the price.
                if (onToggleExpanded != null) ...[
                  const SizedBox(width: AppSpacing.xxs),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: reduceMotion ? Duration.zero : AppMotion.normal,
                    curve: AppMotion.standard,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
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
                Icon(Icons.schedule, size: 14, color: scheme.onSurfaceVariant),
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
                label:
                    l10n?.offerSeatsLeft(seatsLeft.toInt()) ??
                    'Only ${seatsLeft.toInt()} seats left',
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
            // ── 5. Inline itinerary ────────────────────────────────────
            // Built ONLY while expanded, so a collapsed feed carries no
            // off-screen detail and the reveal can animate its height from
            // zero. The reveal clips as it grows, which is what keeps the
            // expansion from jumping the scroll position.
            if (onToggleExpanded != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              _reveal(
                expanded
                    ? _FlightExpandedDetails(
                        offer: data,
                        priceText: formatCardPrice(
                          price: displayPrice.amount,
                          currency: displayPrice.currency,
                        ),
                        totalText: displayTotal == null
                            ? null
                            : formatCardPrice(
                                price: displayTotal.amount,
                                currency: displayTotal.currency,
                              ),
                        onToggle: onToggleExpanded!,
                        onViewOffer: onViewDetails,
                      )
                    : const SizedBox(width: double.infinity),
                reduceMotion: reduceMotion,
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
    final tc = context.tokigoColors;
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
    final tc = context.tokigoColors;
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
                  // The rule mirrors the real route line: an explicit width, or
                  // the skeleton box collapses to 0 wide.
                  CardSkeleton.text(width: double.infinity, height: 2),
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

/// Readable form of the provider's marketing flight number.
///
/// The number already carries the carrier code ("EK 123", "DE2017"); it is
/// NEVER derived from the airline's display name — "Emirates" is not the
/// carrier code "EM". A number that already has a space, or a bare numeric
/// number ("985"), is shown verbatim; a glued alphanumeric prefix only gains a
/// readable space ("DE2017" → "DE 2017").
String _flightNumberText(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return value;
  final match = RegExp(
    r'^([A-Za-z]{2}|[A-Za-z]\d|\d[A-Za-z])(\d+)$',
  ).firstMatch(value);
  if (match == null) return value;
  return '${match.group(1)!.toUpperCase()} ${match.group(2)}';
}

/// The itinerary revealed inline by tapping a result card.
///
/// Every row is guarded by the presence of the provider's own value, so a
/// fact the provider omitted simply has no row — the panel can never state an
/// empty or invented field. The collapsed card's route strip is not repeated
/// here; this panel adds the full dates, the connection detail and the fare
/// facts, then hands off to the existing offer-details route.
class _FlightExpandedDetails extends StatelessWidget {
  const _FlightExpandedDetails({
    required this.offer,
    required this.priceText,
    required this.totalText,
    required this.onToggle,
    required this.onViewOffer,
  });

  final FlightOffer offer;

  /// Already-formatted primary amount ("EGP 5000"); formatting stays with the
  /// card so the expanded panel and the collapsed header agree.
  final String priceText;

  /// Already-formatted stay total, when the provider quoted one.
  final String? totalText;

  /// Collapses the card again.
  final VoidCallback onToggle;

  /// Continues to the existing offer-details route.
  final VoidCallback? onViewOffer;

  @override
  Widget build(BuildContext context) {
    final tc = context.tokigoColors;
    final typography = AppTypography.forLight();
    final l10n = AppLocalizations.of(context)!;

    final DateTime departure = offer.departureTime;
    final DateTime arrival = offer.arrivalTime;
    final bool nextDay = !_sameDay(departure, arrival);
    final int stops = offer.stops ?? 0;
    final String? layover = offer.metadata['layoverDuration']?.toString();
    final String? aircraft = offer.metadata['aircraft']?.toString();
    final String? fareFamily = offer.metadata['fareFamily']?.toString();
    final bool refundable = offer.metadata['refundable'] == true;
    final String? baggage = _baggageValue(offer.metadata['baggage']);
    final String? cabin = (offer.cabinClass ?? '').isEmpty
        ? null
        : offer.cabinClass;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        // Match the other detail cards: surface fill, 1px outline, 18 radius.
        color: tc.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: tc.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            l10n.flightCardShowDetails,
            style: typography.captionSemibold.copyWith(color: tc.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (offer.airline.isNotEmpty)
            _FactRow(label: l10n.offerAirline, value: offer.airline),
          if (offer.flightNumber.isNotEmpty)
            _FactRow(
              label: l10n.offerFlightNumber,
              value: _flightNumberText(offer.flightNumber),
            ),
          _FactRow(
            label: l10n.offerDeparture,
            value: _dateTime(context, departure, offer.origin),
          ),
          _FactRow(
            label: l10n.offerArrival,
            value:
                '${_dateTime(context, arrival, offer.destination)}'
                '${nextDay ? ' (+1)' : ''}',
          ),
          _FactRow(
            label: l10n.offerDuration,
            value: flightDurationBetween(departure, arrival),
          ),
          _FactRow(label: l10n.offerStops, value: l10n.offerStopsCount(stops)),
          if (layover != null && layover.isNotEmpty)
            _FactRow(label: l10n.offerLayoverLabel, value: layover),
          if (cabin != null)
            _FactRow(label: l10n.offerCabin, value: cabin),
          if (baggage != null)
            _FactRow(label: l10n.offerBaggage, value: baggage),
          if (aircraft != null && aircraft.isNotEmpty)
            _FactRow(label: l10n.offerAircraft, value: aircraft),
          if (fareFamily != null && fareFamily.isNotEmpty)
            _FactRow(label: l10n.offerFare, value: fareFamily),
          if (refundable)
            _FactRow(
              label: l10n.offerRefundable,
              value: l10n.offerRefundableYes,
            ),
          const SizedBox(height: AppSpacing.xs),
          Divider(height: 1, thickness: 1, color: tc.hairline),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: Text(
                  l10n.offerPrice,
                  style: typography.caption.copyWith(color: tc.textTertiary),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    priceText,
                    style: typography.titleMedium.copyWith(
                      color: tc.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (totalText != null)
                    Text(
                      l10n.offerCardTotal(totalText!),
                      style: typography.caption.copyWith(
                        color: tc.textTertiary,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.offerPriceNote,
            style: typography.caption.copyWith(color: tc.textTertiary),
          ),
          const SizedBox(height: AppSpacing.md),
          // A wrap, not a row: the two actions keep their full labels and move
          // to a second line on a narrow phone instead of overflowing.
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              CardPrimaryAction(
                label: l10n.flightCardViewOffer,
                onPressed: onViewOffer,
                icon: Icons.open_in_new_rounded,
                expanded: false,
              ),
              TextButton(
                onPressed: onToggle,
                style: TextButton.styleFrom(
                  foregroundColor: tc.brand,
                  minimumSize: const Size(48, 44),
                ),
                child: Text(l10n.flightCardHideDetails),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// "1 Dec 2026, 10:00 · CAI" — the full date the collapsed route strip
  /// compresses to a bare time. A missing airport code is dropped, not
  /// replaced with a dash.
  static String _dateTime(
    BuildContext context,
    DateTime date,
    String airport,
  ) {
    final String day = localizedMediumDate(context, date);
    final String time =
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
    return airport.isEmpty ? '$day, $time' : '$day, $time · $airport';
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Provider baggage, verbatim: `{quantity, type}` → `1 × checked`. Null
  /// when the provider sent nothing usable.
  static String? _baggageValue(dynamic baggage) {
    if (baggage is Map) {
      final quantity = baggage['quantity'];
      final type = baggage['type']?.toString();
      if (quantity != null && type != null && type.isNotEmpty) {
        return '$quantity × $type';
      }
      if (quantity != null) return '$quantity';
      return null;
    }
    final text = baggage?.toString() ?? '';
    return text.isEmpty ? null : text;
  }
}

/// One label / value line of the expanded itinerary.
class _FactRow extends StatelessWidget {
  const _FactRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tc = context.tokigoColors;
    final typography = AppTypography.forLight();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: typography.caption.copyWith(color: tc.textTertiary),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 3,
            child: Text(
              value,
              // Same fact-row recipe as OfferDetailsSummaryCard: the value is
              // the louder body step, the label the quiet caption.
              style: typography.bodyMedium.copyWith(
                color: tc.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
