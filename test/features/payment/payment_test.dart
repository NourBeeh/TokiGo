import 'package:flutter_test/flutter_test.dart';
import 'package:tokigo/features/payment/domain/payment.dart';

void main() {
  test('payment session creation', () {
    final session = PaymentSession(
      id: 'p1',
      bookingId: 'b1',
      amount: 100,
      currency: 'USD',
      status: PaymentStatus.created,
    );
    expect(session.status, PaymentStatus.created);
  });
}
