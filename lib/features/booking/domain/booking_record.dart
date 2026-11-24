import 'package:flutter/foundation.dart';
import 'package:tokigo/core/domain/models/booking/booking.dart';
import 'package:tokigo/features/booking/domain/price_change.dart';

@immutable
class BookingRecord {
  final String bookingId;
  final String userId;
  final String? searchId;
  final String offerId;
  final String providerId;
  final String providerName;
  final String type;
  final BookingStatus status;
  final String currency;
  final double authoritativePrice;
  final PriceBreakdown priceBreakdown;
  final List<Passenger> travelers;
  final String bookingReference;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? expiration;
  final Map<String, dynamic> metadata;

  /// Backend-owned price/terms confirmation state. Null for responses that do
  /// not carry one (legacy records); never synthesized on the client.
  final PriceChangeConfirmation? priceChange;

  const BookingRecord({
    required this.bookingId,
    required this.userId,
    this.searchId,
    required this.offerId,
    required this.providerId,
    required this.providerName,
    required this.type,
    required this.status,
    required this.currency,
    required this.authoritativePrice,
    required this.priceBreakdown,
    required this.travelers,
    required this.bookingReference,
    required this.createdAt,
    required this.updatedAt,
    this.expiration,
    this.metadata = const {},
    this.priceChange,
  });

  BookingRecord copyWith({
    BookingStatus? status,
    String? currency,
    double? authoritativePrice,
    DateTime? expiration,
    PriceChangeConfirmation? priceChange,
  }) {
    return BookingRecord(
      bookingId: bookingId,
      userId: userId,
      searchId: searchId,
      offerId: offerId,
      providerId: providerId,
      providerName: providerName,
      type: type,
      status: status ?? this.status,
      currency: currency ?? this.currency,
      authoritativePrice: authoritativePrice ?? this.authoritativePrice,
      priceBreakdown: priceBreakdown,
      travelers: travelers,
      bookingReference: bookingReference,
      createdAt: createdAt,
      updatedAt: updatedAt,
      expiration: expiration ?? this.expiration,
      metadata: metadata,
      priceChange: priceChange ?? this.priceChange,
    );
  }
}
