import 'package:flutter_test/flutter_test.dart';
import 'package:tokigo/core/domain/models/offers/flight_offer.dart';
import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_section.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';

void main() {
  test('FlightOffer creates with required fields', () {
    final offer = FlightOffer(
      id: '1',
      providerId: 'p1',
      providerName: 'Provider A',
      title: 'NYC → LON',
      price: 299,
      currency: 'USD',
      origin: 'NYC',
      destination: 'LON',
      departureTime: DateTime.utc(2025, 1, 1),
      arrivalTime: DateTime.utc(2025, 1, 2),
      airline: 'AA',
      flightNumber: 'AA100',
    );
    expect(offer.offerType, 'flight');
    expect(offer.origin, 'NYC');
  });

  test('HomeItem immutable fields', () {
    const item = HomeItem(
      id: 'i1',
      type: HomeCardType.hotel,
      title: 'Hotel',
    );
    expect(item.id, 'i1');
    expect(item.type, HomeCardType.hotel);
  });

  test('HomeSection layout', () {
    const section = HomeSection(
      id: 's1',
      title: 'Featured',
      layout: HomeSectionLayout.horizontalPeek,
      items: [],
    );
    expect(section.layout, HomeSectionLayout.horizontalPeek);
  });
}