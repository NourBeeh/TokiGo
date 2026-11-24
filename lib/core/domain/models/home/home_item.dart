import 'package:flutter/foundation.dart';

import '../offers/customer_price.dart';
import 'home_types.dart';

/// One card in a Home/Explore section.
///
/// The old per-item price-verification state (`priceVerified` /
/// `priceUnverified` and their failure categories) is gone: Home no longer
/// runs a live-validation pass. Promotional Nearby prices are labelled as
/// discovery prices by the card, and live booking prices come from a fresh
/// provider search.
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

  /// True when this item carries a provider-sourced travel price at all.
  ///
  /// Deliberately narrow: a price, the backend's converted customer quote, or a
  /// positive raw price. Ratings, review counts, distances, durations, seat
  /// counts, star classes and other descriptive numbers are NOT prices.
  bool get hasTravelPrice =>
      price != null ||
      customerPrice != null ||
      (rawPrice != null && rawPrice! > 0);

  HomeItem copyWith({
    String? id,
    HomeCardType? type,
    String? title,
    String? subtitle,
    String? description,
    String? imageUrl,
    double? price,
    String? currency,
    CustomerPrice? customerPrice,
    double? rating,
    int? reviewCount,
    String? badge,
    List<String>? highlights,
    List<String>? tags,
    String? actionLabel,
    double? rawPrice,
    Map<String, dynamic>? metadata,
  }) {
    return HomeItem(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      customerPrice: customerPrice ?? this.customerPrice,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      badge: badge ?? this.badge,
      highlights: highlights ?? this.highlights,
      tags: tags ?? this.tags,
      actionLabel: actionLabel ?? this.actionLabel,
      rawPrice: rawPrice ?? this.rawPrice,
      metadata: metadata ?? this.metadata,
    );
  }
}
