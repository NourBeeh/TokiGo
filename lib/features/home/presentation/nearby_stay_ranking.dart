import 'dart:math' as math;

import 'package:tokigo/core/domain/models/home/home_item.dart';

/// Truthful "Stays Near You" ranking (owner decision, 2026-11).
///
/// When a valid user location exists, the recommended stays are ordered by
/// their real distance from that location, nearest first. A stay with no
/// usable coordinates is appended after the located ones, in backend order —
/// it is never placed as if it were close, and its distance is never invented.
/// With no location, the backend order is kept exactly (the honest fallback).
///
/// Price is only a tie-breaker between two stays at the SAME distance, and
/// only when both prices exist in the SAME currency — never a cross-currency
/// comparison, never a reason to claim the cheapest is the nearest.
abstract final class NearbyStayRanking {
  /// The stay's distance from a point in kilometres, or null when the stay
  /// carries no usable coordinates.
  static double? distanceToPointKm(
    HomeItem item, {
    required double latitude,
    required double longitude,
  }) {
    if (!_isValidLatitude(latitude) || !_isValidLongitude(longitude)) {
      return null;
    }
    final double? hotelLat = _coordinate(
      item,
      const <String>['latitude', 'lat'],
      isLatitude: true,
    );
    final double? hotelLng = _coordinate(
      item,
      const <String>['longitude', 'lng', 'long'],
      isLatitude: false,
    );
    if (hotelLat == null || hotelLng == null) return null;
    return _haversineKm(latitude, longitude, hotelLat, hotelLng);
  }

  /// Ranks [stays] nearest-first from [latitude]/[longitude].
  ///
  /// A null origin returns the input unchanged, preserving the backend order.
  static List<HomeItem> rankNearestFirst(
    List<HomeItem> stays, {
    double? latitude,
    double? longitude,
  }) {
    if (stays.isEmpty || latitude == null || longitude == null) return stays;

    final List<_RankedStay> entries = <_RankedStay>[];
    for (int i = 0; i < stays.length; i++) {
      final HomeItem stay = stays[i];
      entries.add(
        _RankedStay(
          stay,
          distanceToPointKm(stay, latitude: latitude, longitude: longitude),
          i,
        ),
      );
    }

    // Deterministic: distance, then price (only on a matched currency),
    // then the original backend order.
    entries.sort((_RankedStay a, _RankedStay b) {
      final double? aDistance = a.distanceKm;
      final double? bDistance = b.distanceKm;
      if (aDistance == null && bDistance == null) {
        return a.order.compareTo(b.order);
      }
      // A stay with no coordinates always sorts last.
      if (aDistance == null) return 1;
      if (bDistance == null) return -1;
      final int byDistance = aDistance.compareTo(bDistance);
      if (byDistance != 0) return byDistance;

      final double? aPrice = a.stay.price;
      final double? bPrice = b.stay.price;
      final String aCurrency = (a.stay.currency ?? '').toUpperCase();
      final String bCurrency = (b.stay.currency ?? '').toUpperCase();
      if (aPrice != null &&
          bPrice != null &&
          aCurrency.isNotEmpty &&
          aCurrency == bCurrency) {
        final int byPrice = aPrice.compareTo(bPrice);
        if (byPrice != 0) return byPrice;
      }
      return a.order.compareTo(b.order);
    });

    return entries.map((_RankedStay e) => e.stay).toList();
  }

  /// Reads a coordinate, rejecting values that cannot be a real position.
  ///
  /// A provider may send `null`, an empty string, a non-numeric string, `NaN`
  /// or an out-of-range number (a latitude of 200 is not a place). Every one of
  /// those is treated as "no usable coordinate" — the stay is never given a
  /// fabricated distance and never sorted as if it were close.
  static double? _coordinate(
    HomeItem item,
    List<String> keys, {
    required bool isLatitude,
  }) {
    for (final String key in keys) {
      final Object? value = item.metadata[key];
      final double? parsed = switch (value) {
        num n => n.toDouble(),
        String s => double.tryParse(s.trim()),
        _ => null,
      };
      if (parsed == null || !parsed.isFinite) continue;
      final bool inRange = isLatitude
          ? (parsed >= -90 && parsed <= 90)
          : (parsed >= -180 && parsed <= 180);
      if (inRange) return parsed;
    }
    return null;
  }

  static bool _isValidLatitude(double value) =>
      value.isFinite && value >= -90 && value <= 90;

  static bool _isValidLongitude(double value) =>
      value.isFinite && value >= -180 && value <= 180;

  static double _haversineKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double earthRadiusKm = 6371;
    final double dLat = _radians(lat2 - lat1);
    final double dLon = _radians(lng2 - lng1);
    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_radians(lat1)) *
            math.cos(_radians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final double distance =
        earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return distance.isFinite ? distance : 0;
  }

  static double _radians(double degrees) => degrees * math.pi / 180;
}

class _RankedStay {
  _RankedStay(this.stay, this.distanceKm, this.order);

  final HomeItem stay;
  final double? distanceKm;

  /// Original index — the stable tie-breaker for equal keys.
  final int order;
}
