import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tokigo/core/network/api_error.dart';
import 'package:tokigo/features/bag/domain/trip.dart';
import 'package:tokigo/features/booking/application/booking_state.dart';
import 'package:tokigo/features/booking/domain/booking_record.dart';
import 'package:tokigo/features/booking/application/prepare_booking_usecase.dart';
import 'package:tokigo/features/booking/application/revalidate_booking_usecase.dart';
import 'package:tokigo/features/booking/application/confirm_booking_usecase.dart';
import 'package:tokigo/features/booking/application/decide_price_change_usecase.dart';
import 'package:tokigo/features/booking/domain/booking_preparation.dart'
    as prep;
import 'package:tokigo/features/booking/domain/booking_error.dart';
import 'package:tokigo/features/booking/domain/price_change.dart';
import 'package:tokigo/features/bag/application/bag_controller.dart';

class BookingController extends StateNotifier<BookingState> {
  final PrepareBookingUseCase prepareUseCase;
  final RevalidateBookingUseCase revalidateUseCase;
  final ConfirmBookingUseCase confirmUseCase;
  final DecidePriceChangeUseCase? decidePriceChangeUseCase;
  final BagController bagController;

  BookingController({
    required this.prepareUseCase,
    required this.revalidateUseCase,
    required this.confirmUseCase,
    this.decidePriceChangeUseCase,
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
    double? oldPrice,
  }) async {
    if (state.phase == BookingPhase.revalidating) return;
    // Once the provider outcome is unknown, a revalidation would call the
    // provider again (for hotels, prebook/hold) and must not be issued. The
    // pending state can only be resolved by the admin reconciliation path,
    // never by the customer's funnel.
    if (state.phase == BookingPhase.reconciliationPending) return;
    state = BookingState(
      phase: BookingPhase.revalidating,
      record: state.record,
      preparation: state.preparation,
      priceAccepted: state.priceAccepted,
      idempotencyKey: state.idempotencyKey,
    );
    final res = await revalidateUseCase.call(bookingId: bookingId);
    res.when(
      success: (record) {
        final change = record.priceChange;
        final preparation = _preparationFor(
          record,
          change,
          fallbackOldPrice: oldPrice,
        );
        if (change != null && change.requiresAcceptance) {
          state = BookingState(
            phase: BookingPhase.priceChanged,
            record: record,
            preparation: preparation,
          );
        } else if (change?.isDeclined == true) {
          state = BookingState(
            phase: BookingPhase.priceChangeDeclined,
            record: record,
            preparation: preparation,
          );
        } else {
          state = BookingState(
            phase: BookingPhase.readyToConfirm,
            record: record,
            preparation: preparation,
            priceAccepted: change?.accepted ?? state.priceAccepted,
            idempotencyKey: state.idempotencyKey,
          );
        }
      },
      failure: (error) {
        final parsed = bookingErrorFrom(error);
        state = BookingState(
          phase: _phaseForError(parsed.code),
          record: state.record,
          preparation: state.preparation,
          errorMessage: parsed.message,
          errorCode: parsed.code,
          priceAccepted: state.priceAccepted,
          idempotencyKey: state.idempotencyKey,
        );
      },
    );
  }

  /// Explicit customer acceptance of the updated price AND terms.
  ///
  /// The backend records the acceptance against provider + offer + amount +
  /// currency + terms version. This method never mutates a local flag: the
  /// new state comes from the backend response, so a failed/raced acceptance
  /// can never unblock confirmation.
  Future<bool> acceptNewPrice() async {
    final local = state;
    final record = local.record;
    final change = record?.priceChange;
    if (local.phase != BookingPhase.priceChanged ||
        record == null ||
        change == null ||
        change.isDeclined ||
        !change.requiresAcceptance) {
      return false;
    }
    final decide = decidePriceChangeUseCase;
    if (decide == null) {
      state = BookingState(
        phase: BookingPhase.error,
        record: record,
        preparation: local.preparation,
        errorMessage: 'Price confirmation is unavailable',
        errorCode: BookingErrorCode.unknownError,
      );
      return false;
    }

    state = BookingState(
      phase: BookingPhase.revalidating,
      record: record,
      preparation: local.preparation,
      priceAccepted: local.priceAccepted,
      idempotencyKey: local.idempotencyKey,
    );
    final res = await decide.call(
      bookingId: record.bookingId,
      decision: 'accept',
      expectedPrice: change.currentPrice,
      expectedCurrency: change.currency,
      expectedTermsVersion: change.termsVersion,
    );
    var accepted = false;
    res.when(
      success: (updated) {
        accepted = true;
        state = BookingState(
          phase: BookingPhase.readyToConfirm,
          record: updated,
          preparation: local.preparation,
          priceAccepted: true,
          idempotencyKey: local.idempotencyKey,
        );
      },
      failure: (error) => _applyDecisionFailure(local, record, error),
    );
    return accepted;
  }

  /// Explicit customer refusal of the updated offer. Nothing at the changed
  /// price may be booked; the funnel returns to offer selection.
  Future<bool> declinePriceChange() async {
    final local = state;
    final record = local.record;
    final change = record?.priceChange;
    if (local.phase != BookingPhase.priceChanged ||
        record == null ||
        change == null) {
      return false;
    }
    final decide = decidePriceChangeUseCase;
    if (decide == null) return false;

    state = BookingState(
      phase: BookingPhase.revalidating,
      record: record,
      preparation: local.preparation,
      priceAccepted: local.priceAccepted,
      idempotencyKey: local.idempotencyKey,
    );
    final res = await decide.call(
      bookingId: record.bookingId,
      decision: 'decline',
      expectedPrice: change.currentPrice,
      expectedCurrency: change.currency,
      expectedTermsVersion: change.termsVersion,
    );
    var declined = false;
    res.when(
      success: (updated) {
        declined = true;
        state = BookingState(
          phase: BookingPhase.priceChangeDeclined,
          record: updated,
          preparation: local.preparation,
        );
      },
      failure: (error) => _applyDecisionFailure(local, record, error),
    );
    return declined;
  }

  /// The pre-checkout offer check found the offer gone (or expired). The
  /// funnel must NOT continue — the Continue action is blocked until a fresh
  /// revalidation succeeds.
  void markOfferUnavailable(String message) {
    state = state.copyWith(
      phase: BookingPhase.unavailable,
      errorMessage: message,
    );
  }

  /// The offer expired. Distinct from a generic failure so the traveller is
  /// told to search again rather than retry the same offerId.
  void markOfferExpired(String message) {
    state = state.copyWith(
      phase: BookingPhase.expired,
      errorMessage: message,
    );
  }

  /// The offer check itself failed (backend unreachable / provider error).
  /// Blocking is the safe default: proceeding on an unverified price would
  /// let a moved fare through silently.
  void markOfferCheckFailed(String message) {
    state = state.copyWith(
      phase: BookingPhase.error,
      errorMessage: message,
    );
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
    // A duplicate tap while the request is in flight — or after the booking is
    // already confirmed — is a NO-OP. It must never become a second submission
    // and must never overwrite a confirmed state with an error. This check has
    // to run before the generic phase guard below, which would otherwise turn
    // an in-flight/confirmed phase into a validation error.
    if (stateLocal.phase == BookingPhase.confirming) return;
    if (stateLocal.phase == BookingPhase.confirmed) return;
    // An unknown provider outcome is terminal for the customer funnel: a
    // second submit could double-book or double-charge. Return without
    // touching state so the pending-verification message stays visible.
    if (stateLocal.phase == BookingPhase.reconciliationPending) return;
    if (stateLocal.phase != BookingPhase.readyToConfirm) {
      state = state.copyWith(
        phase: BookingPhase.error,
        errorMessage: 'Cannot confirm in current phase',
        errorCode: BookingErrorCode.validationFailed,
      );
      return;
    }

    final record = stateLocal.record;
    if (record == null) {
      state = state.copyWith(
        phase: BookingPhase.error,
        errorMessage: 'Missing booking record',
        errorCode: BookingErrorCode.validationFailed,
      );
      return;
    }

    // Hotel bookings must carry the real guests collected for the selected
    // offer + occupancy. The sandbox default is never a valid substitute for
    // a hotel booking, so an empty or malformed list blocks confirmation.
    if (!_hasValidTravelers(record.type, travelers)) {
      state = state.copyWith(
        phase: BookingPhase.error,
        errorMessage: 'Hotel guest details are missing or incomplete',
        errorCode: BookingErrorCode.validationFailed,
      );
      return;
    }

    // Price/terms safety: confirmation is allowed only when the exact
    // revalidated state was accepted. The backend re-checks this again, but
    // the funnel must not even send a confirm it knows is unaccepted.
    final change = record.priceChange;
    if (change != null && change.requiresAcceptance) {
      state = BookingState(
        phase: BookingPhase.priceChanged,
        record: record,
        preparation: stateLocal.preparation,
        errorMessage: 'Price change not accepted',
        errorCode: BookingErrorCode.priceChanged,
        idempotencyKey: stateLocal.idempotencyKey,
      );
      return;
    }
    if (change?.isDeclined == true) {
      state = BookingState(
        phase: BookingPhase.priceChangeDeclined,
        record: record,
        preparation: stateLocal.preparation,
        errorMessage: 'The updated offer was declined',
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
        final parsed = bookingErrorFrom(error);
        final fresh = PriceChangeConfirmation.tryParse(
          parsed.details['priceChange'],
        );
        if (parsed.code == BookingErrorCode.priceChanged && fresh != null) {
          // A change was detected at confirm time. Never report a generic
          // failure: show the exact updated price/conditions and require a
          // new explicit acceptance before anything is booked.
          final updated = record.copyWith(
            authoritativePrice: fresh.currentPrice,
            currency: fresh.currency,
            priceChange: fresh,
          );
          state = BookingState(
            phase: BookingPhase.priceChanged,
            record: updated,
            preparation: _preparationFor(updated, fresh),
            errorMessage: parsed.message,
            errorCode: parsed.code,
          );
          return;
        }
        if (parsed.code == BookingErrorCode.bookingOutcomeUnknown) {
          // The provider did not establish either success or failure. This is
          // NOT a failed booking (which would invite a retry) and NOT a
          // confirmation. Keep the record and the exact idempotency key, block
          // re-submission, and let the admin reconciliation flow resolve it.
          state = BookingState(
            phase: BookingPhase.reconciliationPending,
            record: state.record,
            preparation: stateLocal.preparation,
            errorMessage: parsed.message,
            errorCode: parsed.code,
            priceAccepted: stateLocal.priceAccepted,
            idempotencyKey: key,
          );
          return;
        }
        state = BookingState(
          phase: BookingPhase.failed,
          record: state.record,
          preparation: stateLocal.preparation,
          errorMessage: parsed.message,
          errorCode: parsed.code,
          priceAccepted: stateLocal.priceAccepted,
          idempotencyKey: stateLocal.idempotencyKey,
        );
      },
    );
  }

  BookingPhase _phaseForError(BookingErrorCode code) {
    return switch (code) {
      BookingErrorCode.noAvailability => BookingPhase.unavailable,
      BookingErrorCode.bookingExpired ||
      BookingErrorCode.offerNotFound => BookingPhase.expired,
      BookingErrorCode.bookingOutcomeUnknown =>
        BookingPhase.reconciliationPending,
      _ => BookingPhase.error,
    };
  }

  prep.BookingPreparation _preparationFor(
    BookingRecord record,
    PriceChangeConfirmation? change, {
    double? fallbackOldPrice,
  }) {
    return prep.BookingPreparation(
      request: prep.BookingRequest(
        offerId: record.offerId,
        providerId: record.providerId,
        searchId: record.searchId ?? '',
      ),
      revalidation: prep.PriceRevalidationResult(
        authoritativePrice: change?.currentPrice ?? record.authoritativePrice,
        oldPrice: change?.previousPrice ?? fallbackOldPrice,
        currency: change?.currency ?? record.currency,
        priceChanged: change?.priceChanged ?? false,
        available: true,
        providerId: change?.providerId ?? record.providerId,
        offerId: change?.offerId ?? record.offerId,
        expiresAt: change?.expiresAt,
      ),
    );
  }

  /// A decision call can itself discover a newer change. Never collapse that
  /// into a generic error: surface the fresh summary and require a new
  /// decision bound to it.
  void _applyDecisionFailure(
    BookingState local,
    BookingRecord record,
    ApiError error,
  ) {
    final parsed = bookingErrorFrom(error);
    final fresh = PriceChangeConfirmation.tryParse(
      parsed.details['priceChange'],
    );
    if (fresh != null) {
      final updated = record.copyWith(
        authoritativePrice: fresh.currentPrice,
        currency: fresh.currency,
        priceChange: fresh,
      );
      state = BookingState(
        phase: fresh.isDeclined
            ? BookingPhase.priceChangeDeclined
            : BookingPhase.priceChanged,
        record: updated,
        preparation: _preparationFor(updated, fresh),
        errorMessage: parsed.message,
        errorCode: parsed.code,
        idempotencyKey: local.idempotencyKey,
      );
      return;
    }
    state = BookingState(
      phase: BookingPhase.error,
      record: record,
      preparation: local.preparation,
      errorMessage: parsed.message,
      errorCode: parsed.code,
      priceAccepted: local.priceAccepted,
      idempotencyKey: local.idempotencyKey,
    );
  }

  /// Whether [travelers] satisfies the booking type's requirements.
  ///
  /// Hotel bookings require at least one guest with a non-empty first and
  /// last name; flights keep the existing behaviour (the sandbox default is
  /// used when the list is empty).
  static bool _hasValidTravelers(String type, List<dynamic> travelers) {
    if (type != 'hotel') return true;
    if (travelers.isEmpty) return false;
    for (final dynamic traveler in travelers) {
      if (traveler is! Map) return false;
      final String firstName =
          (traveler['firstName'] as String?)?.trim() ?? '';
      final String lastName = (traveler['lastName'] as String?)?.trim() ?? '';
      if (firstName.isEmpty || lastName.isEmpty) return false;
    }
    return true;
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
