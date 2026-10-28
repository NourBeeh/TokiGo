import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tokigo/core/network/api_client.dart';
import 'package:tokigo/core/network/http_api_client.dart';

/// Outcome of the pre-checkout revalidation call (spec points 7-8).
enum RevalidationStatus { ok, priceChanged, unavailable, error }

@immutable
class RevalidationOutcome {
  const RevalidationOutcome({
    required this.status,
    this.price,
    this.currency,
    this.newPrice,
    this.oldPrice,
    this.expiresAt,
    this.reason,
  });

  final RevalidationStatus status;
  final double? price;
  final String? currency;
  final double? newPrice;
  final double? oldPrice;
  final String? expiresAt;
  final String? reason;

  bool get canProceed => status == RevalidationStatus.ok;
}

/// Calls the backend `/offers/revalidate` endpoint right before checkout —
/// the Flutter side of the SELECTED -> PRICE_REVALIDATED transition
/// (spec point 8: never charge a stale search price).
class OfferRevalidationService {
  OfferRevalidationService(this._client);

  final ApiClient _client;

  Future<RevalidationOutcome> revalidate({
    required String offerId,
    required String providerId,
    required String offerType,
    double? knownPrice,
    int? guests,
  }) async {
    final result = await _client.post<Map<String, dynamic>>(
      '/offers/revalidate',
      body: <String, dynamic>{
        'offerId': offerId,
        'providerId': providerId,
        'offerType': offerType,
        'knownPrice': ?knownPrice,
        'guests': ?guests,
      },
    );

    return result.when(
      success: (body) {
        final status = body['status']?.toString();
        switch (status) {
          case 'OK':
            return RevalidationOutcome(
              status: RevalidationStatus.ok,
              price: (body['price'] as num?)?.toDouble(),
              currency: body['currency']?.toString(),
              expiresAt: body['expiresAt']?.toString(),
            );
          case 'PRICE_CHANGED':
            return RevalidationOutcome(
              status: RevalidationStatus.priceChanged,
              newPrice: (body['newPrice'] as num?)?.toDouble(),
              oldPrice: (body['oldPrice'] as num?)?.toDouble(),
              currency: body['currency']?.toString(),
              expiresAt: body['expiresAt']?.toString(),
            );
          case 'UNAVAILABLE':
            return RevalidationOutcome(
              status: RevalidationStatus.unavailable,
              reason: body['reason']?.toString(),
            );
          default:
            return RevalidationOutcome(
              status: RevalidationStatus.error,
              reason: body['error']?.toString() ?? 'Unexpected response',
            );
        }
      },
      failure: (error) => RevalidationOutcome(
        status: RevalidationStatus.error,
        reason: error.message,
      ),
    );
  }
}

final offerRevalidationServiceProvider = Provider<OfferRevalidationService>(
  (ref) => OfferRevalidationService(HttpApiClient()),
);
