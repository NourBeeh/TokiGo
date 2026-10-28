import 'package:flutter/foundation.dart';

/// One leg of a flight itinerary: where it leaves from, where it lands and
/// when.
///
/// A one-way trip has one leg, a round trip has one leg plus a return date,
/// and a **multi-city** trip has a list of them (owner decision, 2026-10-20).
@immutable
class FlightSearchLeg {
  const FlightSearchLeg({
    required this.origin,
    required this.destination,
    required this.date,
  });

  final String origin;
  final String destination;
  final DateTime date;

  FlightSearchLeg copyWith({
    String? origin,
    String? destination,
    DateTime? date,
  }) => FlightSearchLeg(
    origin: origin ?? this.origin,
    destination: destination ?? this.destination,
    date: date ?? this.date,
  );

  @override
  bool operator ==(Object other) =>
      other is FlightSearchLeg &&
      other.origin == origin &&
      other.destination == destination &&
      other.date == date;

  @override
  int get hashCode => Object.hash(origin, destination, date);

  @override
  String toString() => 'FlightSearchLeg($origin → $destination, $date)';
}

@immutable
class FlightSearchParams {
  final String origin;
  final String destination;
  final DateTime departureDate;
  final DateTime? returnDate;
  final String tripType;
  final int adults;
  final int children;
  final int infants;
  final String cabinClass;
  final bool directOnly;

  /// The legs of a **multi-city** itinerary. Empty for a one-way or a
  /// round-trip search, where [origin]/[destination]/[departureDate] already
  /// describe the trip.
  final List<FlightSearchLeg> legs;
  final String? market;

  const FlightSearchParams({
    required this.origin,
    required this.destination,
    required this.departureDate,
    this.returnDate,
    this.tripType = 'oneway',
    this.adults = 1,
    this.children = 0,
    this.infants = 0,
    this.cabinClass = 'economy',
    this.directOnly = false,
    this.legs = const <FlightSearchLeg>[],
    this.market,
  });

  /// The itinerary as the API sees it: the explicit legs when there are any,
  /// otherwise the single leg the origin/destination/date describe.
  List<FlightSearchLeg> get effectiveLegs => legs.isNotEmpty
      ? legs
      : <FlightSearchLeg>[
          FlightSearchLeg(
            origin: origin,
            destination: destination,
            date: departureDate,
          ),
        ];

  FlightSearchParams copyWith({
    String? origin,
    String? destination,
    DateTime? departureDate,
    DateTime? returnDate,
    String? tripType,
    int? adults,
    int? children,
    int? infants,
    String? cabinClass,
    bool? directOnly,
    List<FlightSearchLeg>? legs,
    String? market,
  }) {
    return FlightSearchParams(
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      departureDate: departureDate ?? this.departureDate,
      returnDate: returnDate ?? this.returnDate,
      tripType: tripType ?? this.tripType,
      adults: adults ?? this.adults,
      children: children ?? this.children,
      infants: infants ?? this.infants,
      cabinClass: cabinClass ?? this.cabinClass,
      directOnly: directOnly ?? this.directOnly,
      legs: legs ?? this.legs,
      market: market ?? this.market,
    );
  }
}
