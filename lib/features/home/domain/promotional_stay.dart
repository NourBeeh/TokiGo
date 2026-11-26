import 'package:flutter/foundation.dart';

/// A cached Nearby Stays payload may be shown while the network settles, but
/// once it passes this age it is no longer "the latest nearby hotels" and must
/// be discarded instead of presented as current.
const Duration nearbyStaysFreshnessTtl = Duration(hours: 24);

/// A promotional Nearby Stays card (R3/R5).
///
/// This is DISCOVERY information, not a bookable offer. It never carries a
/// provider rate/offer id, a prebook id, or a verification flag: the app must
/// run a fresh live search before any booking. The price is the minimum valid
/// one-night rate across the seven-night window the backend searched.
@immutable
class PromotionalStay {
  const PromotionalStay({
    required this.hotelId,
    required this.hotelName,
    required this.city,
    required this.country,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    required this.promotionalMinimumPrice,
    required this.currency,
    required this.searchedFromDate,
    required this.searchedToDate,
    required this.occupancy,
    required this.nationality,
    required this.provider,
    required this.fetchedAt,
    required this.locationConfidence,
    this.image,
    this.rating,
    this.reviewCount,
  });

  final String hotelId;
  final String hotelName;
  final String city;
  final String country;
  final String? image;
  final double latitude;
  final double longitude;
  final double distanceKm;
  final double? rating;
  final int? reviewCount;
  final double promotionalMinimumPrice;
  final String currency;
  final String searchedFromDate;
  final String searchedToDate;
  final int occupancy;
  final String nationality;
  final String provider;
  final DateTime fetchedAt;
  final String locationConfidence;

  /// True when the provider reported a usable review score AND count.
  bool get hasRealReviews => (reviewCount ?? 0) > 0 && rating != null;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'hotelId': hotelId,
    'hotelName': hotelName,
    'city': city,
    'country': country,
    'image': image,
    'latitude': latitude,
    'longitude': longitude,
    'distanceKm': distanceKm,
    'rating': rating,
    'reviewCount': reviewCount,
    'promotionalMinimumPrice': promotionalMinimumPrice,
    'currency': currency,
    'searchedFromDate': searchedFromDate,
    'searchedToDate': searchedToDate,
    'occupancy': occupancy,
    'nationality': nationality,
    'provider': provider,
    'fetchedAt': fetchedAt.toIso8601String(),
    'locationConfidence': locationConfidence,
  };

  /// Parses one card. Returns null for a malformed record — a cached or
  /// network payload is never allowed to crash Home.
  static PromotionalStay? tryParse(Map<String, dynamic> map) {
    final String hotelId = map['hotelId']?.toString().trim() ?? '';
    final String hotelName =
        map['hotelName']?.toString().trim() ??
        map['name']?.toString().trim() ??
        '';
    final double? latitude = _number(map['latitude'] ?? map['lat']);
    final double? longitude = _number(
      map['longitude'] ?? map['lng'] ?? map['long'],
    );
    final double? distanceKm = _number(map['distanceKm']);
    final double? price = _number(
      map['promotionalMinimumPrice'] ?? map['price'],
    );
    final String currency = map['currency']?.toString().trim() ?? '';
    if (hotelId.isEmpty ||
        hotelName.isEmpty ||
        latitude == null ||
        longitude == null ||
        !_validLatitude(latitude) ||
        !_validLongitude(longitude) ||
        distanceKm == null ||
        distanceKm < 0 ||
        price == null ||
        price <= 0 ||
        currency.isEmpty) {
      return null;
    }
    return PromotionalStay(
      hotelId: hotelId,
      hotelName: hotelName,
      city: map['city']?.toString().trim() ?? '',
      country: map['country']?.toString().trim() ?? '',
      image: map['image']?.toString().trim(),
      latitude: latitude,
      longitude: longitude,
      distanceKm: distanceKm,
      rating: _number(map['rating']),
      reviewCount: _integer(map['reviewCount']),
      promotionalMinimumPrice: price,
      currency: currency,
      searchedFromDate: map['searchedFromDate']?.toString() ?? '',
      searchedToDate: map['searchedToDate']?.toString() ?? '',
      occupancy: _integer(map['occupancy']) ?? 2,
      nationality: map['nationality']?.toString() ?? 'EG',
      provider: map['provider']?.toString() ?? 'nuitee',
      fetchedAt:
          DateTime.tryParse(map['fetchedAt']?.toString() ?? '') ??
          DateTime.now().toUtc(),
      locationConfidence: map['locationConfidence']?.toString() ?? 'medium',
    );
  }

  static PromotionalStay fromMap(Map<String, dynamic> map) {
    final PromotionalStay? parsed = tryParse(map);
    if (parsed == null) {
      throw const FormatException('Invalid promotional stay payload');
    }
    return parsed;
  }

  static double? _number(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  static int? _integer(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static bool _validLatitude(double value) => value >= -90 && value <= 90;
  static bool _validLongitude(double value) => value >= -180 && value <= 180;
}

/// The `GET /home/nearby-stays` response.
@immutable
class NearbyStaysResponse {
  const NearbyStaysResponse({
    required this.stays,
    required this.radiusKm,
    required this.locationConfidence,
    required this.locationSource,
    required this.locationRequired,
    required this.currency,
    required this.occupancy,
    required this.nationality,
    required this.rankingVersion,
    required this.partialFailure,
    required this.fetchedAt,
    this.reason,
    this.searchedFromDate,
    this.searchedToDate,
  });

  final List<PromotionalStay> stays;
  final double radiusKm;
  final String? locationConfidence;
  final String? locationSource;
  final bool locationRequired;
  final String? reason;
  final String? searchedFromDate;
  final String? searchedToDate;
  final String currency;
  final int occupancy;
  final String nationality;
  final String rankingVersion;
  final bool partialFailure;
  final DateTime fetchedAt;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'stays': stays.map((PromotionalStay stay) => stay.toMap()).toList(),
    'radiusKm': radiusKm,
    'locationConfidence': locationConfidence,
    'locationSource': locationSource,
    'locationRequired': locationRequired,
    'reason': reason,
    'searchedFromDate': searchedFromDate,
    'searchedToDate': searchedToDate,
    'currency': currency,
    'occupancy': occupancy,
    'nationality': nationality,
    'rankingVersion': rankingVersion,
    'partialFailure': partialFailure,
    'fetchedAt': fetchedAt.toIso8601String(),
  };

  static NearbyStaysResponse? tryParse(Map<String, dynamic> map) {
    final rawStays = map['stays'];
    if (rawStays is! List) return null;
    final List<PromotionalStay> stays = <PromotionalStay>[];
    for (final Object? raw in rawStays) {
      if (raw is! Map) continue;
      final PromotionalStay? stay = PromotionalStay.tryParse(
        Map<String, dynamic>.from(
          raw.map((Object? k, Object? v) => MapEntry(k.toString(), v)),
        ),
      );
      if (stay != null) stays.add(stay);
    }
    final double? radiusKm = PromotionalStay._number(map['radiusKm']);
    if (radiusKm == null) return null;
    return NearbyStaysResponse(
      stays: stays,
      radiusKm: radiusKm,
      locationConfidence: map['locationConfidence']?.toString(),
      locationSource: map['locationSource']?.toString(),
      locationRequired: map['locationRequired'] == true,
      reason: map['reason']?.toString(),
      searchedFromDate: map['searchedFromDate']?.toString(),
      searchedToDate: map['searchedToDate']?.toString(),
      currency: map['currency']?.toString() ?? 'USD',
      occupancy: PromotionalStay._integer(map['occupancy']) ?? 2,
      nationality: map['nationality']?.toString() ?? 'EG',
      rankingVersion: map['rankingVersion']?.toString() ?? '',
      partialFailure: map['partialFailure'] == true,
      fetchedAt:
          DateTime.tryParse(map['fetchedAt']?.toString() ?? '') ??
          DateTime.now().toUtc(),
    );
  }
}
