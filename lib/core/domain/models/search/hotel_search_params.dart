import 'package:flutter/foundation.dart';

/// The search form's full request contract. Context fields are informational
/// except for country and market.
@immutable
class HotelSearchParams {
  final String destination;
  final DateTime checkIn;
  final DateTime checkOut;
  final int rooms;
  final int adults;
  final int children;
  final double? minRating;
  final double? maxPrice;
  final double? minPrice;
  final List<String> amenities;
  final String? countryCode;
  final String? market;

  const HotelSearchParams({
    required this.destination,
    required this.checkIn,
    required this.checkOut,
    this.rooms = 1,
    this.adults = 2,
    this.children = 0,
    this.minRating,
    this.maxPrice,
    this.minPrice,
    this.amenities = const [],
    this.countryCode,
    this.market,
  });
}
