import 'package:tokigo/core/domain/models/offers/flight_offer.dart';
import 'package:tokigo/core/domain/models/offers/hotel_offer.dart';
import 'package:tokigo/core/domain/models/offers/car_offer.dart';
import 'package:tokigo/features/search/domain/sort_option.dart';

List<FlightOffer> sortFlights(List<FlightOffer> list, SortOption option) {
  final items = List<FlightOffer>.from(list);
  switch (option) {
    case SortOption.priceLowHigh:
      items.sort((a, b) => a.price.compareTo(b.price));
      break;
    case SortOption.priceHighLow:
      items.sort((a, b) => b.price.compareTo(a.price));
      break;
    case SortOption.rating:
      items.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
      break;
    case SortOption.duration:
      items.sort((a, b) {
        final da = a.arrivalTime.difference(a.departureTime).inMinutes;
        final db = b.arrivalTime.difference(b.departureTime).inMinutes;
        return da.compareTo(db);
      });
      break;
    case SortOption.stops:
      items.sort((a, b) => (a.stops ?? 0).compareTo(b.stops ?? 0));
      break;
    case SortOption.recommended:
      break;
  }
  return items;
}

List<HotelOffer> sortHotels(List<HotelOffer> list, SortOption option) {
  final items = List<HotelOffer>.from(list);
  switch (option) {
    case SortOption.priceLowHigh:
      items.sort((a, b) => a.price.compareTo(b.price));
      break;
    case SortOption.priceHighLow:
      items.sort((a, b) => b.price.compareTo(a.price));
      break;
    case SortOption.rating:
      items.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
      break;
    case SortOption.recommended:
    case SortOption.duration:
    case SortOption.stops:
      break;
  }
  return items;
}

List<CarOffer> sortCars(List<CarOffer> list, SortOption option) {
  final items = List<CarOffer>.from(list);
  switch (option) {
    case SortOption.priceLowHigh:
      items.sort((a, b) => a.price.compareTo(b.price));
      break;
    case SortOption.priceHighLow:
      items.sort((a, b) => b.price.compareTo(a.price));
      break;
    case SortOption.recommended:
    case SortOption.rating:
    case SortOption.duration:
    case SortOption.stops:
      break;
  }
  return items;
}