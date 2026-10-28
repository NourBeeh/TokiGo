import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tokigo/core/domain/models/offers/base_offer.dart';
import 'package:tokigo/core/domain/models/offers/car_offer.dart';
import 'package:tokigo/core/domain/models/offers/flight_offer.dart';
import 'package:tokigo/core/domain/models/offers/hotel_offer.dart';

/// The offer the booking funnel is working on.
///
/// Beyond the base hand-off fields (what `prepare` needs), it carries the
/// booked item's own identity — name, sub-line, photo and its own dates — so a
/// later screen (the confirmation) can show **what** was booked instead of a
/// card it invents. Every field is optional: hand-offs that only know the base
/// fields (Home/AI cards) simply leave them empty, and the receiving screen
/// shows less rather than something made up.
class SelectedOffer {
  final String offerId;
  final String providerId;
  final String providerName;
  final double price;
  final String currency;
  final String searchId;
  final String offerType;
  final Map<String, dynamic> metadata;

  /// The offer's own title as the provider/search named it.
  final String? title;

  /// The offer's own sub-line (place, route, car class…).
  final String? subtitle;

  /// The offer's own photo. Absent for verticals without photography.
  final String? imageUrl;

  /// The offer's own start/end (check-in/out, departure/arrival, pickup/drop-off).
  final DateTime? startsAt;
  final DateTime? endsAt;

  const SelectedOffer({
    required this.offerId,
    required this.providerId,
    required this.providerName,
    required this.price,
    required this.currency,
    required this.searchId,
    required this.offerType,
    this.metadata = const {},
    this.title,
    this.subtitle,
    this.imageUrl,
    this.startsAt,
    this.endsAt,
  });

  /// US-6 — the single booking hand-off used by the Universal Search results
  /// product tap: every normalized offer already exposes the base fields, so
  /// no per-vertical duplication is needed.
  factory SelectedOffer.fromOffer(BaseOffer offer) {
    final (DateTime? startsAt, DateTime? endsAt) = switch (offer) {
      HotelOffer o => (o.checkIn, o.checkOut),
      FlightOffer o => (o.departureTime, o.arrivalTime),
      CarOffer o => (o.pickupTime, o.dropoffTime),
      _ => (null, null),
    };
    return SelectedOffer(
      offerId: offer.id,
      providerId: offer.providerId,
      providerName: offer.providerName,
      price: offer.price,
      currency: offer.currency,
      searchId: '',
      offerType: offer.offerType,
      metadata: offer.metadata,
      title: offer.title,
      subtitle: offer.subtitle,
      imageUrl: offer.imageUrl,
      startsAt: startsAt,
      endsAt: endsAt,
    );
  }
}

final selectedOfferProvider = StateProvider<SelectedOffer?>((ref) => null);
