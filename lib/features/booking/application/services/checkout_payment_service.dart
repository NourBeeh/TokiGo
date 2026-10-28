import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tokigo/core/network/api_client.dart';
import 'package:tokigo/core/network/http_api_client.dart';
import 'package:tokigo/core/storage/secure_token_storage.dart';
import 'package:tokigo/core/storage/secure_token_storage_provider.dart';

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
  CheckoutPaymentService(this._client, {this.tokenStorage});

  final ApiClient _client;

  /// Backend `/payments/*` routes are JWT-guarded (a payment belongs to an
  /// authenticated traveller), so every call carries the stored access token.
  /// Null in tests — a missing token simply means an unauthenticated call.
  final SecureTokenStorage? tokenStorage;

  /// `Authorization` header for the current session, or null when nobody is
  /// signed in. A null header is intentional: it lets the backend answer 401
  /// honestly instead of us inventing a token.
  Future<Map<String, String>?> _authHeaders() async {
    final token = await tokenStorage?.getAccessToken();
    if (token == null || token.isEmpty) return null;
    return <String, String>{'Authorization': 'Bearer $token'};
  }

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
      headers: await _authHeaders(),
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
        if (body['status'] == 'OK') {
          paymentId = body['intent']?['paymentId']?.toString();
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
      headers: await _authHeaders(),
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
        final status = body['intent']?['status']?.toString();
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
  (ref) => CheckoutPaymentService(
    HttpApiClient(),
    tokenStorage: ref.watch(secureTokenStorageProvider),
  ),
);
