import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/domain/models/offers/hotel_offer.dart';
import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/features/search/presentation/widgets/hotel_map_view.dart';

/// The real hotel map (owner decision, 2026-11).
///
/// * real OpenStreetMap tiles and the required attribution;
/// * one marker per result whose PROVIDER coordinates are present and in
///   range — missing or invalid coordinates produce no marker;
/// * an honest empty state when nothing is mappable;
/// * a marker tap identifies the hotel and shows the linking card.
HotelOffer _offer(
  String id, {
  double? lat,
  double? lng,
  String title = 'Riverside Grand',
}) {
  final Map<String, dynamic> metadata = <String, dynamic>{};
  if (lat != null) metadata['latitude'] = lat;
  if (lng != null) metadata['longitude'] = lng;
  return HotelOffer(
    id: id,
    providerId: 'nuitee',
    providerName: 'Nuitee',
    title: title,
    price: 186,
    currency: 'USD',
    city: 'Cairo',
    country: 'EG',
    checkIn: DateTime(2026, 12, 1),
    checkOut: DateTime(2026, 12, 3),
    roomType: 'Deluxe',
    metadata: metadata,
  );
}

Widget _host(
  HotelMapView map, {
  TextDirection direction = TextDirection.ltr,
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Directionality(
      textDirection: direction,
      child: Scaffold(body: SizedBox.expand(child: map)),
    ),
  );
}

void main() {
  testWidgets('one marker per geolocated result; none invented', (tester) async {
    await tester.pumpWidget(
      _host(
        HotelMapView(
          offers: <HotelOffer>[
            _offer('a', lat: 30.0, lng: 31.0),
            _offer('b', lat: 30.01, lng: 31.01),
            _offer('c'), // no coordinates
            _offer('d', lat: 200, lng: 10), // out of range
            _offer('e', lat: 10, lng: 400), // out of range
          ],
          selectedOfferId: null,
          onOfferSelected: (_) {},
          onOpenDetails: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Only the two real, in-range results get a marker.
    expect(find.byIcon(Icons.location_on_outlined), findsNWidgets(2));
    expect(find.byIcon(Icons.location_on_rounded), findsNothing);

    // The OSM attribution is present.
    expect(find.textContaining('OpenStreetMap contributors'), findsOneWidget);
  });

  testWidgets('a marker tap identifies the hotel and shows the linking card', (
    tester,
  ) async {
    String? selectedId;
    HotelOffer? selected;
    late StateSetter setHostState;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          setHostState = setState;
          return _host(
            HotelMapView(
              offers: <HotelOffer>[
                _offer('a', lat: 30.0, lng: 31.0, title: 'Riverside Grand'),
              ],
              selectedOfferId: selectedId,
              onOfferSelected: (HotelOffer offer) {
                selected = offer;
                setHostState(() => selectedId = offer.id);
              },
              onOpenDetails: (_) {},
            ),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.location_on_outlined));
    await tester.pumpAndSettle();
    expect(selected?.id, 'a');

    // The selected hotel is highlighted and its linking card is shown.
    expect(find.byIcon(Icons.location_on_rounded), findsOneWidget);
    expect(find.text('Riverside Grand'), findsOneWidget);
    expect(find.text('View details'), findsOneWidget);
  });

  testWidgets('no mappable result shows an honest empty state', (tester) async {
    await tester.pumpWidget(
      _host(
        HotelMapView(
          offers: <HotelOffer>[_offer('c'), _offer('d', lat: 200, lng: 10)],
          selectedOfferId: null,
          onOfferSelected: (_) {},
          onOpenDetails: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.location_on_outlined), findsNothing);
    expect(
      find.textContaining('No stay in these results has a mappable location'),
      findsOneWidget,
    );
  });

  testWidgets('the map mirrors its controls in RTL', (tester) async {
    await tester.pumpWidget(
      _host(
        HotelMapView(
          offers: <HotelOffer>[_offer('a', lat: 30.0, lng: 31.0)],
          selectedOfferId: 'a',
          onOfferSelected: (_) {},
          onOpenDetails: (_) {},
        ),
        direction: TextDirection.rtl,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.location_on_rounded), findsOneWidget);
    expect(find.text('View details'), findsOneWidget);
  });
}
