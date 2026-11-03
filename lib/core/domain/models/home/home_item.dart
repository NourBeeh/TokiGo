import 'package:flutter/foundation.dart';
import '../offers/customer_price.dart';
import 'home_types.dart';

@immutable
class HomeItem {
  const HomeItem({
    required this.id,
    required this.type,
    required this.title,
    this.subtitle,
    this.description,
    this.imageUrl,
    this.price,
    this.currency,
    /// Backend-quoted display price (market/currency converted). The card shows
    /// this when present; [price]/[currency] stay the provider's own figures.
    this.customerPrice,
    this.rating,
    this.reviewCount,
    this.badge,
    this.highlights = const [],
    this.tags = const [],
    this.actionLabel,
    this.rawPrice,
    this.metadata = const {},
  });

  final String id;
  final HomeCardType type;
  final String title;
  final String? subtitle;
  final String? description;
  final String? imageUrl;
  final double? price;
  final String? currency;
  final CustomerPrice? customerPrice;
  final double? rating;
  final int? reviewCount;
  final String? badge;
  final List<String> highlights;
  final List<String> tags;
  final String? actionLabel;
  final double? rawPrice;
  final Map<String, dynamic> metadata;
}
