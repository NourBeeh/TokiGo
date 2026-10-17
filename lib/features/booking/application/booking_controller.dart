import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tokigo/features/booking/application/booking_state.dart';
import 'package:tokigo/features/booking/domain/booking_record.dart';
import 'package:tokigo/features/booking/application/prepare_booking_usecase.dart';
import 'package:tokigo/features/booking/application/revalidate_booking_usecase.dart';
import 'package:tokigo/features/booking/application/confirm_booking_usecase.dart';
import 'package:tokigo/features/booking/domain/booking_preparation.dart' as prep;
import 'package:tokigo/features/bag/application/bag_controller.dart';

class BookingController extends StateNotifier<BookingState> {
  final PrepareBookingUseCase prepareUseCase;
  final RevalidateBookingUseCase revalidateUseCase;
  final ConfirmBookingUseCase confirmUseCase;
  final BagController bagController;

  BookingController({
    required this.prepareUseCase,
    required this.revalidateUseCase,
    required this.confirmUseCase,
    required this.bagController,
  }) : super(BookingState.idle());

  Future<void> prepare({
    required String offerId,
    required String providerId,
    required String searchId,
  }) async {
    if (state.phase == BookingPhase.preparing) return;
    state = state.copyWith(phase: BookingPhase.preparing, errorMessage: null);
    final res = await prepareUseCase.call(offerId: offerId, providerId: providerId, searchId: searchId);
    res.when(
      success: (record) {
        final request = prep.BookingRequest(offerId: offerId, providerId: providerId, searchId: searchId);
        final revalidation = prep.PriceRevalidationResult(
          authoritativePrice: record.authoritativePrice,
          currency: record.currency,
          priceChanged: false,
          available: true,
        );
        final preparation = prep.BookingPreparation(request: request, revalidation: revalidation);
        state = BookingState(
          phase: BookingPhase.prepared,
          record: record,
          preparation: preparation,
        );
      },
      failure: (error) {
        state = state.copyWith(phase: BookingPhase.error, errorMessage: error.message);
      },
    );
  }

  Future<void> revalidate({required String bookingId, required double oldPrice}) async {
    if (state.phase == BookingPhase.revalidating) return;
    state = state.copyWith(phase: BookingPhase.revalidating, errorMessage: null);
    final res = await revalidateUseCase.call(bookingId: bookingId);
    res.when(
      success: (record) {
        final authoritativePrice = record.authoritativePrice;
        final changed = authoritativePrice != oldPrice;
        if (changed) {
          final revalidation = prep.PriceRevalidationResult(
            authoritativePrice: authoritativePrice,
            oldPrice: oldPrice,
            currency: record.currency,
            priceChanged: true,
            available: true,
            providerId: record.providerId,
            offerId: record.offerId,
          );
          final request = prep.BookingRequest(
            offerId: record.offerId,
            providerId: record.providerId,
            searchId: record.searchId ?? '',
          );
          final preparation = prep.BookingPreparation(request: request, revalidation: revalidation);
          state = BookingState(
            phase: BookingPhase.priceChanged,
            record: record,
            preparation: preparation,
          );
        } else {
          state = state.copyWith(phase: BookingPhase.readyToConfirm, record: record);
        }
      },
      failure: (error) {
        state = state.copyWith(phase: BookingPhase.error, errorMessage: error.message);
      },
    );
  }

  void acceptNewPrice() {
    if (state.phase == BookingPhase.priceChanged) {
      state = state.copyWith(phase: BookingPhase.readyToConfirm, priceAccepted: true);
    }
  }

  Future<void> confirm() async {
    final stateLocal = state;
    if (stateLocal.phase != BookingPhase.readyToConfirm) {
      state = state.copyWith(phase: BookingPhase.error, errorMessage: 'Cannot confirm in current phase');
      return;
    }
    if (stateLocal.phase == BookingPhase.confirming) return;

    final record = stateLocal.record;
    if (record == null) {
      state = state.copyWith(phase: BookingPhase.error, errorMessage: 'Missing booking record');
      return;
    }

    // Price safety
    if (stateLocal.preparation?.revalidation.priceChanged == true && !stateLocal.priceAccepted) {
      state = state.copyWith(phase: BookingPhase.error, errorMessage: 'Price change not accepted');
      return;
    }

    // Idempotency key
    String key = stateLocal.idempotencyKey ?? _generateIdempotencyKey(record);
    // Prevent duplicate rapid confirmation
    state = state.copyWith(phase: BookingPhase.confirming, idempotencyKey: key);

    final travelers = <dynamic>[]; // Placeholder; real travelers from preparation if needed
    final res = await confirmUseCase.call(
      offerId: record.offerId,
      providerId: record.providerId,
      idempotencyKey: key,
      travelers: travelers,
    );

    res.when(
      success: (confirmedRecord) {
        state = BookingState(
          phase: BookingPhase.confirmed,
          record: confirmedRecord,
          preparation: stateLocal.preparation,
          priceAccepted: stateLocal.priceAccepted,
          idempotencyKey: key,
        );
        // Non-blocking sync to Bag
        try {
          bagController.syncFromBooking(confirmedRecord);
        } catch (_) {
          // Sync failure must not invalidate confirmed booking
        }
      },
      failure: (error) {
        state = state.copyWith(
          phase: BookingPhase.failed,
          errorMessage: error.message,
        );
      },
    );
  }

  String _generateIdempotencyKey(BookingRecord record) {
    // Deterministic key per logical booking attempt
    return 'confirm-${record.offerId}-${record.providerId}-${record.searchId ?? ''}';
  }

  void reset() {
    state = BookingState.idle();
  }
}

// Provider definition moved to booking_providers.dart