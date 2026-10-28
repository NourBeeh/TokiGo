import 'package:flutter/foundation.dart';
import 'base_offer.dart';

@immutable
class TravelPackageOffer extends BaseOffer {
  const TravelPackageOffer({
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
    required this.destination,
    required this.durationDays,
    required this.inclusions,
  });

  final String destination;
  final int durationDays;
  final List<String> inclusions;

  @override
  String get offerType => 'package';
}
