import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tokigo/core/auth/token_session.dart';
import 'package:tokigo/core/network/api_client.dart';
import 'package:tokigo/core/network/api_error.dart';
import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/core/network/http_api_client.dart';
import 'package:tokigo/core/storage/secure_token_storage_provider.dart';

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
    this.expired = false,
  });

  final RevalidationStatus status;
  final double? price;
  final String? currency;
  final double? newPrice;
  final double? oldPrice;
  final String? expiresAt;
  final String? reason;

  /// True when the provider reports the offer itself expired (as opposed to a
  /// transport failure). The review page tells the traveller to search again
  /// instead of retrying the same offerId.
  final bool expired;

  bool get canProceed => status == RevalidationStatus.ok;

  /// A provider "offer expired / not found" reason — never a silent retry.
  static bool looksExpired(String? reason) =>
      reason != null &&
      RegExp('expir|404|not found', caseSensitive: false).hasMatch(reason);
}

/// Calls the backend `/offers/revalidate` endpoint right before checkout —
/// the Flutter side of the SELECTED -> PRICE_REVALIDATED transition
/// (spec point 8: never charge a stale search price).
///
/// AUTH: the backend refuses an anonymous Nuitee hotel revalidation because
/// that path calls `prebookHotel`, which freezes a quote at the provider. This
/// service therefore attaches the session Bearer token from [TokenSession] (the
/// app's single secure token store) and, for that provider, NEVER falls back to
/// an anonymous call:
///
///  * no stored access token  -> returns an error outcome, no request is made;
///  * 401 (expired access)    -> one renewal via `POST /auth/refresh`, then a
///                               single retry with the new token;
///  * renewal failed           -> error outcome; the store has been cleared.
///
/// Read-only providers (Nuitee flights, Duffel) keep working exactly as before
/// for signed-out travellers; when a session exists they simply send the token
/// too.
class OfferRevalidationService {
  OfferRevalidationService(ApiClient client, {TokenSession? session})
    : this._(client, session);

  OfferRevalidationService._(this._client, this._session);

  final ApiClient _client;
  final TokenSession? _session;

  /// Providers whose revalidation has a real provider-side side effect
  /// (a Nuitee hotel prebook creates an inventory hold).
  static const Set<String> _holdProviders = <String>{'nuitee'};

  Future<RevalidationOutcome> revalidate({
    required String offerId,
    required String providerId,
    required String offerType,
    double? knownPrice,
    int? guests,
  }) async {
    final requiresAuth = _holdProviders.contains(providerId);
    final headers = await _session?.authHeaders();

    // P0-S3: never revalidate a hold-creating provider anonymously.
    if (requiresAuth && (headers == null || headers.isEmpty)) {
      return const RevalidationOutcome(
        status: RevalidationStatus.error,
        reason: 'Sign-in required to revalidate this offer.',
      );
    }

    final body = <String, dynamic>{
      'offerId': offerId,
      'providerId': providerId,
      'offerType': offerType,
      'knownPrice': ?knownPrice,
      'guests': ?guests,
    };

    var result = await _post(headers: headers, body: body);

    // Expired access token: renew once through the existing refresh flow and
    // retry. A failed renewal is terminal — never an anonymous retry.
    //
    // Only 401 means "expired": a 403 is an authorisation decision that a new
    // token cannot change, so it is surfaced as-is.
    final error = result.errorOrNull;
    final accessTokenExpired =
        error is ApiUnauthorizedError && error.statusCode == 401;
    if (requiresAuth && accessTokenExpired) {
      final TokenRefreshOutcome? renewal = await _session?.refresh();
      if (renewal == null || !renewal.isSuccess) {
        // Transport failure: the stored tokens are intact, so the traveller
        // can simply retry. A rejected/malformed refresh means the session is
        // dead (the store was cleared) — signing in again is the only path.
        final bool transport =
            renewal?.failure == TokenRefreshFailure.transport;
        return RevalidationOutcome(
          status: RevalidationStatus.error,
          reason: transport
              ? 'We could not reach the server to refresh your session. Please try again.'
              : 'Session expired. Please sign in again.',
        );
      }
      final renewed = renewal.accessToken!;
      result = await _post(
        headers: <String, String>{'Authorization': 'Bearer $renewed'},
        body: body,
      );
    }

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
            final reason = body['reason']?.toString();
            return RevalidationOutcome(
              status: RevalidationStatus.unavailable,
              reason: reason,
              expired: RevalidationOutcome.looksExpired(reason),
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

  /// Posts the revalidation request. A transport-level throw is reported as a
  /// failure — never as an anonymous success.
  Future<ApiResult<Map<String, dynamic>>> _post({
    Map<String, String>? headers,
    required Map<String, dynamic> body,
  }) async {
    try {
      return await _client.post<Map<String, dynamic>>(
        '/offers/revalidate',
        headers: headers,
        body: body,
      );
    } catch (_) {
      return const ApiResult.failure(
        ApiNetworkError(message: 'Revalidation request failed.'),
      );
    }
  }
}

final offerRevalidationServiceProvider = Provider<OfferRevalidationService>((
  ref,
) {
  final client = HttpApiClient();
  return OfferRevalidationService(
    client,
    session: TokenSession(
      apiClient: client,
      storage: ref.watch(secureTokenStorageProvider),
    ),
  );
});
