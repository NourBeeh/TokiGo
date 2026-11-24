import { HttpException, HttpStatus } from '@nestjs/common';

/**
 * Normalised booking error taxonomy (Phase 4A).
 *
 * Every failure the booking surface can produce is expressed with a stable
 * machine-readable `code` plus an HTTP status, so the client never has to
 * parse free-text. The Flutter repository maps these codes 1:1 onto
 * `BookingErrorCode`.
 */
export type BookingErrorCode =
  | 'offer_not_found'
  | 'booking_not_found'
  | 'validation_failed'
  | 'booking_expired'
  | 'price_changed'
  | 'no_availability'
  | 'duplicate_request'
  | 'unauthorized'
  | 'capability_unsupported'
  | 'provider_unavailable'
  | 'provider_error'
  | 'booking_outcome_unknown'
  | 'payment_required'
  | 'payment_not_verified'
  | 'unknown_error';

const STATUS_BY_CODE: Record<BookingErrorCode, number> = {
  offer_not_found: HttpStatus.NOT_FOUND,
  booking_not_found: HttpStatus.NOT_FOUND,
  validation_failed: HttpStatus.UNPROCESSABLE_ENTITY,
  booking_expired: HttpStatus.CONFLICT,
  price_changed: HttpStatus.CONFLICT,
  no_availability: HttpStatus.CONFLICT,
  duplicate_request: HttpStatus.CONFLICT,
  unauthorized: HttpStatus.UNAUTHORIZED,
  capability_unsupported: HttpStatus.UNPROCESSABLE_ENTITY,
  provider_unavailable: HttpStatus.SERVICE_UNAVAILABLE,
  provider_error: HttpStatus.BAD_GATEWAY,
  /**
   * NOT a 2xx: the Flutter transport treats every 2xx as success and would
   * falsely confirm the booking. 409 is a stable error surface that carries
   * the `{code, message, details}` body; the client must not retry.
   */
  booking_outcome_unknown: HttpStatus.CONFLICT,
  /** A verified customer payment is required before a provider booking. */
  payment_required: HttpStatus.CONFLICT,
  /** Payment evidence exists but does not prove this exact booking amount. */
  payment_not_verified: HttpStatus.CONFLICT,
  unknown_error: HttpStatus.INTERNAL_SERVER_ERROR,
};

export class BookingException extends HttpException {
  readonly code: BookingErrorCode;

  constructor(
    code: BookingErrorCode,
    message: string,
    details?: Record<string, any>,
  ) {
    super(
      { code, message, ...(details ? { details } : {}) },
      STATUS_BY_CODE[code],
    );
    this.code = code;
  }

  static statusFor(code: BookingErrorCode): number {
    return STATUS_BY_CODE[code];
  }
}
