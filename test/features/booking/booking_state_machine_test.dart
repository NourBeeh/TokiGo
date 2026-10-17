import 'package:flutter_test/flutter_test.dart';
import 'package:tokigo/features/booking/application/booking_state_machine.dart';

void main() {
  test('valid transitions', () {
    expect(BookingStateMachine.canTransition(ExtendedBookingStatus.draft, ExtendedBookingStatus.pending), true);
    expect(BookingStateMachine.canTransition(ExtendedBookingStatus.pending, ExtendedBookingStatus.revalidating), true);
    expect(BookingStateMachine.canTransition(ExtendedBookingStatus.revalidating, ExtendedBookingStatus.awaitingPayment), true);
    expect(BookingStateMachine.canTransition(ExtendedBookingStatus.awaitingPayment, ExtendedBookingStatus.paymentProcessing), true);
    expect(BookingStateMachine.canTransition(ExtendedBookingStatus.paymentProcessing, ExtendedBookingStatus.paid), true);
    expect(BookingStateMachine.canTransition(ExtendedBookingStatus.paid, ExtendedBookingStatus.confirming), true);
    expect(BookingStateMachine.canTransition(ExtendedBookingStatus.confirming, ExtendedBookingStatus.confirmed), true);
  });

  test('invalid transitions', () {
    expect(BookingStateMachine.canTransition(ExtendedBookingStatus.confirmed, ExtendedBookingStatus.pending), false);
    expect(BookingStateMachine.canTransition(ExtendedBookingStatus.failed, ExtendedBookingStatus.confirmed), false);
  });
}
