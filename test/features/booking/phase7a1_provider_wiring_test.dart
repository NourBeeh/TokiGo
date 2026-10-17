import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tokigo/features/booking/application/booking_providers.dart';
import 'package:tokigo/features/booking/application/booking_controller.dart';
import 'package:tokigo/features/booking/application/booking_state.dart';
import 'package:tokigo/features/booking/application/prepare_booking_usecase.dart';
import 'package:tokigo/features/booking/application/revalidate_booking_usecase.dart';
import 'package:tokigo/core/repositories/booking_repository_impl.dart';


void main() {
  test('provider graph creates BookingController without UnimplementedError', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(bookingControllerProvider.notifier);
    expect(controller, isA<BookingController>());
    expect(container.read(bookingControllerProvider).phase, BookingPhase.idle);
  });

  test('bookingRepositoryProvider returns BookingRepositoryImpl', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final repo = container.read(bookingRepositoryProvider);
    expect(repo, isA<BookingRepositoryImpl>());
  });

  test('use cases are wired with repository', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final prepare = container.read(prepareBookingUseCaseProvider);
    final revalidate = container.read(revalidateBookingUseCaseProvider);
    expect(prepare, isA<PrepareBookingUseCase>());
    expect(revalidate, isA<RevalidateBookingUseCase>());
  });
}
