import 'package:flutter/foundation.dart';
import 'base_offer.dart';

@immutable
class FlightOffer extends BaseOffer {
  const FlightOffer({
    required super.id,
    required super.providerId,
    required super.providerName,
    required super.title,
    super.subtitle,
    super.description,
    super.imageUrl,
    required super.price,
    required super.currency,
    super.availability,
    super.validUntil,
    super.metadata,
    super.rating,
    super.reviewCount,
    super.customerPrice,
    required this.origin,
    required this.destination,
    required this.departureTime,
    required this.arrivalTime,
    required this.airline,
    required this.flightNumber,
    this.stops,
    this.cabinClass,
  });

  final String origin;
  final String destination;
  final DateTime departureTime;
  final DateTime arrivalTime;
  final String airline;
  final String flightNumber;
  final int? stops;
  final String? cabinClass;

  @override
  String get offerType => 'flight';
}
