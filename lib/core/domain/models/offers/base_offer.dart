import 'package:flutter/foundation.dart';

import 'customer_price.dart';

/// Base normalized offer fields shared across all travel products.
/// Concrete offers extend this with product-specific data.
@immutable
abstract class BaseOffer {
  const BaseOffer({
    required this.id,
    required this.providerId,
    required this.providerName,
    required this.title,
    this.subtitle,
    this.description,
    this.imageUrl,
    required this.price,
    required this.currency,
    this.availability,
    this.validUntil,
    this.metadata = const {},
    this.rating,
    this.reviewCount,
    this.customerPrice,
  });

  final String id;
  final String providerId;
  final String providerName;
  final String title;
  final String? subtitle;
  final String? description;
  final String? imageUrl;
  final double price;
  final String currency;
  final bool? availability;
  final DateTime? validUntil;
  final Map<String, dynamic> metadata;
  final double? rating;
  final int? reviewCount;

  /// Backend-quoted customer display price (spec point 5): provider amount
  /// stays in [price]/[currency]; this carries the converted EGP total with
  /// its FX snapshot and breakdown.
  final CustomerPrice? customerPrice;

  /// Normalized identifier for UI rendering.
  String get offerType;
}
