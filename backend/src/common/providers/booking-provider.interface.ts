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
  available: boolean;
  expiresAt?: string;
  /** Set when the provider itself reports the price moved. */
  priceChanged?: boolean;
  oldPrice?: number;
  /** Opaque provider handoff data (e.g. Nuitee prebookId/transactionId). */
  handoff?: Record<string, any>;
}

export interface CreateBookingInput {
  offerId: string;
  /** Persisted provider snapshot built during prepare/revalidate. */
  offerSnapshot?: Record<string, any>;
  travelers?: any[];
}

export interface CreatedBooking {
  /** Human-facing provider confirmation reference (PNR / code). */
  reference: string;
  providerBookingId?: string;
  status?: string;
  amount?: number;
  currency?: string;
  raw?: Record<string, any>;
}

export interface CancelBookingInput {
  bookingReference?: string;
  providerBookingId?: string;
  offerSnapshot?: Record<string, any>;
}

/** A provider that can participate in the booking lifecycle. */
export interface BookingProvider {
  readonly providerId: string;
  readonly providerName: string;
  readonly bookingCapability: BookingCapability;
  revalidateBooking(offerId: string): Promise<ProviderResult<BookingRevalidation>>;
  createBooking(input: CreateBookingInput): Promise<ProviderResult<CreatedBooking>>;
  cancelBooking?(
    input: CancelBookingInput,
  ): Promise<ProviderResult<{ cancelled: boolean }>>;
}
