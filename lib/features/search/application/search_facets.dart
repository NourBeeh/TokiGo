import 'dart:math' as math;

import 'package:tokigo/core/domain/models/offers/base_offer.dart';
import 'package:tokigo/core/domain/models/offers/car_offer.dart';
import 'package:tokigo/core/domain/models/offers/flight_offer.dart';
import 'package:tokigo/core/domain/models/offers/hotel_offer.dart';
import 'package:tokigo/features/search/application/search_results_processing.dart';

/// Phase 3C follow-up — the filter options a result list can honestly offer.
///
/// A filter may only narrow by values that the provider actually returned:
/// the price span of the current list, the airlines flying it, the facilities
/// the stays report, the transmission values the cars report. Inventing an
/// option list ("Emirates", "Spa") would let the customer filter by something
/// no result has — and would show a chip that can only empty the screen.

/// The real price span of a result list, in the single currency it is priced
/// in. `null` when there is nothing to span, when prices are missing, or when
/// the list mixes currencies (amounts would not be comparable).
class PriceFacet {
  const PriceFacet({
    required this.min,
    required this.max,
    required this.currency,
  });

  /// Slider floor — the cheapest offered amount, rounded down.
  final double min;

  /// Slider ceiling — the dearest offered amount, rounded up.
  final double max;

  /// The currency every amount in the span is priced in.
  final String currency;

  /// A single-price list has nothing to narrow.
  bool get isUsable => max > min;
}

/// The span every offer can be compared in — the same amount the filters and
/// the sorts use, so the slider can never exclude an offer it appears to include.
PriceFacet? priceFacetOf(Iterable<BaseOffer> offers) {
  final currencies = <String>{};
  var low = double.infinity;
  var high = double.negativeInfinity;

  for (final offer in offers) {
    final amount = effectiveSortAmount(offer);
    // An unpriced offer is not "free" — it simply has no amount to compare.
    if (amount <= 0) continue;
    final currency = (offer.customerPrice?.customerCurrency ?? offer.currency)
        .trim();
    // A missing currency cannot be labelled honestly.
    if (currency.isEmpty) return null;
    currencies.add(currency);
    low = math.min(low, amount);
    high = math.max(high, amount);
  }

  if (currencies.length != 1 || low == double.infinity) return null;
  final min = low.floorToDouble();
  final max = high.ceilToDouble();
  final facet = PriceFacet(min: min, max: max, currency: currencies.single);
  return facet.isUsable ? facet : null;
}

/// Airlines that appear in the current flight results, deduplicated and
/// alphabetical. Empty values (a provider that sent no carrier) are not an
/// option.
List<String> airlinesOf(Iterable<FlightOffer> offers) {
  final values = <String>{};
  for (final offer in offers) {
    final airline = offer.airline.trim();
    if (airline.isNotEmpty) values.add(airline);
  }
  return values.toList()..sort();
}

/// Facilities the current stays report, deduplicated and alphabetical.
List<String> amenitiesOf(Iterable<HotelOffer> offers) {
  final values = <String>{};
  for (final offer in offers) {
    for (final amenity in offer.amenities) {
      final value = amenity.trim();
      if (value.isNotEmpty) values.add(value);
    }
  }
  return values.toList()..sort();
}

/// Transmission values the current car results report, deduplicated.
///
/// The raw provider values are kept verbatim: this is data, not vocabulary.
List<String> transmissionsOf(Iterable<CarOffer> offers) {
  final values = <String>{};
  for (final offer in offers) {
    final value = (offer.transmission ?? '').trim();
    if (value.isNotEmpty) values.add(value);
  }
  return values.toList()..sort();
}
