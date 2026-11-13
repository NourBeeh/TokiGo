import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/features/home/presentation/nearby_stay_ranking.dart';

/// Truthful "Stays Near You" ranking (owner decision, 2026-11).
///
/// * no location → the backend order is preserved exactly;
/// * a valid location → real distance, nearest first;
/// * a stay with no coordinates sorts last (never placed as if close);
/// * price only breaks a distance tie, and only in a matched currency.
HomeItem _stay(
  String id, {
  double? lat,
  double? lng,
  double? price,
  String? currency,
}) {
  final Map<String, dynamic> metadata = <String, dynamic>{};
  if (lat != null) metadata['latitude'] = lat;
  if (lng != null) metadata['longitude'] = lng;
  return HomeItem(
    id: id,
    type: HomeCardType.hotel,
    title: 'Hotel $id',
    price: price,
    currency: currency,
    metadata: metadata,
  );
}

void main() {
  test('no location keeps the backend order exactly', () {
    final List<HomeItem> stays = <HomeItem>[
      _stay('a', lat: 10, lng: 10),
      _stay('b', lat: 1, lng: 1),
    ];

    final List<HomeItem> ranked = NearbyStayRanking.rankNearestFirst(stays);

    expect(ranked.map((HomeItem s) => s.id).toList(), <String>['a', 'b']);
  });

  test('a valid location ranks nearest-first by real distance', () {
    final List<HomeItem> stays = <HomeItem>[
      _stay('far', lat: 10, lng: 10),
      _stay('near', lat: 0.1, lng: 0.1),
      _stay('mid', lat: 1, lng: 1),
    ];

    final List<HomeItem> ranked = NearbyStayRanking.rankNearestFirst(
      stays,
      latitude: 0,
      longitude: 0,
    );

    expect(
      ranked.map((HomeItem s) => s.id).toList(),
      <String>['near', 'mid', 'far'],
    );
  });

  test('a stay with no coordinates sorts last, in backend order', () {
    final List<HomeItem> stays = <HomeItem>[
      _stay('unknown-1'),
      _stay('near', lat: 0.1, lng: 0.1),
      _stay('unknown-2'),
    ];

    final List<HomeItem> ranked = NearbyStayRanking.rankNearestFirst(
      stays,
      latitude: 0,
      longitude: 0,
    );

    expect(
      ranked.map((HomeItem s) => s.id).toList(),
      <String>['near', 'unknown-1', 'unknown-2'],
    );
  });

  test('price breaks a distance tie only in a matched currency', () {
    final List<HomeItem> stays = <HomeItem>[
      _stay('expensive', lat: 1, lng: 1, price: 500, currency: 'USD'),
      _stay('cheap', lat: 1, lng: 1, price: 100, currency: 'USD'),
      // Same distance, different currency: the backend order must hold.
      _stay('foreign', lat: 1, lng: 1, price: 1, currency: 'EUR'),
    ];

    final List<HomeItem> ranked = NearbyStayRanking.rankNearestFirst(
      stays,
      latitude: 0,
      longitude: 0,
    );

    expect(ranked.first.id, 'cheap');
    expect(ranked.last.id, 'foreign');
  });

  test('distanceToPointKm measures real coordinates and nulls otherwise', () {
    final HomeItem located = _stay('a', lat: 0, lng: 0);
    final double km = NearbyStayRanking.distanceToPointKm(
      located,
      latitude: 0,
      longitude: 0,
    )!;
    expect(km, 0);

    final double farKm = NearbyStayRanking.distanceToPointKm(
      located,
      latitude: 1,
      longitude: 1,
    )!;
    expect(farKm, greaterThan(100));

    expect(
      NearbyStayRanking.distanceToPointKm(
        _stay('no-coords'),
        latitude: 0,
        longitude: 0,
      ),
      isNull,
    );
  });

  test('invalid coordinates are treated as no coordinates and sort last', () {
    HomeItem withMetadata(String id, Map<String, dynamic> metadata) => HomeItem(
          id: id,
          type: HomeCardType.hotel,
          title: 'Hotel $id',
          metadata: metadata,
        );

    final List<HomeItem> stays = <HomeItem>[
      withMetadata(
        'bad-lat',
        const <String, dynamic>{'latitude': 200, 'longitude': 10},
      ),
      withMetadata(
        'bad-lng',
        const <String, dynamic>{'latitude': 10, 'longitude': 400},
      ),
      withMetadata(
        'non-numeric',
        const <String, dynamic>{'latitude': 'abc', 'longitude': 'xyz'},
      ),
      withMetadata(
        'nan',
        const <String, dynamic>{'latitude': double.nan, 'longitude': 10},
      ),
      _stay('near', lat: 0.1, lng: 0.1),
    ];

    final List<HomeItem> ranked = NearbyStayRanking.rankNearestFirst(
      stays,
      latitude: 0,
      longitude: 0,
    );

    expect(ranked.first.id, 'near');
    // Every unusable coordinate stays after the located one, in backend order.
    expect(
      ranked.skip(1).map((HomeItem s) => s.id).toList(),
      <String>['bad-lat', 'bad-lng', 'non-numeric', 'nan'],
    );
  });

  test('an invalid origin leaves the backend order untouched', () {
    final List<HomeItem> stays = <HomeItem>[
      _stay('far', lat: 10, lng: 10),
      _stay('near', lat: 0.1, lng: 0.1),
    ];

    for (final double badLatitude in <double>[200, double.nan, -200]) {
      expect(
        NearbyStayRanking.rankNearestFirst(
          stays,
          latitude: badLatitude,
          longitude: 0,
        ).map((HomeItem s) => s.id).toList(),
        <String>['far', 'near'],
      );
    }
  });

  test('unlocated stays keep the backend order after the located ones', () {
    final List<HomeItem> stays = <HomeItem>[
      _stay('unknown-a'),
      _stay('near', lat: 0.1, lng: 0.1),
      _stay('unknown-b'),
      _stay('unknown-c'),
    ];

    final List<HomeItem> ranked = NearbyStayRanking.rankNearestFirst(
      stays,
      latitude: 0,
      longitude: 0,
    );

    expect(
      ranked.map((HomeItem s) => s.id).toList(),
      <String>['near', 'unknown-a', 'unknown-b', 'unknown-c'],
    );
  });
}
