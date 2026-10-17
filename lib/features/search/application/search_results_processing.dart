library;

import 'package:tokigo/core/domain/models/offers/base_offer.dart';
import 'package:tokigo/core/domain/models/offers/car_offer.dart';
import 'package:tokigo/core/domain/models/offers/flight_offer.dart';
import 'package:tokigo/core/domain/models/offers/hotel_offer.dart';
import 'package:tokigo/features/search/domain/search_filters.dart';
import 'package:tokigo/features/search/domain/sort_option.dart';

/// Phase 3C — unified, deterministic results processing for all verticals.
///
/// Sorting and filtering are CLIENT-SIDE over the provider-returned list:
/// they reorder/limit what the backend already returned — they never alter
/// or re-request provider truth (provider-safe by construction). Sorting
/// compares the CUSTOMER total (customerPrice.customerAmount) when present,
/// falling back to the provider amount only when no quote was attached —
/// mixed provider currencies then stay grouped by currency instead of
/// producing a fake cross-currency "cheapest" (spec point 14: Cheapest must
/// be truly lowest CUSTOMER total).

/// The effective comparison amount: the backend-quoted customer total when
/// available, else the provider amount. Exposed for tests/cards.
double effectiveSortAmount(BaseOffer offer) {
  final quote = offer.customerPrice;
  if (quote != null && quote.customerAmount > 0) {
    return quote.customerAmount;
  }
  return offer.price;
}

/// Whether the list is sortable by customer total at all (all priced in the
/// same customer currency or no quotes attached). Used to keep mixed
/// currency fallbacks honest (grouped, not falsely ranked).
bool hasComparableCustomerTotals(Iterable<BaseOffer> offers) {
  final quoted = offers.where((o) => o.customerPrice != null).toList();
  if (quoted.isEmpty) return true; // provider-amount fallback for the whole list
  final currencies = quoted.map((o) => o.customerPrice!.customerCurrency).toSet();
  return currencies.length == 1;
}

// ---------------------------------------------------------------------------
// Filtering
// ---------------------------------------------------------------------------

/// Applies the shared filter set to flights — provider-safe: pure
/// post-filtering of the returned list, nothing re-requested.
List<FlightOffer> applyFlightFilters(List<FlightOffer> offers, SearchFilters filters) {
  var items = offers;
  if (filters.priceMin != null) {
    items = items.where((o) => effectiveSortAmount(o) >= filters.priceMin!).toList();
  }
  if (filters.priceMax != null) {
    items = items.where((o) => effectiveSortAmount(o) <= filters.priceMax!).toList();
  }
  if (filters.maxStops != null) {
    items = items.where((o) => (o.stops ?? 0) <= filters.maxStops!).toList();
  }
  if (filters.airlines != null && filters.airlines!.isNotEmpty) {
    final selected = filters.airlines!.toSet();
    items = items.where((o) => selected.contains(o.airline)).toList();
  }
  return items;
}

List<HotelOffer> applyHotelFilters(List<HotelOffer> offers, SearchFilters filters) {
  var items = offers;
  if (filters.priceMin != null) {
    items = items.where((o) => effectiveSortAmount(o) >= filters.priceMin!).toList();
  }
  if (filters.priceMax != null) {
    items = items.where((o) => effectiveSortAmount(o) <= filters.priceMax!).toList();
  }
  if (filters.minRating != null) {
    items = items.where((o) => (o.rating ?? 0) >= filters.minRating!).toList();
  }
  if (filters.amenities != null && filters.amenities!.isNotEmpty) {
    final wanted = filters.amenities!.toSet();
    items = items
        .where((o) => wanted.any(o.amenities.contains))
        .toList();
  }
  return items;
}

List<CarOffer> applyCarFilters(List<CarOffer> offers, SearchFilters filters) {
  var items = offers;
  if (filters.priceMin != null) {
    items = items.where((o) => effectiveSortAmount(o) >= filters.priceMin!).toList();
  }
  if (filters.priceMax != null) {
    items = items.where((o) => effectiveSortAmount(o) <= filters.priceMax!).toList();
  }
  if (filters.minSeats != null) {
    items = items.where((o) => (o.seats ?? 0) >= filters.minSeats!).toList();
  }
  if (filters.transmission != null) {
    items = items.where((o) => o.transmission == filters.transmission).toList();
  }
  return items;
}

// ---------------------------------------------------------------------------
// Sorting
// ---------------------------------------------------------------------------

/// Deterministic comparator base: customer-total-aware with a stable
/// tie-breaker so equal-amount offers never swap places between rebuilds.
int _compareByAmount(BaseOffer a, BaseOffer b, {bool descending = false}) {
  final comparable = hasComparableCustomerTotals([a, b]);
  final av = comparable ? effectiveSortAmount(a) : _grouped(a);
  final bv = comparable ? effectiveSortAmount(b) : _grouped(b);
  final primary = descending ? bv.compareTo(av) : av.compareTo(bv);
  if (primary != 0) return primary;
  return a.id.compareTo(b.id); // stable tie-breaker
}

/// Fallback bucket for non-comparable (mixed-currency) lists: group by
/// currency first so the list stays honest — no fake cross-currency ranking.
int _grouped(BaseOffer o) => o.currency.hashCode;

int _compareDuration(FlightOffer a, FlightOffer b) {
  final da = a.arrivalTime.difference(a.departureTime).inMinutes;
  final db = b.arrivalTime.difference(b.departureTime).inMinutes;
  return da.compareTo(db);
}

/// Sorts flights. `recommended` is an explicit no-op passthrough: the
/// backend's provider order IS the recommendation (deterministic registry
/// order), never a client-side invention.
List<FlightOffer> sortFlightResults(List<FlightOffer> list, SortOption option) {
  final items = List<FlightOffer>.from(list);
  switch (option) {
    case SortOption.priceLowHigh:
      items.sort((a, b) => _compareByAmount(a, b));
      break;
    case SortOption.priceHighLow:
      items.sort((a, b) => _compareByAmount(a, b, descending: true));
      break;
    case SortOption.rating:
      items.sort(
          (a, b) => _tie(b.rating ?? 0, a.rating ?? 0, a.id, b.id));
      break;
    case SortOption.duration:
      items.sort((a, b) => _compareDuration(a, b) != 0
          ? _compareDuration(a, b)
          : a.id.compareTo(b.id));
      break;
    case SortOption.stops:
      items.sort((a, b) => _tie(a.stops ?? 0, b.stops ?? 0, a.id, b.id));
      break;
    case SortOption.recommended:
      break; // passthrough — provider order is the recommendation.
  }
  return items;
}

/// Sorts hotels.
List<HotelOffer> sortHotelResults(List<HotelOffer> list, SortOption option) {
  final items = List<HotelOffer>.from(list);
  switch (option) {
    case SortOption.priceLowHigh:
      items.sort((a, b) => _compareByAmount(a, b));
      break;
    case SortOption.priceHighLow:
      items.sort((a, b) => _compareByAmount(a, b, descending: true));
      break;
    case SortOption.rating:
      items.sort((a, b) => _tie(b.rating ?? 0, a.rating ?? 0, a.id, b.id));
      break;
    case SortOption.duration:
    case SortOption.stops:
    case SortOption.recommended:
      break;
  }
  return items;
}

/// Sorts cars.
List<CarOffer> sortCarResults(List<CarOffer> list, SortOption option) {
  final items = List<CarOffer>.from(list);
  switch (option) {
    case SortOption.priceLowHigh:
      items.sort((a, b) => _compareByAmount(a, b));
      break;
    case SortOption.priceHighLow:
      items.sort((a, b) => _compareByAmount(a, b, descending: true));
      break;
    case SortOption.rating:
      items.sort((a, b) => _tie(b.rating ?? 0, a.rating ?? 0, a.id, b.id));
      break;
    case SortOption.duration:
    case SortOption.stops:
    case SortOption.recommended:
      break;
  }
  return items;
}

int _tie(num a, num b, String idA, String idB) =>
    a.compareTo(b) != 0 ? a.compareTo(b) : idA.compareTo(idB);
