import 'package:flutter_test/flutter_test.dart';
import 'package:tokigo/features/booking/application/booking_state_machine.dart';

void main() {
  test('booking state transitions valid', () {
    expect(BookingStateMachine.canTransition(ExtendedBookingStatus.draft, ExtendedBookingStatus.pending), isTrue);
    expect(BookingStateMachine.canTransition(ExtendedBookingStatus.pending, ExtendedBookingStatus.revalidating), isTrue);
    expect(BookingStateMachine.canTransition(ExtendedBookingStatus.revalidating, ExtendedBookingStatus.awaitingPayment), isTrue);
  });

  test('booking state transitions invalid', () {
    expect(BookingStateMachine.canTransition(ExtendedBookingStatus.confirmed, ExtendedBookingStatus.pending), isFalse);
  });
}
