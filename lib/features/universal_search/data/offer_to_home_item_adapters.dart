import 'package:flutter/foundation.dart';

import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_section.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/core/domain/models/offers/base_offer.dart';
import 'package:tokigo/core/domain/models/offers/car_offer.dart';
import 'package:tokigo/core/domain/models/offers/flight_offer.dart';
import 'package:tokigo/core/domain/models/offers/hotel_offer.dart';
import 'package:tokigo/core/domain/models/offers/travel_package_offer.dart';

/// Adapters from the existing normalized offers into `HomeItem`s so
/// Universal Search results render through the EXISTING
/// `HomeSectionWidget` + Product Card system (US-1 STEP 16). No card
/// system is created, no `HomeItem` field is changed — metadata carries
/// the identifiers the booking + live-validation flows already expect.
@immutable
abstract final class OfferToHomeItemAdapters {
  /// Base mapping shared by every offer: identifiers, display fields and
  /// the product-specific metadata entries merged in one pass.
  static HomeItem _adapt(
    BaseOffer offer,
    HomeCardType type, {
    String? subtitle,
    List<String> highlights = const [],
    Map<String, dynamic> productMetadata = const {},
  }) {
    return HomeItem(
      id: offer.id,
      type: type,
      title: offer.title,
      subtitle: subtitle ?? offer.subtitle,
      imageUrl: offer.imageUrl,
      price: offer.customerPrice?.customerAmount ?? offer.price,
      currency: offer.customerPrice?.customerCurrency ?? offer.currency,
      rating: offer.rating,
      reviewCount: offer.reviewCount,
      badge: offer.metadata['badge'] as String?,
      highlights: highlights,
      tags: (offer.metadata['tags'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      actionLabel: offer.metadata['actionLabel'] as String?,
      metadata: <String, dynamic>{
        ...offer.metadata,
        ...productMetadata,
        'providerOfferId': offer.id,
        'providerId': offer.providerId,
        'providerName': offer.providerName,
      },
    );
  }

  static HomeItem fromFlightOffer(FlightOffer offer) {
    return _adapt(
      offer,
      HomeCardType.flight,
      subtitle: '${offer.origin} → ${offer.destination}',
      highlights: <String>[
        offer.airline,
        if (offer.cabinClass != null) offer.cabinClass!,
      ],
      productMetadata: <String, dynamic>{
        'origin': offer.origin,
        'destination': offer.destination,
        'departureTime': offer.departureTime.toIso8601String(),
        'arrivalTime': offer.arrivalTime.toIso8601String(),
        'airline': offer.airline,
        'flightNumber': offer.flightNumber,
        'stops': offer.stops ?? 0,
      },
    );
  }

  static HomeItem fromHotelOffer(HotelOffer offer) {
    return _adapt(
      offer,
      HomeCardType.hotel,
      subtitle: '${offer.city}, ${offer.country}',
      highlights: offer.amenities.take(3).toList(),
      productMetadata: <String, dynamic>{
        'city': offer.city,
        'country': offer.country,
        'checkIn': offer.checkIn.toIso8601String(),
        'checkOut': offer.checkOut.toIso8601String(),
        'roomType': offer.roomType,
      },
    );
  }

  static HomeItem fromCarOffer(CarOffer offer) {
    return _adapt(
      offer,
      HomeCardType.car,
      subtitle: offer.pickupLocation,
      highlights: <String>[
        offer.carType,
        if (offer.transmission != null) offer.transmission!,
      ],
      productMetadata: <String, dynamic>{
        'pickupLocation': offer.pickupLocation,
        'dropoffLocation': offer.dropoffLocation,
        'pickupTime': offer.pickupTime.toIso8601String(),
        'dropoffTime': offer.dropoffTime.toIso8601String(),
        'carType': offer.carType,
        'seats': offer.seats,
      },
    );
  }

  static HomeItem fromTravelPackageOffer(TravelPackageOffer offer) {
    return _adapt(
      offer,
      HomeCardType.package,
      subtitle: offer.destination,
      highlights: offer.inclusions.take(3).toList(),
      productMetadata: <String, dynamic>{
        'destination': offer.destination,
        'durationDays': offer.durationDays,
        'inclusions': offer.inclusions,
      },
    );
  }

  /// Dispatch over any normalized offer list.
  static Iterable<HomeItem> adaptAll(List<dynamic> offers) {
    return offers.map<HomeItem>((offer) {
      if (offer is FlightOffer) return fromFlightOffer(offer);
      if (offer is HotelOffer) return fromHotelOffer(offer);
      if (offer is CarOffer) return fromCarOffer(offer);
      if (offer is TravelPackageOffer) return fromTravelPackageOffer(offer);
      throw ArgumentError.value(offer, 'offer', 'Unsupported offer type');
    });
  }
}

/// Groups adapted items into a single renderable section — flights get the
/// `flightRecommendationList` layout the card system already knows;
/// everything else renders vertical (US-1 STEP 17).
HomeSection offersResultSection(List<dynamic> offers) {
  final items = OfferToHomeItemAdapters.adaptAll(offers).toList();
  if (items.isEmpty) {
    return const HomeSection(
      id: 'universal-search-results',
      title: 'Results',
      layout: HomeSectionLayout.vertical,
      items: [],
    );
  }

  final isFlight = items.first.type == HomeCardType.flight;
  return HomeSection(
    id: 'universal-search-results',
    title: 'Results',
    layout: isFlight
        ? HomeSectionLayout.flightRecommendationList
        : HomeSectionLayout.vertical,
    items: items,
  );
}

/// Adapts an offer list into display sections (empty list → no sections so
/// the caller branches to its empty state).
List<HomeSection> offersToHomeSections(List<dynamic> offers) {
  if (offers.isEmpty) return const <HomeSection>[];
  return <HomeSection>[offersResultSection(offers)];
}
