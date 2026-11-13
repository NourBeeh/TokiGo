import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/features/home/presentation/stay_distance.dart';

/// The stay's honest distance line (owner decision, 2026-11).
///
/// A distance is only ever stated from a REAL source — the provider's own
/// figure, or the hotel's coordinates measured against a known city centre.
/// Missing, zero, unknown-city and out-of-range coordinates all hide the line
/// instead of inventing a number.
void main() {
  test('the provider distance is used verbatim when present', () {
    final double? km = stayDistanceToCenterKm(
      metadata: const <String, dynamic>{'distanceToCenter': 2.5},
      city: 'Cairo',
    );
    expect(km, 2.5);
  });

  test('a zero provider distance is ignored', () {
    expect(
      stayDistanceToCenterKm(
        metadata: const <String, dynamic>{'distanceToCenter': 0},
        city: 'Cairo',
      ),
      isNull,
    );
  });

  test('no provider distance and no coordinates hides the line', () {
    expect(
      stayDistanceToCenterKm(metadata: const <String, dynamic>{}, city: 'Cairo'),
      isNull,
    );
  });

  test('coordinates plus a known city centre measure the distance', () {
    final double? km = stayDistanceToCenterKm(
      metadata: const <String, dynamic>{
        'latitude': 30.0444,
        'longitude': 31.2357,
      },
      city: 'Cairo',
    );
    expect(km, isNotNull);
    expect(km, closeTo(0, 0.001));
  });

  test('coordinates without a known city centre hide the line', () {
    expect(
      stayDistanceToCenterKm(
        metadata: const <String, dynamic>{'latitude': 0, 'longitude': 0},
        city: 'Nowhere',
      ),
      isNull,
    );
  });

  test('out-of-range coordinates never produce a distance', () {
    expect(
      stayDistanceToCenterKm(
        metadata: const <String, dynamic>{'latitude': 200, 'longitude': 10},
        city: 'Cairo',
      ),
      isNull,
    );
    expect(
      stayDistanceToCenterKm(
        metadata: const <String, dynamic>{'latitude': 10, 'longitude': 400},
        city: 'Cairo',
      ),
      isNull,
    );
  });

  test('the printed value keeps one decimal below 10km and rounds above it', () {
    expect(formatStayDistance(1.25), '1.3');
    expect(formatStayDistance(12.4), '12');
  });
}
