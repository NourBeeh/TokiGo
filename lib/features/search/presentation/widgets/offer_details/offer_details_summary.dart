import 'package:tokigo/core/domain/models/offers/car_offer.dart';
import 'package:tokigo/core/domain/models/offers/flight_offer.dart';
import 'package:tokigo/core/domain/models/offers/hotel_offer.dart';
import 'package:tokigo/core/domain/models/offers/travel_package_offer.dart';

/// The offer's own headline facts, read from the offer and nothing else.
///
/// Extracted from `OfferDetailsPage` so the mapping is testable without a
/// widget tree: an unknown vertical answers an empty summary (no invented
/// title, no invented price) rather than a placeholder.
typedef OfferDetailsSummary = ({
  String title,
  String subtitle,
  String? imageUrl,
  double price,
  String currency,
});

/// Title / subtitle / photo / price for any supported offer type.
///
/// A flight's subtitle is its route; a hotel's is `city, country`; a car's is
/// its class; a package's is its destination. All four are provider fields —
/// none of them is composed from assumptions.
OfferDetailsSummary offerDetailsSummaryOf(Object offer) {
  return switch (offer) {
    FlightOffer(
      :final title,
      :final origin,
      :final destination,
      :final price,
      :final currency,
      :final imageUrl,
    ) =>
      (
        title: title,
        subtitle: '$origin → $destination',
        imageUrl: imageUrl,
        price: price,
        currency: currency,
      ),
    HotelOffer(
      :final title,
      :final city,
      :final country,
      :final price,
      :final currency,
      :final imageUrl,
    ) =>
      (
        title: title,
        subtitle: '$city, $country',
        imageUrl: imageUrl,
        price: price,
        currency: currency,
      ),
    CarOffer(
      :final title,
      :final carType,
      :final price,
      :final currency,
      :final imageUrl,
    ) =>
      (
        title: title,
        subtitle: carType,
        imageUrl: imageUrl,
        price: price,
        currency: currency,
      ),
    TravelPackageOffer(
      :final title,
      :final destination,
      :final price,
      :final currency,
      :final imageUrl,
    ) =>
      (
        title: title,
        subtitle: destination,
        imageUrl: imageUrl,
        price: price,
        currency: currency,
      ),
    _ => (title: '', subtitle: '', imageUrl: null, price: 0, currency: 'USD'),
  };
}
