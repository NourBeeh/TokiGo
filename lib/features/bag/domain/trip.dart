import 'package:flutter/foundation.dart';

/// What the booking funnel really booked, reduced to the facts a trip card can
/// honestly show.
///
/// It exists so the Bag never has to reach into the search feature: the
/// checkout hands over the booked offer's own name, photo and dates, and the
/// trip keeps exactly those. Every field is optional — a booking made without
/// that context yields a trip that states fewer facts rather than invented
/// ones.
@immutable
class TripItem {
  /// The booked item's own name (hotel name, route, car class…).
  final String? title;

  /// Its own sub-line (place, route, car class…).
  final String? subtitle;

  /// Its own photo, when the provider supplied one.
  final String? imageUrl;

  /// Its own start/end (check-in/out, departure/arrival, pickup/drop-off).
  final DateTime? startsAt;
  final DateTime? endsAt;

  const TripItem({
    this.title,
    this.subtitle,
    this.imageUrl,
    this.startsAt,
    this.endsAt,
  });
}

@immutable
class TripSummary {
  final String tripId;
  final String bookingId;

  /// The booked vertical as the backend recorded it (`hotel`, `flight`, …).
  final String type;

  /// The place/route the booking carried — `''` when the booking carried none.
  final String destination;

  /// The booked item's own name, when the funnel carried it.
  final String? title;

  /// The booked item's own photo, when the provider supplied one.
  final String? imageUrl;

  /// The trip's REAL dates as the offer/booking reported them. Null when the
  /// booking carried no such dates: the Bag never derives a stay window (the
  /// old `createdAt` / `createdAt + 1 day` fallback showed dates nobody booked).
  final DateTime? startDate;
  final DateTime? endDate;

  /// `BookingStatus.name` of the confirmed booking.
  final String status;

  final double total;
  final String currency;
  final String bookingReference;
  final String providerName;

  /// How many travellers the confirmed booking carried, or null when unknown.
  final int? travelersCount;

  const TripSummary({
    required this.tripId,
    required this.bookingId,
    required this.type,
    required this.destination,
    this.title,
    this.imageUrl,
    this.startDate,
    this.endDate,
    required this.status,
    required this.total,
    required this.currency,
    required this.bookingReference,
    required this.providerName,
    this.travelersCount,
  });

  /// A copy with the fields the traveller (or the backend) changed.
  TripSummary copyWith({
    String? status,
    String? bookingReference,
    DateTime? startDate,
    DateTime? endDate,
  }) => TripSummary(
    tripId: tripId,
    bookingId: bookingId,
    type: type,
    destination: destination,
    title: title,
    imageUrl: imageUrl,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    status: status ?? this.status,
    total: total,
    currency: currency,
    bookingReference: bookingReference ?? this.bookingReference,
    providerName: providerName,
    travelersCount: travelersCount,
  );
}

@immutable
class ItineraryStage {
  final String name;
  final DateTime? dateTime;
  final String status;
  final String? location;

  const ItineraryStage({
    required this.name,
    this.dateTime,
    required this.status,
    this.location,
  });
}
