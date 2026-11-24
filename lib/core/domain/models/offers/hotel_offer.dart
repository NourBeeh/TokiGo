import 'package:flutter/foundation.dart';
import 'base_offer.dart';

@immutable
class HotelOffer extends BaseOffer {
  const HotelOffer({
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
    required this.city,
    required this.country,
    this.checkIn,
    this.checkOut,
    required this.roomType,
    this.amenities = const [],
    this.offers = const <HotelOffer>[],
  });

  final String city;
  final String country;

  /// The provider's own dates. Null when the payload did not state them — a
  /// missing date is never replaced with "today".
  final DateTime? checkIn;
  final DateTime? checkOut;
  final String roomType;
  final List<String> amenities;

  /// Every valid room-type offer the provider returned for this hotel, cheapest
  /// first. The offer's own fields are the cheapest one; this list powers the
  /// details page's room/board/price/cancellation selector. It is never empty
  /// for a live hotel offer (the backend groups at least one valid offer).
  final List<HotelOffer> offers;

  /// What the details selector should list: the grouped offers when present,
  /// otherwise this offer alone (older cached payloads / other providers).
  List<HotelOffer> get selectableOffers =>
      offers.isEmpty ? <HotelOffer>[this] : offers;

  /// The hotel's own star classification (1–5) as the provider reports it.
  /// This is the hotel class, NOT the guest review score ([rating]).
  int? get starClass {
    final stars = metadata['stars'];
    return stars is num ? stars.toInt() : null;
  }

  /// Provider meal-plan text (e.g. "Room Only", "Breakfast included").
  String? get boardName => _metaString('boardName');

  /// Provider meal-plan code (e.g. "RO", "BB").
  String? get boardType => _metaString('boardType');

  /// Tri-state refundability: true/false when the provider tagged the rates,
  /// null when it sent no tag (never assumed non-refundable).
  bool? get refundable {
    final value = metadata['refundable'];
    return value is bool ? value : null;
  }

  /// The provider's own cancellation window, verbatim, when it sent one.
  Map<String, dynamic>? get cancellationPolicy {
    final value = metadata['cancellationPolicy'];
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  DateTime? get freeCancellationUntil =>
      _parseDate(cancellationPolicy?['refundableUntil']);

  double? get cancellationFee {
    final value = cancellationPolicy?['feeAmount'];
    return value is num ? value.toDouble() : null;
  }

  String? get cancellationFeeCurrency =>
      cancellationPolicy?['feeCurrency']?.toString();

  /// Number of rooms this offer covers, as reported by the provider.
  int? get roomCount {
    final occupancy = metadata['occupancy'];
    if (occupancy is Map && occupancy['rooms'] is num) {
      return (occupancy['rooms'] as num).toInt();
    }
    return null;
  }

  String? _metaString(String key) {
    final value = metadata[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return null;
  }

  static DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  @override
  String get offerType => 'hotel';
}
