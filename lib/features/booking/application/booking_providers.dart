import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tokigo/core/network/http_api_client.dart';
import 'package:tokigo/core/repositories/booking_repository_impl.dart';
import 'package:tokigo/features/booking/application/booking_state.dart';
import 'package:tokigo/features/booking/application/prepare_booking_usecase.dart';
import 'package:tokigo/features/booking/application/revalidate_booking_usecase.dart';
import 'package:tokigo/features/booking/application/confirm_booking_usecase.dart';
import 'package:tokigo/features/booking/application/booking_controller.dart';
import 'package:tokigo/features/bag/application/bag_controller.dart';

final apiClientProvider = Provider((ref) => HttpApiClient());

final bookingRepositoryProvider = Provider((ref) {
  final client = ref.watch(apiClientProvider);
  return BookingRepositoryImpl(client);
});

final prepareBookingUseCaseProvider = Provider((ref) {
  final repo = ref.watch(bookingRepositoryProvider);
  return PrepareBookingUseCase(repo);
});

final revalidateBookingUseCaseProvider = Provider((ref) {
  final repo = ref.watch(bookingRepositoryProvider);
  return RevalidateBookingUseCase(repo);
});

final confirmBookingUseCaseProvider = Provider((ref) {
  final repo = ref.watch(bookingRepositoryProvider);
  return ConfirmBookingUseCase(repo);
});

final bookingControllerProvider = StateNotifierProvider<BookingController, BookingState>((ref) {
  final prepare = ref.watch(prepareBookingUseCaseProvider);
  final revalidate = ref.watch(revalidateBookingUseCaseProvider);
  final confirm = ref.watch(confirmBookingUseCaseProvider);
  final bag = ref.watch(bagControllerProvider.notifier);
  return BookingController(prepareUseCase: prepare, revalidateUseCase: revalidate, confirmUseCase: confirm, bagController: bag);
});