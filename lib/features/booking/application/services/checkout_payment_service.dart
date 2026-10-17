import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tokigo/core/network/api_client.dart';
import 'package:tokigo/core/network/http_api_client.dart';

/// Result of the backend payment orchestration consumed by checkout.
enum PaymentOutcome { succeeded, pending3ds, failed, unavailable }

@immutable
class CheckoutPaymentResult {
  const CheckoutPaymentResult({
    required this.outcome,
    this.paymentId,
    this.reason,
  });

  final PaymentOutcome outcome;
  final String? paymentId;
  final String? reason;
}

/// Talks to the backend payment abstraction (spec point 31): creates the
/// intent, confirms with the picked method, and surfaces the 3DS/pending
/// state exactly like the production gateways will.
class CheckoutPaymentService {
  CheckoutPaymentService(this._client);

  final ApiClient _client;

  Future<CheckoutPaymentResult> pay({
    required String bookingId,
    required double amount,
    required String currency,
    required String market,
    required String idempotencyKey,
    required String method,
  }) async {
    // 1. Create the intent.
    final intentResult = await _client.post<Map<String, dynamic>>(
      '/payments/intent',
      body: <String, dynamic>{
        'bookingId': bookingId,
        'amount': amount,
        'currency': currency,
        'market': market,
        'idempotencyKey': 'intent-$idempotencyKey',
      },
    );

    String? paymentId;
    final intentOk = intentResult.when(
      success: (body) {
        if (body?['status'] == 'OK') {
          paymentId = body?['intent']?['paymentId']?.toString();
          return true;
        }
        return false;
      },
      failure: (_) => false,
    );

    if (!intentOk || paymentId == null) {
      return const CheckoutPaymentResult(
        outcome: PaymentOutcome.unavailable,
        reason: 'Payment unavailable for this market',
      );
    }

    // 2. Confirm with the picked method.
    final methodReference = switch (method) {
      'wallet' => 'WALLET',
      'card_3ds' => 'CARD_3DS',
      'card_declined' => 'CARD_DECLINED',
      _ => 'CARD_SUCCESS',
    };

    final confirmResult = await _client.post<Map<String, dynamic>>(
      '/payments/confirm',
      body: <String, dynamic>{
        'paymentId': paymentId,
        'methodReference': methodReference,
        'market': market,
        'idempotencyKey': 'confirm-$idempotencyKey',
        'bookingId': bookingId,
      },
    );

    return confirmResult.when(
      success: (body) {
        final status = body?['intent']?['status']?.toString();
        switch (status) {
          case 'SUCCEEDED':
            return CheckoutPaymentResult(
              outcome: PaymentOutcome.succeeded,
              paymentId: paymentId,
            );
          case 'PENDING':
            return CheckoutPaymentResult(
              outcome: PaymentOutcome.pending3ds,
              paymentId: paymentId,
            );
          case 'FAILED':
            return CheckoutPaymentResult(
              outcome: PaymentOutcome.failed,
              paymentId: paymentId,
            );
          default:
            return CheckoutPaymentResult(
              outcome: PaymentOutcome.unavailable,
              reason: 'Unexpected payment status',
            );
        }
      },
      failure: (error) => CheckoutPaymentResult(
        outcome: PaymentOutcome.failed,
        reason: error.message,
      ),
    );
  }
}

final checkoutPaymentServiceProvider = Provider<CheckoutPaymentService>(
  (ref) => CheckoutPaymentService(HttpApiClient()),
);
