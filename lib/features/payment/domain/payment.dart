enum PaymentStatus {
  created,
  requiresAction,
  processing,
  succeeded,
  failed,
  cancelled,
  expired,
}

class PaymentSession {
  final String id;
  final String bookingId;
  final double amount;
  final String currency;
  final PaymentStatus status;
  final String? clientSecret;

  const PaymentSession({
    required this.id,
    required this.bookingId,
    required this.amount,
    required this.currency,
    required this.status,
    this.clientSecret,
  });
}

class PaymentError {
  final String code;
  final String message;
  const PaymentError(this.code, this.message);
}
