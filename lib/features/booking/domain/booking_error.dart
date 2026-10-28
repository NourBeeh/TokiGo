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
  final code = _parseBody(error.message)?['code']?.toString();
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
BookingError bookingErrorFrom(ApiError error) => BookingError(
  bookingErrorCodeFrom(error),
  error.message ?? 'Booking failed',
);

Map<String, dynamic>? _parseBody(String? message) {
  if (message == null || message.isEmpty) return null;
  try {
    final decoded = jsonDecode(message);
    return decoded is Map<String, dynamic> ? decoded : null;
  } catch (_) {
    return null;
  }
}
