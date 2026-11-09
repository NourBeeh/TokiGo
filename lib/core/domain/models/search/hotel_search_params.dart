import 'package:flutter/foundation.dart';

import 'package:tokigo/core/domain/models/search/hotel_room_occupancy.dart';

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
  final List<HotelRoomOccupancy> occupancies;
  final double? minRating;
  final double? maxPrice;
  final double? minPrice;
  final List<String> amenities;
  final String? countryCode;
  final String? market;
  final String? currency;
  final String languageCode;

  const HotelSearchParams({
    required this.destination,
    required this.checkIn,
    required this.checkOut,
    this.rooms = 1,
    this.adults = 2,
    this.children = 0,
    this.occupancies = const <HotelRoomOccupancy>[],
    this.minRating,
    this.maxPrice,
    this.minPrice,
    this.amenities = const [],
    this.countryCode,
    this.market,
    this.currency,
    this.languageCode = 'en',
  });
}
