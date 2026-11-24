import { OfferTermsSnapshot } from '../pricing/offer-terms';
import { ProviderResult } from './provider.result';

/**
 * Provider booking capability descriptor (Phase 4A).
 *
 * The search abstractions (FlightProvider/HotelProvider) only describe how to
 * FIND offers. Booking must not be an ad-hoc switch on concrete service
 * classes — every provider declares, in one place, what it can actually do.
 * The booking service checks `bookingCapability` BEFORE calling anything, so
 * an unsupported action surfaces as a structured capability error instead of
 * a crash or a silent no-op.
 */
export interface BookingCapability {
  /** Can this provider commit an offer into a real booking? */
  book: boolean;
  /** Can this provider cancel an existing booking? */
  cancel: boolean;
  /** Can this provider revalidate a live offer's price/availability? */
  revalidate: boolean;
}

/** Result of a provider-side price/availability revalidation. */
export interface BookingRevalidation {
  /** Authoritative price returned by the provider. */
  price: number;
  currency: string;
  /** Provider's own amount string, preserving its decimal convention. */
  amountText?: string;
  available: boolean;
  expiresAt?: string;
  /** Set when the provider itself reports the price moved. */
  priceChanged?: boolean;
  oldPrice?: number;
  /** Opaque provider handoff data (e.g. Nuitee prebookId/transactionId). */
  handoff?: Record<string, any>;
  /**
   * Normalized fare/room/cancellation/baggage facts returned by the provider
   * during this revalidation. Absent fields stay unknown; they are never
   * filled with defaults.
   */
  terms?: OfferTermsSnapshot;
  /** Stable hash of [terms]. The customer acceptance is bound to it. */
  termsVersion?: string;
  /**
   * Provider-reported condition changes (e.g. Nuitee `cancellationChanged`,
   * `boardChanged`). Empty when the provider reports no change flags.
   */
  changedTerms?: string[];
}

export interface CreateBookingInput {
  offerId: string;
  /** Persisted provider snapshot built during prepare/revalidate. */
  offerSnapshot?: Record<string, any>;
  travelers?: any[];
  /**
   * Persisted TokiGo booking identity. Providers that support a client
   * reference use it as their idempotency key so a retried request cannot
   * create a second booking.
   */
  bookingId?: string;
  /**
   * Server-authoritative amount/currency taken from the final revalidation.
   * A provider call that needs a payment MUST use these exact values; the
   * adapter must fail before calling the provider when they are missing.
   */
  amount?: number;
  currency?: string;
  /**
   * The provider-offer amount string from the final revalidation, when the
   * provider publishes one. It preserves the provider's own decimal places
   * (e.g. currencies without minor units) instead of reformatting a number.
   */
  amountText?: string;
  /** Accepted commercial version the payment evidence is bound to. */
  priceVersion?: string;
  /** Verified payment-attempt id; provider metadata only, never card data. */
  paymentAttemptId?: string;
}

/** Normalized provider confirmation state, decided by each adapter. */
export type ProviderConfirmationState =
  | 'confirmed'
  | 'pending'
  | 'failed'
  | 'unknown';

export interface CreatedBooking {
  /** Human-facing provider confirmation reference (PNR / code). */
  reference: string;
  providerBookingId?: string;
  status?: string;
  amount?: number;
  currency?: string;
  raw?: Record<string, any>;
  /**
   * Provider truth about whether the booking/ticketing is actually
   * established. `pending`/`unknown` must be persisted as
   * reconciliation-pending; only `confirmed` may reach booking confirmation.
   * Adapters set this explicitly; `status` is kept for provider evidence.
   */
  confirmationState?: ProviderConfirmationState;
}

export interface CancelBookingInput {
  bookingReference?: string;
  providerBookingId?: string;
  offerSnapshot?: Record<string, any>;
}

/** Context a provider may need to revalidate an offer. */
export interface RevalidationContext {
  /**
   * Travellers collected by the funnel. Present at CONFIRM time (the booking
   * service passes the persisted list); absent at prepare time, where the
   * traveller form has not been filled yet.
   */
  travelers?: any[];
  /**
   * The booking's persisted provider snapshot (`offerId`, `prebookId`,
   * `transactionId`, …). Present at REVIEW time so a provider can validate the
   * EXISTING hold instead of creating another one; absent at prepare time,
   * where no hold exists yet.
   */
  offerSnapshot?: Record<string, any>;
}

/** A provider that can participate in the booking lifecycle. */
export interface BookingProvider {
  readonly providerId: string;
  readonly providerName: string;
  readonly bookingCapability: BookingCapability;
  revalidateBooking(
    offerId: string,
    context?: RevalidationContext,
  ): Promise<ProviderResult<BookingRevalidation>>;
  /**
   * Commit the offer into a provider booking.
   *
   * `success: true` is a DEFINITIVE success and MUST carry a non-empty
   * `data.reference`. `success: false` MUST classify the outcome:
   *  - `failureKind: 'definitive'` only when the provider explicitly refused
   *    and no booking was created (safe to retry);
   *  - `failureKind: 'ambiguous'` (or omitted) for timeouts, lost responses,
   *    5xx, malformed bodies, and any state where the provider may have
   *    created the booking.
   *
   * Callers persist an ambiguous result as reconciliation-pending and never
   * submit the same logical booking again.
   */
  createBooking(input: CreateBookingInput): Promise<ProviderResult<CreatedBooking>>;
  cancelBooking?(
    input: CancelBookingInput,
  ): Promise<ProviderResult<{ cancelled: boolean }>>;
}
