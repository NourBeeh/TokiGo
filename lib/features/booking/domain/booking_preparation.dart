class BookingRequest {
  final String offerId;
  final String providerId;
  final String searchId;
  final Map<String, dynamic> params;

  const BookingRequest({
    required this.offerId,
    required this.providerId,
    required this.searchId,
    this.params = const {},
  });
}

class PriceRevalidationResult {
  final double authoritativePrice;
  final double? oldPrice;
  final String currency;
  final bool priceChanged;
  final bool available;
  final String? providerId;
  final String? offerId;
  final String? reason;
  final DateTime? expiresAt;

  const PriceRevalidationResult({
    required this.authoritativePrice,
    this.oldPrice,
    required this.currency,
    required this.priceChanged,
    required this.available,
    this.providerId,
    this.offerId,
    this.reason,
    this.expiresAt,
  });
}

class BookingPreparation {
  final BookingRequest request;
  final PriceRevalidationResult revalidation;

  const BookingPreparation({required this.request, required this.revalidation});
}
