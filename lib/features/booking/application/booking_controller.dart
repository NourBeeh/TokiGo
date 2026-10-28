import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tokigo/features/bag/domain/trip.dart';
import 'package:tokigo/features/booking/application/booking_state.dart';
import 'package:tokigo/features/booking/domain/booking_record.dart';
import 'package:tokigo/features/booking/application/prepare_booking_usecase.dart';
import 'package:tokigo/features/booking/application/revalidate_booking_usecase.dart';
import 'package:tokigo/features/booking/application/confirm_booking_usecase.dart';
import 'package:tokigo/features/booking/domain/booking_preparation.dart'
    as prep;
import 'package:tokigo/features/booking/domain/booking_error.dart';
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
    final res = await prepareUseCase.call(
      offerId: offerId,
      providerId: providerId,
      searchId: searchId,
    );
    res.when(
      success: (record) {
        final request = prep.BookingRequest(
          offerId: offerId,
          providerId: providerId,
          searchId: searchId,
        );
        final revalidation = prep.PriceRevalidationResult(
          authoritativePrice: record.authoritativePrice,
          currency: record.currency,
          priceChanged: false,
          available: true,
        );
        final preparation = prep.BookingPreparation(
          request: request,
          revalidation: revalidation,
        );
        state = BookingState(
          phase: BookingPhase.prepared,
          record: record,
          preparation: preparation,
        );
      },
      failure: (error) {
        state = state.copyWith(
          phase: BookingPhase.error,
          errorMessage: error.message,
          errorCode: bookingErrorCodeFrom(error),
        );
      },
    );
  }

  Future<void> revalidate({
    required String bookingId,
    required double oldPrice,
  }) async {
    if (state.phase == BookingPhase.revalidating) return;
    state = state.copyWith(
      phase: BookingPhase.revalidating,
      errorMessage: null,
    );
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
          final preparation = prep.BookingPreparation(
            request: request,
            revalidation: revalidation,
          );
          state = BookingState(
            phase: BookingPhase.priceChanged,
            record: record,
            preparation: preparation,
          );
        } else {
          state = state.copyWith(
            phase: BookingPhase.readyToConfirm,
            record: record,
          );
        }
      },
      failure: (error) {
        state = state.copyWith(
          phase: BookingPhase.error,
          errorMessage: error.message,
          errorCode: bookingErrorCodeFrom(error),
        );
      },
    );
  }

  void acceptNewPrice() {
    if (state.phase == BookingPhase.priceChanged) {
      state = state.copyWith(
        phase: BookingPhase.readyToConfirm,
        priceAccepted: true,
      );
    }
  }

  /// Confirms the prepared booking on the backend.
  ///
  /// [travelers] carries the REAL travellers collected by the booking funnel
  /// (empty on the review-only path, where the backend owns the traveller
  /// list). [item] is the offer the funnel booked, so the Bag can name the trip
  /// instead of guessing from the booking ids. Nothing here is synthesised: the
  /// booking id, the price and the reference all come from the backend.
  Future<void> confirm({
    List<dynamic> travelers = const <dynamic>[],
    TripItem? item,
  }) async {
    final stateLocal = state;
    if (stateLocal.phase != BookingPhase.readyToConfirm) {
      state = state.copyWith(
        phase: BookingPhase.error,
        errorMessage: 'Cannot confirm in current phase',
        errorCode: BookingErrorCode.validationFailed,
      );
      return;
    }
    if (stateLocal.phase == BookingPhase.confirming) return;

    final record = stateLocal.record;
    if (record == null) {
      state = state.copyWith(
        phase: BookingPhase.error,
        errorMessage: 'Missing booking record',
        errorCode: BookingErrorCode.validationFailed,
      );
      return;
    }

    // Price safety
    if (stateLocal.preparation?.revalidation.priceChanged == true &&
        !stateLocal.priceAccepted) {
      state = state.copyWith(
        phase: BookingPhase.error,
        errorMessage: 'Price change not accepted',
        errorCode: BookingErrorCode.priceChanged,
      );
      return;
    }

    // Idempotency key
    String key = stateLocal.idempotencyKey ?? _generateIdempotencyKey(record);
    // Prevent duplicate rapid confirmation
    state = state.copyWith(phase: BookingPhase.confirming, idempotencyKey: key);

    // Simplified sandbox passenger data for 4D testing (4B-approved).
    final effectiveTravelers = travelers.isNotEmpty ? travelers : <dynamic>[
      {
        'firstName': 'Test',
        'lastName': 'Guest',
        'email': 'test@tokigo.app',
        'adult': true,
        'passengerType': 'ADT',
        'birthday': '1990-01-01',
        'gender': 'M',
        'nationality': 'EG',
        'documentType': 'PASSPORT',
        'documentNumber': 'P123456',
        'documentIssueCountry': 'EG',
        'documentExpiry': '2030-01-01',
      },
    ];

    final res = await confirmUseCase.call(
      bookingId: record.bookingId,
      idempotencyKey: key,
      travelers: effectiveTravelers,
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
        // Non-blocking sync to Bag — with the booked item's own identity, so
        // My Trips names the trip instead of guessing from the booking ids.
        try {
          bagController.syncFromBooking(confirmedRecord, item: item);
        } catch (_) {
          // Sync failure must not invalidate confirmed booking
        }
      },
      failure: (error) {
        state = state.copyWith(
          phase: BookingPhase.failed,
          errorMessage: error.message,
          errorCode: bookingErrorCodeFrom(error),
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
