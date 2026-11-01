import 'dart:math' as math;

/// The stay's distance to the city centre, when it can be stated honestly.
///
/// Two real sources are accepted, in order:
/// * the provider's own distance (`distanceToCenter` / `distanceToCenterKm`);
/// * the hotel's coordinates plus a known city-centre coordinate, measured
///   with the haversine formula.
///
/// A value is never invented: when neither source exists the card simply hides
/// the line.
double? stayDistanceToCenterKm({
  required Map<String, dynamic> metadata,
  required String city,
}) {
  final double? stated = _firstNumber(metadata, const <String>[
    'distanceToCenterKm',
    'distanceToCenter',
    'distance_from_center_km',
  ]);
  if (stated != null && stated > 0) return stated;

  final double? latitude = _firstNumber(metadata, const <String>[
    'latitude',
    'lat',
  ]);
  final double? longitude = _firstNumber(metadata, const <String>[
    'longitude',
    'lng',
    'long',
  ]);
  if (latitude == null || longitude == null) return null;

  final _Coordinate? center = _cityCenters[city.trim().toLowerCase()];
  if (center == null) return null;

  const double earthRadiusKm = 6371;
  final double dLat = _radians(latitude - center.latitude);
  final double dLon = _radians(longitude - center.longitude);
  final double a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_radians(center.latitude)) *
          math.cos(_radians(latitude)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final double distance =
      earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return distance.isFinite ? distance : null;
}

/// The value the card prints: one decimal below 10 km, whole numbers above it.
String formatStayDistance(double km) =>
    km < 10 ? km.toStringAsFixed(1) : km.round().toString();

double? _firstNumber(Map<String, dynamic> metadata, List<String> keys) {
  for (final String key in keys) {
    final Object? value = metadata[key];
    if (value is num) return value.toDouble();
    if (value is String) {
      final double? parsed = double.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
  }
  return null;
}

double _radians(double degrees) => degrees * math.pi / 180;

class _Coordinate {
  const _Coordinate(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

/// Approximate centres of the markets TokiGo serves. Used only to measure a
/// hotel's distance when the PROVIDER supplied its coordinates — the hotel's
/// own position is never guessed.
const Map<String, _Coordinate> _cityCenters = <String, _Coordinate>{
  'cairo': _Coordinate(30.0444, 31.2357),
  'hurghada': _Coordinate(27.2579, 33.8116),
  'sharm el sheikh': _Coordinate(27.9158, 34.3300),
  'luxor': _Coordinate(25.6872, 32.6396),
  'dubai': _Coordinate(25.2048, 55.2708),
  'abu dhabi': _Coordinate(24.4539, 54.3773),
  'riyadh': _Coordinate(24.7136, 46.6753),
  'jeddah': _Coordinate(21.4858, 39.1925),
  'istanbul': _Coordinate(41.0082, 28.9784),
  'antalya': _Coordinate(36.8969, 30.7133),
  'doha': _Coordinate(25.2854, 51.5310),
  'kuwait city': _Coordinate(29.3759, 47.9774),
  'amman': _Coordinate(31.9539, 35.9106),
  'london': _Coordinate(51.5072, -0.1276),
  'paris': _Coordinate(48.8566, 2.3522),
  'nice': _Coordinate(43.7102, 7.2620),
  'rome': _Coordinate(41.9028, 12.4964),
  'milan': _Coordinate(45.4642, 9.1900),
  'madrid': _Coordinate(40.4168, -3.7038),
  'barcelona': _Coordinate(41.3874, 2.1686),
  'berlin': _Coordinate(52.5200, 13.4050),
  'munich': _Coordinate(48.1351, 11.5820),
  'athens': _Coordinate(37.9838, 23.7275),
  'new york': _Coordinate(40.7128, -74.0060),
  'miami': _Coordinate(25.7617, -80.1918),
  'bangkok': _Coordinate(13.7563, 100.5018),
  'singapore': _Coordinate(1.3521, 103.8198),
  'kuala lumpur': _Coordinate(3.1390, 101.6869),
  'tokyo': _Coordinate(35.6762, 139.6503),
};
