import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/domain/models/offers/hotel_offer.dart';
import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/features/search/presentation/widgets/hotel_map_view.dart';

/// The hotel map's provider configuration (owner decision, 2026-11).
///
/// The map is a REAL map: OpenStreetMap tiles through flutter_map, with the
/// required attribution and a declared user-agent package so the tile
/// provider can identify the app. Markers come only from provider coordinates.
void main() {
  testWidgets('the map uses the OpenStreetMap tile endpoint and attribution', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SizedBox.expand(
            child: HotelMapView(
              offers: const <HotelOffer>[],
              selectedOfferId: null,
              onOfferSelected: (_) {},
              onOpenDetails: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final TileLayer tileLayer = tester.widget<TileLayer>(
      find.byType(TileLayer),
    );
    expect(
      tileLayer.urlTemplate,
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    );
    // flutter_map takes the user-agent package as a constructor parameter and
    // stores it in the tile provider's User-Agent header; the widget exposes
    // the provider, not a getter of its own.
    expect(
      tileLayer.tileProvider.headers['User-Agent'],
      'flutter_map (com.tokigo.tokigo)',
    );

    // The OSM attribution is always shown.
    expect(find.textContaining('OpenStreetMap contributors'), findsOneWidget);
  });
}
