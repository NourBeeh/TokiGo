import 'package:flutter/foundation.dart';

enum BookingStatus { draft, pending, confirmed, cancelled, failed }

@immutable
class PriceBreakdown {
  final double basePrice;
  final double taxes;
  final double fees;
  final String currency;

  const PriceBreakdown({
    required this.basePrice,
    required this.taxes,
    required this.fees,
    required this.currency,
  });

  double get total => basePrice + taxes + fees;

  static const empty = PriceBreakdown(
    basePrice: 0,
    taxes: 0,
    fees: 0,
    currency: 'USD',
  );
}

@immutable
class Passenger {
  final String firstName;
  final String lastName;
  final String? email;
  final String? phone;

  const Passenger({
    required this.firstName,
    required this.lastName,
    this.email,
    this.phone,
  });
}

@immutable
class BookingItem {
  final String providerId;
  final String providerName;
  final String offerId;
  final String offerType;
  final dynamic offerData;
  final PriceBreakdown priceBreakdown;
  final String searchId;

  const BookingItem({
    required this.providerId,
    required this.providerName,
    required this.offerId,
    required this.offerType,
    required this.offerData,
    required this.priceBreakdown,
    required this.searchId,
  });
}

@immutable
class Booking {
  final String id;
  final BookingStatus status;
  final List<BookingItem> items;
  final List<Passenger> passengers;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Booking({
    required this.id,
    required this.status,
    required this.items,
    required this.passengers,
    required this.createdAt,
    this.updatedAt,
  });
}
