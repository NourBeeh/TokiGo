import 'package:flutter/foundation.dart';
import 'base_offer.dart';

@immutable
class CarOffer extends BaseOffer {
  const CarOffer({
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
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.pickupTime,
    required this.dropoffTime,
    required this.carType,
    this.transmission,
    this.seats,
  });

  final String pickupLocation;
  final String dropoffLocation;
  final DateTime pickupTime;
  final DateTime dropoffTime;
  final String carType;
  final String? transmission;
  final int? seats;

  @override
  String get offerType => 'car';
}
