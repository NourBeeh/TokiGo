import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/core/domain/models/offers/car_offer.dart';
import 'package:tokigo/core/domain/models/offers/customer_price.dart';
import 'package:tokigo/core/domain/models/offers/flight_offer.dart';
import 'package:tokigo/core/domain/models/offers/hotel_offer.dart';
import 'package:tokigo/core/domain/models/offers/travel_package_offer.dart';
import 'package:tokigo/features/universal_search/data/offer_to_home_item_adapters.dart';

/// The four US-1 adapters map every normalized offer into the EXISTING
/// HomeItem contract — identifiers land in metadata for the booking and
/// live-validation flows, display fields are preserved, and flight lists
/// get the flightRecommendationList layout (US-1 STEP 26).
void main() {
  final now = DateTime(2026, 10, 1);

  final flight = FlightOffer(
    id: 'f1',
    providerId: 'duffel',
    providerName: 'Duffel',
    title: 'Cairo to Dubai',
    price: 450,
    currency: 'USD',
    origin: 'CAI',
    destination: 'DXB',
    departureTime: now,
    arrivalTime: now.add(const Duration(hours: 3)),
    airline: 'EgyptAir',
    flightNumber: '985',
    stops: 0,
  );

  final hotel = HotelOffer(
    id: 'h1',
    providerId: 'nuitee',
    providerName: 'Nuitee',
    title: 'Downtown Dubai Hotel',
    price: 120,
    currency: 'USD',
    rating: 4.5,
    reviewCount: 210,
    city: 'Dubai',
    country: 'UAE',
    checkIn: now,
    checkOut: now.add(const Duration(days: 2)),
    roomType: 'Deluxe',
    amenities: const ['WiFi', 'Pool', 'Gym'],
  );

  final car = CarOffer(
    id: 'c1',
    providerId: 'car-provider',
    providerName: 'Europcar',
    title: 'Compact Car',
    price: 80,
    currency: 'USD',
    pickupLocation: 'Riyadh Airport',
    dropoffLocation: 'Riyadh City',
    pickupTime: now,
    dropoffTime: now.add(const Duration(days: 3)),
    carType: 'Compact',
    transmission: 'Automatic',
    seats: 5,
  );

  final packageOffer = TravelPackageOffer(
    id: 'p1',
    providerId: 'pkg-provider',
    providerName: 'Packages Co',
    title: 'Sharm All-Inclusive',
    price: 600,
    currency: 'USD',
    destination: 'Sharm El Sheikh',
    durationDays: 5,
    inclusions: const ['Flights', 'Hotel', 'Transfers'],
  );

  test('FlightOffer adapter maps identifiers + route metadata', () {
    final item = OfferToHomeItemAdapters.fromFlightOffer(flight);
    expect(item.type, HomeCardType.flight);
    expect(item.title, 'Cairo to Dubai');
    expect(item.subtitle, 'CAI → DXB');
    expect(item.price, 450);
    expect(item.metadata['providerOfferId'], 'f1');
    expect(item.metadata['providerId'], 'duffel');
    expect(item.metadata['providerName'], 'Duffel');
    expect(item.metadata['origin'], 'CAI');
    expect(item.metadata['destination'], 'DXB');
    expect(item.metadata['airline'], 'EgyptAir');
    expect(item.metadata['stops'], 0);
  });

  test('HotelOffer adapter maps location + stay metadata', () {
    final item = OfferToHomeItemAdapters.fromHotelOffer(hotel);
    expect(item.type, HomeCardType.hotel);
    expect(item.subtitle, 'Dubai, UAE');
    expect(item.rating, 4.5);
    expect(item.reviewCount, 210);
    expect(item.metadata['providerOfferId'], 'h1');
    expect(item.metadata['city'], 'Dubai');
    expect(item.metadata['roomType'], 'Deluxe');
    expect(item.highlights, containsAll(<String>['WiFi', 'Pool', 'Gym']));
  });

  test('CarOffer adapter maps rental metadata', () {
    final item = OfferToHomeItemAdapters.fromCarOffer(car);
    expect(item.type, HomeCardType.car);
    expect(item.subtitle, 'Riyadh Airport');
    expect(item.metadata['providerOfferId'], 'c1');
    expect(item.metadata['pickupLocation'], 'Riyadh Airport');
    expect(item.metadata['carType'], 'Compact');
    expect(item.metadata['seats'], 5);
    expect(item.highlights, contains('Automatic'));
  });

  test('TravelPackageOffer adapter maps destination + inclusions', () {
    final item = OfferToHomeItemAdapters.fromTravelPackageOffer(packageOffer);
    expect(item.type, HomeCardType.package);
    expect(item.subtitle, 'Sharm El Sheikh');
    expect(item.metadata['providerOfferId'], 'p1');
    expect(item.metadata['durationDays'], 5);
    expect(item.metadata['inclusions'], contains('Flights'));
  });

  test('customer price takes precedence when present', () {
    final priced = HotelOffer(
      id: 'h2',
      providerId: 'nuitee',
      providerName: 'Nuitee',
      title: 'Priced Hotel',
      price: 100,
      currency: 'USD',
      customerPrice: CustomerPrice(
        providerAmount: 100,
        providerCurrency: 'USD',
        customerAmount: 4900,
        customerCurrency: 'EGP',
        pricingVersion: 'v1',
        expiresAt: '2026-10-01T00:00:00Z',
      ),
      city: 'Dubai',
      country: 'UAE',
      checkIn: now,
      checkOut: now.add(const Duration(days: 1)),
      roomType: 'Standard',
    );
    final item = OfferToHomeItemAdapters.fromHotelOffer(priced);
    expect(item.price, 4900);
    expect(item.currency, 'EGP');
  });

  test('flights group into flightRecommendationList; others vertical', () {
    final flightSections = offersToHomeSections(<dynamic>[flight]);
    expect(flightSections, isNotEmpty);
    expect(
      flightSections.first.layout,
      HomeSectionLayout.flightRecommendationList,
    );

    final hotelSections = offersToHomeSections(<dynamic>[hotel]);
    expect(hotelSections.first.layout, HomeSectionLayout.vertical);
  });

  test('empty offer list produces no sections', () {
    expect(offersToHomeSections(<dynamic>[]), isEmpty);
  });

  test('adaptAll dispatches over mixed lists', () {
    final items =
        OfferToHomeItemAdapters.adaptAll(<dynamic>[flight, hotel, car, packageOffer]).toList();
    expect(items, hasLength(4));
    expect(items.map((i) => i.type), containsAll(<HomeCardType>[
      HomeCardType.flight,
      HomeCardType.hotel,
      HomeCardType.car,
      HomeCardType.package,
    ]));
  });
}
