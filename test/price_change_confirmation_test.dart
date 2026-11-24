import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tokigo/core/domain/models/booking/booking.dart';
import 'package:tokigo/core/network/api_error.dart';
import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/core/repositories/contracts/booking_repository.dart';
import 'package:tokigo/features/bag/application/bag_controller.dart';
import 'package:tokigo/features/booking/application/booking_controller.dart';
import 'package:tokigo/features/booking/application/booking_state.dart';
import 'package:tokigo/features/booking/application/confirm_booking_usecase.dart';
import 'package:tokigo/features/booking/application/decide_price_change_usecase.dart';
import 'package:tokigo/features/booking/application/prepare_booking_usecase.dart';
import 'package:tokigo/features/booking/application/revalidate_booking_usecase.dart';
import 'package:tokigo/features/booking/domain/booking_preparation.dart';
import 'package:tokigo/features/booking/domain/booking_record.dart';
import 'package:tokigo/features/booking/domain/price_change.dart';

/// Shared price/terms-change confirmation contract.
///
/// The model is backend-owned: it must parse exactly what the backend sends,
/// reject anything without an identity/amount/currency/terms version, and never
/// invent missing facts. The controller must never accept a change locally.

Map<String, dynamic> _rawChange({
  String providerId = 'duffel-flight',
  String offerId = 'off-1',
  String currency = 'USD',
  double currentPrice = 950,
  double? previousPrice = 800,
  String termsVersion = 'terms-v1-abc',
  bool priceChanged = true,
  bool termsChanged = false,
  List<String> changedTerms = const <String>[],
  bool requiresAcceptance = true,
  bool accepted = false,
  String? decision,
}) {
  return <String, dynamic>{
    'providerId': providerId,
    'offerId': offerId,
    'offerType': 'flight',
    'previousPrice': previousPrice,
    'currentPrice': currentPrice,
    'currency': currency,
    'priceDifference': previousPrice == null ? 0 : currentPrice - previousPrice,
    'priceChangePercent': previousPrice == null || previousPrice == 0
        ? null
        : ((currentPrice - previousPrice) / previousPrice) * 100,
    'priceChanged': priceChanged,
    'termsChanged': termsChanged,
    'changedTerms': changedTerms,
    'previousTerms': <String, dynamic>{'conditions': 'old'},
    'currentTerms': <String, dynamic>{'conditions': 'new'},
    'termsVersion': termsVersion,
    'requiresAcceptance': requiresAcceptance,
    'accepted': accepted,
    'decision': decision,
    'checkedAt': '2026-01-02T00:00:00.000Z',
  };
}

PriceChangeConfirmation _change({
  double previousPrice = 800,
  double currentPrice = 950,
  bool requiresAcceptance = true,
  bool accepted = false,
  String? decision,
}) {
  return PriceChangeConfirmation(
    providerId: 'duffel-flight',
    offerId: 'off-1',
    offerType: 'flight',
    previousPrice: previousPrice,
    currentPrice: currentPrice,
    currency: 'USD',
    priceDifference: currentPrice - previousPrice,
    priceChangePercent: ((currentPrice - previousPrice) / previousPrice) * 100,
    priceChanged: true,
    termsChanged: false,
    changedTerms: const <String>[],
    termsVersion: 'terms-v1-abc',
    requiresAcceptance: requiresAcceptance,
    accepted: accepted,
    decision: decision,
    checkedAt: DateTime.utc(2026, 1, 2),
  );
}

BookingRecord _record({
  double price = 950,
  PriceChangeConfirmation? priceChange,
}) {
  return BookingRecord(
    bookingId: 'bk-1',
    userId: 'user-1',
    searchId: 'search-1',
    offerId: 'off-1',
    providerId: 'duffel-flight',
    providerName: 'Duffel',
    type: 'flight',
    status: BookingStatus.pending,
    currency: 'USD',
    authoritativePrice: price,
    priceBreakdown: PriceBreakdown.empty,
    travelers: const <Passenger>[],
    bookingReference: '',
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
    priceChange: priceChange,
  );
}

BookingPreparation _preparation() => const BookingPreparation(
  request: BookingRequest(
    offerId: 'off-1',
    providerId: 'duffel-flight',
    searchId: 'search-1',
  ),
  revalidation: PriceRevalidationResult(
    authoritativePrice: 950,
    currency: 'USD',
    priceChanged: true,
    available: true,
  ),
);

class _NoopBookingRepository implements BookingRepository {
  int createCalls = 0;

  @override
  Future<ApiResult<BookingRecord>> prepareBooking(
    String offerId,
    String providerId,
    String searchId,
  ) async => ApiResult.success(_record());

  @override
  Future<ApiResult<BookingRecord>> revalidateBooking(String bookingId) async =>
      ApiResult.success(_record());

  @override
  Future<ApiResult<BookingRecord>> createBooking(
    String bookingId,
    String idempotencyKey,
    List<dynamic> travelers,
  ) async {
    createCalls++;
    return ApiResult.success(
      _record(price: 950, priceChange: _change(
        requiresAcceptance: false,
        accepted: true,
        decision: 'accepted',
      )).copyWith(status: BookingStatus.confirmed),
    );
  }

  @override
  Future<ApiResult<BookingRecord>> getBooking(String bookingId) async =>
      ApiResult.success(_record());

  @override
  Future<ApiResult<BookingRecord>> getBookingStatus(String bookingId) async =>
      ApiResult.success(_record());

  @override
  Future<ApiResult<void>> cancelBooking(String bookingId) async =>
      const ApiResult<void>.success(null);
}

class _FakeDecisionRepository implements PriceChangeDecisionRepository {
  int calls = 0;
  String? decision;
  double? expectedPrice;
  String? expectedCurrency;
  String? expectedTermsVersion;
  ApiResult<BookingRecord> Function()? responder;

  @override
  Future<ApiResult<BookingRecord>> decidePriceChange(
    String bookingId, {
    required String decision,
    double? expectedPrice,
    String? expectedCurrency,
    String? expectedTermsVersion,
  }) async {
    calls++;
    this.decision = decision;
    this.expectedPrice = expectedPrice;
    this.expectedCurrency = expectedCurrency;
    this.expectedTermsVersion = expectedTermsVersion;
    return responder?.call() ??
        ApiResult.success(
          _record(
            priceChange: _change(
              requiresAcceptance: false,
              accepted: true,
              decision: 'accepted',
            ),
          ),
        );
  }
}

BookingController _controller(
  _NoopBookingRepository repo, {
  PriceChangeDecisionRepository? decisions,
}) {
  return BookingController(
    prepareUseCase: PrepareBookingUseCase(repo),
    revalidateUseCase: RevalidateBookingUseCase(repo),
    confirmUseCase: ConfirmBookingUseCase(repo),
    decidePriceChangeUseCase: decisions == null
        ? null
        : DecidePriceChangeUseCase(decisions),
    bagController: BagController(),
  );
}

void main() {
  group('PriceChangeConfirmation.tryParse', () {
    test('parses the complete backend payload verbatim', () {
      final change = PriceChangeConfirmation.tryParse(
        _rawChange(
          termsChanged: true,
          changedTerms: <String>['conditions', 'baggageAllowances'],
        ),
      );

      expect(change, isNotNull);
      expect(change!.providerId, 'duffel-flight');
      expect(change.offerId, 'off-1');
      expect(change.offerType, 'flight');
      expect(change.previousPrice, 800);
      expect(change.currentPrice, 950);
      expect(change.currency, 'USD');
      expect(change.priceDifference, 150);
      expect(change.priceChangePercent, 18.75);
      expect(change.priceChanged, isTrue);
      expect(change.termsChanged, isTrue);
      expect(change.changedTerms, <String>[
        'conditions',
        'baggageAllowances',
      ]);
      expect(change.termsVersion, 'terms-v1-abc');
      expect(change.requiresAcceptance, isTrue);
      expect(change.accepted, isFalse);
      expect(change.decision, isNull);
      expect(change.checkedAt, DateTime.utc(2026, 1, 2));
    });

    test('rejects a payload without the exact offer identity', () {
      expect(
        PriceChangeConfirmation.tryParse(_rawChange(providerId: '')),
        isNull,
      );
      expect(
        PriceChangeConfirmation.tryParse(_rawChange(offerId: '  ')),
        isNull,
      );
      expect(PriceChangeConfirmation.tryParse(null), isNull);
      expect(PriceChangeConfirmation.tryParse('not-a-map'), isNull);
      expect(PriceChangeConfirmation.tryParse(<dynamic>[]), isNull);
    });

    test('rejects a payload without a usable price or currency', () {
      expect(
        PriceChangeConfirmation.tryParse(_rawChange(currency: '')),
        isNull,
      );
      expect(
        PriceChangeConfirmation.tryParse(_rawChange(currentPrice: 0)),
        isNull,
      );
      expect(
        PriceChangeConfirmation.tryParse(_rawChange(currentPrice: -5)),
        isNull,
      );
      final missingPrice = _rawChange()..remove('currentPrice');
      expect(PriceChangeConfirmation.tryParse(missingPrice), isNull);
    });

    test('rejects a payload without the terms version', () {
      expect(
        PriceChangeConfirmation.tryParse(_rawChange(termsVersion: '')),
        isNull,
      );
      final missingVersion = _rawChange()..remove('termsVersion');
      expect(PriceChangeConfirmation.tryParse(missingVersion), isNull);
    });

    test('keeps unknown facts unknown instead of inventing them', () {
      final raw = _rawChange(previousPrice: null)
        ..remove('previousTerms')
        ..remove('currentTerms')
        ..remove('priceChangePercent');
      final change = PriceChangeConfirmation.tryParse(raw)!;

      expect(change.previousPrice, isNull);
      expect(change.priceChangePercent, isNull);
      expect(change.previousTerms, isNull);
      expect(change.currentTerms, isNull);
      expect(change.priceDifference, 0);
    });

    test('acceptance payload binds decision to the shown amount/terms', () {
      final change = PriceChangeConfirmation.tryParse(_rawChange())!;
      expect(change.acceptancePayload('accept'), <String, dynamic>{
        'decision': 'accept',
        'expectedPrice': 950.0,
        'expectedCurrency': 'USD',
        'expectedTermsVersion': 'terms-v1-abc',
      });
    });
  });

  group('BookingController price/terms acceptance', () {
    test('acceptNewPrice sends the exact signature and trusts the backend',
        () async {
      final repo = _NoopBookingRepository();
      final decisions = _FakeDecisionRepository();
      final controller = _controller(repo, decisions: decisions);
      addTearDown(controller.dispose);
      controller.state = BookingState(
        phase: BookingPhase.priceChanged,
        record: _record(priceChange: _change()),
        preparation: _preparation(),
      );

      final accepted = await controller.acceptNewPrice();

      expect(accepted, isTrue);
      expect(decisions.calls, 1);
      expect(decisions.decision, 'accept');
      expect(decisions.expectedPrice, 950);
      expect(decisions.expectedCurrency, 'USD');
      expect(decisions.expectedTermsVersion, 'terms-v1-abc');
      expect(controller.state.phase, BookingPhase.readyToConfirm);
      expect(controller.state.priceAccepted, isTrue);
      expect(controller.state.record?.priceChange?.accepted, isTrue);
    });

    test('a failed acceptance never unblocks confirmation', () async {
      final repo = _NoopBookingRepository();
      final decisions = _FakeDecisionRepository()
        ..responder = () => ApiResult.failure(
          const ApiClientError(
            message: '{"code":"provider_unavailable","message":"try later"}',
            statusCode: 503,
          ),
        );
      final controller = _controller(repo, decisions: decisions);
      addTearDown(controller.dispose);
      controller.state = BookingState(
        phase: BookingPhase.priceChanged,
        record: _record(priceChange: _change()),
        preparation: _preparation(),
      );

      final accepted = await controller.acceptNewPrice();

      expect(accepted, isFalse);
      expect(controller.state.phase, BookingPhase.error);
      expect(controller.state.priceAccepted, isFalse);
      expect(controller.state.record?.priceChange?.accepted, isFalse);
      expect(repo.createCalls, 0);
    });

    test('a stale acceptance surfaces the newer change, not a success',
        () async {
      final repo = _NoopBookingRepository();
      final decisions = _FakeDecisionRepository()
        ..responder = () => ApiResult.failure(
          ApiClientError(
            message: jsonEncode(<String, dynamic>{
              'code': 'price_changed',
              'message': 'The offer changed again',
              'details': <String, dynamic>{
                'priceChange': _rawChange(
                  currentPrice: 990,
                  termsVersion: 'terms-v1-new',
                ),
              },
            }),
            statusCode: 409,
          ),
        );
      final controller = _controller(repo, decisions: decisions);
      addTearDown(controller.dispose);
      controller.state = BookingState(
        phase: BookingPhase.priceChanged,
        record: _record(priceChange: _change()),
        preparation: _preparation(),
      );

      final accepted = await controller.acceptNewPrice();

      expect(accepted, isFalse);
      expect(controller.state.phase, BookingPhase.priceChanged);
      expect(controller.state.record?.priceChange?.currentPrice, 990);
      expect(controller.state.record?.priceChange?.termsVersion,
          'terms-v1-new');
      expect(controller.state.priceAccepted, isFalse);
      expect(repo.createCalls, 0);
    });

    test('decline records the refusal and never books at the changed price',
        () async {
      final repo = _NoopBookingRepository();
      final decisions = _FakeDecisionRepository()
        ..responder = () => ApiResult.success(
          _record(
            priceChange: _change(
              requiresAcceptance: false,
              decision: 'declined',
            ),
          ),
        );
      final controller = _controller(repo, decisions: decisions);
      addTearDown(controller.dispose);
      controller.state = BookingState(
        phase: BookingPhase.priceChanged,
        record: _record(priceChange: _change()),
        preparation: _preparation(),
      );

      final declined = await controller.declinePriceChange();

      expect(declined, isTrue);
      expect(decisions.calls, 1);
      expect(decisions.decision, 'decline');
      expect(controller.state.phase, BookingPhase.priceChangeDeclined);
      expect(repo.createCalls, 0);

      // A confirm attempt after the refusal cannot book anything either.
      await controller.confirm();
      expect(repo.createCalls, 0);
      expect(controller.state.phase, isNot(BookingPhase.confirmed));
    });

    test('without a decision surface acceptance fails closed', () async {
      final repo = _NoopBookingRepository();
      final controller = _controller(repo);
      addTearDown(controller.dispose);
      controller.state = BookingState(
        phase: BookingPhase.priceChanged,
        record: _record(priceChange: _change()),
        preparation: _preparation(),
      );

      final accepted = await controller.acceptNewPrice();

      expect(accepted, isFalse);
      expect(controller.state.phase, BookingPhase.error);
      expect(controller.state.priceAccepted, isFalse);
      expect(repo.createCalls, 0);
    });

    test('confirm refuses a pending change and allows only an accepted one',
        () async {
      final repo = _NoopBookingRepository();
      final controller = _controller(repo);
      addTearDown(controller.dispose);

      controller.state = BookingState(
        phase: BookingPhase.readyToConfirm,
        record: _record(priceChange: _change()),
        preparation: _preparation(),
        priceAccepted: false,
      );
      await controller.confirm();
      expect(repo.createCalls, 0);
      expect(controller.state.phase, BookingPhase.priceChanged);

      controller.state = BookingState(
        phase: BookingPhase.readyToConfirm,
        record: _record(
          priceChange: _change(
            requiresAcceptance: false,
            accepted: true,
            decision: 'accepted',
          ),
        ),
        preparation: _preparation(),
        priceAccepted: true,
      );
      await controller.confirm();
      expect(repo.createCalls, 1);
      expect(controller.state.phase, BookingPhase.confirmed);
    });
  });
}
