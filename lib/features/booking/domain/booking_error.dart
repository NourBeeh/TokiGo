import 'dart:convert';

import 'package:tokigo/core/network/api_error.dart';

/// Normalised booking failure codes — mirror the backend `code` values 1:1
/// (Phase 4A `BookingException`). The client never parses free-text.
enum BookingErrorCode {
  offerNotFound,
  bookingNotFound,
  providerUnavailable,
  priceChanged,
  noAvailability,
  bookingExpired,
  validationFailed,
  unauthorized,
  providerError,
  duplicateRequest,
  capabilityUnsupported,
  /// The provider booking/payment outcome is unknown and must be reconciled
  /// before anything else happens. This is deliberately distinct from
  /// [duplicateRequest] (a replay of the same request) and from
  /// [providerError] (a definitive failure): nothing proves the booking
  /// failed, so the customer must not retry the booking or pay again.
  bookingOutcomeUnknown,
  unknownError,
}

class BookingError {
  final BookingErrorCode code;
  final String message;
  final Map<String, dynamic> details;

  const BookingError(this.code, this.message, [this.details = const {}]);
}

/// Maps a network-layer [ApiError] to a stable [BookingErrorCode].
///
/// Preference order: the backend's structured `{code}` in the response body,
/// then a status-code fallback so even an unstructured failure is classified.
BookingErrorCode bookingErrorCodeFrom(ApiError error) {
  // A transport failure means the provider never answered (timeout / socket
  // loss). It is a providerUnavailable outcome, not an unknown one — callers
  // use this code to decide whether a retry is meaningful.
  if (error is ApiTimeoutError || error is ApiNetworkError) {
    return BookingErrorCode.providerUnavailable;
  }

  final body = _parseBody(error.message);

  // A 409 can mean several different things. The unknown-outcome surface is
  // recognised from its structured details (and/or code) BEFORE the generic
  // status fallback, so it can never collapse into `duplicateRequest`.
  if (_isReconciliationPending(body)) {
    return BookingErrorCode.bookingOutcomeUnknown;
  }

  final code = body?['code']?.toString();
  switch (code) {
    case 'offer_not_found':
      return BookingErrorCode.offerNotFound;
    case 'booking_not_found':
      return BookingErrorCode.bookingNotFound;
    case 'provider_unavailable':
      return BookingErrorCode.providerUnavailable;
    case 'price_changed':
      return BookingErrorCode.priceChanged;
    case 'no_availability':
      return BookingErrorCode.noAvailability;
    case 'booking_expired':
      return BookingErrorCode.bookingExpired;
    case 'validation_failed':
      return BookingErrorCode.validationFailed;
    case 'unauthorized':
      return BookingErrorCode.unauthorized;
    case 'provider_error':
      return BookingErrorCode.providerError;
    case 'duplicate_request':
      return BookingErrorCode.duplicateRequest;
    case 'capability_unsupported':
      return BookingErrorCode.capabilityUnsupported;
    case 'booking_outcome_unknown':
      return BookingErrorCode.bookingOutcomeUnknown;
  }

  switch (error.statusCode) {
    case 401:
    case 403:
      return BookingErrorCode.unauthorized;
    case 404:
      return BookingErrorCode.offerNotFound;
    case 409:
      return BookingErrorCode.duplicateRequest;
    case 422:
      return BookingErrorCode.validationFailed;
    case 503:
      return BookingErrorCode.providerUnavailable;
    default:
      return BookingErrorCode.unknownError;
  }
}

/// Builds a [BookingError] (code + human message) from a network failure.
/// The backend's structured `details` (e.g. the latest price-change summary)
/// are preserved so the funnel can show the exact changed amount/terms.
BookingError bookingErrorFrom(ApiError error) {
  final body = _parseBody(error.message);
  final rawDetails = body?['details'];
  final Map<String, dynamic> details = rawDetails is Map
      ? Map<String, dynamic>.from(rawDetails)
      : const <String, dynamic>{};
  // The backend's structured body carries the customer-facing message. Prefer
  // it over the raw JSON envelope so the funnel never shows transport bytes.
  final rawMessage = body?['message'];
  final String message = rawMessage is String && rawMessage.trim().isNotEmpty
      ? rawMessage
      : (error.message ?? 'Booking failed');
  return BookingError(bookingErrorCodeFrom(error), message, details);
}

/// Whether the backend explicitly marked the outcome as pending reconciliation.
///
/// The canonical payload is `{code: 'booking_outcome_unknown', details: {
/// status: 'reconciliation_pending', requiresReconciliation: true,
/// retryable: false, operationStatus: 'unknown'}}`. The flags are checked too,
/// so a future response that keeps the machine state but changes the code is
/// still classified safely instead of being mistaken for a duplicate 409.
bool _isReconciliationPending(Map<String, dynamic>? body) {
  if (body == null) return false;
  if (body['code']?.toString() == 'booking_outcome_unknown') return true;
  if (body['status']?.toString() == 'reconciliation_pending') return true;
  if (body['requiresReconciliation'] == true) return true;

  final rawDetails = body['details'];
  if (rawDetails is! Map) return false;
  final details = rawDetails;
  if (details['status']?.toString() == 'reconciliation_pending') return true;
  if (details['requiresReconciliation'] == true) return true;
  // An explicitly non-retryable unknown provider operation is the same state:
  // there is no proof of failure, so nothing may be resubmitted.
  return details['operationStatus']?.toString() == 'unknown' &&
      details['retryable'] == false;
}

Map<String, dynamic>? _parseBody(String? message) {
  if (message == null || message.isEmpty) return null;
  try {
    final decoded = jsonDecode(message);
    return decoded is Map<String, dynamic> ? decoded : null;
  } catch (_) {
    return null;
  }
}
