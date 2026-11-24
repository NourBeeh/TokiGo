/**
 * Nuitee provider contracts.
 *
 * These types used to live inside `nuitee.service.ts`. They are kept in their
 * own module so the transport client and the pure mapper can describe their
 * inputs without importing the service (and creating an import cycle).
 */

/** Rates-search input as the domain layer speaks it. */
export interface NuiteeSearchParams {
  city: string;
  checkIn: Date;
  checkOut: Date;
  guests?: number;
  rooms?: number;
  occupancies?: { adults: number; children?: number[] }[];
  /** ISO-2 country of the city. Omitted → resolved from the city table. */
  country?: string;
  /** Guest residency/nationality required by the provider. */
  nationality?: string;
  /** Traveller market (ISO-2). Used as nationality context when absent. */
  market?: string;
  /** Hotel content language. Omitted preserves Nuitee's default (English). */
  language?: 'en' | 'ar';
}

/**
 * Prebook outcome: the frozen quote plus the ids Nuitee will not re-issue.
 *
 * The documented response is root-shaped under `data` and carries `price`
 * (not `net`) and no expiry. `transactionId` is returned ONLY when
 * `usePaymentSdk: true`; the merchant-of-record flow uses `usePaymentSdk:
 * false`, so it is optional and must never be required to book.
 */
export interface NuiteePrebookResult {
  success: boolean;
  providerId: string;
  prebookId?: string;
  transactionId?: string;
  hotelId?: string;
  checkin?: string;
  checkout?: string;
  /** Number of booked rooms (`roomTypes[]` in the prebook response). */
  roomCount?: number;
  priceChanged?: boolean;
  priceDifferencePercent?: number;
  cancellationChanged?: boolean;
  boardChanged?: boolean;
  oldPrice?: number;
  newPrice?: number;
  currency?: string;
  /** Normalized condition facts reported by the provider (only true flags). */
  terms?: Record<string, any>;
  termsVersion?: string;
  changedTerms?: string[];
  expiresAt?: string;
  error?: string;
}

/**
 * One bookable room-type offer extracted from a rates response.
 *
 * `roomTypes[].offerId` is the identity prebook/book accept; `rates[]` are the
 * per-room components of that one offer (one rate per occupancy). The offer
 * total is `offerRetailRate` (all rooms), not a single rate's total.
 */
export interface NuiteeRateEntry {
  hotelId?: string;
  offerId?: string;
  roomTypeId?: string;
  roomType?: string;
  rates: any[];
  offerRetailRate?: any[];
  room?: any;
}

/** Holder/payer details required by `POST /rates/book`. */
export interface NuiteeBookingHolder {
  firstName: string;
  lastName: string;
  email: string;
  phone: string;
}

/** One primary guest per booked room, keyed by `occupancyNumber` (1-based). */
export interface NuiteeBookingGuest {
  occupancyNumber: number;
  firstName: string;
  lastName: string;
  email?: string;
  phone?: string;
  remarks?: string;
}

/**
 * The provider-verbatim offer TokiGo stores and displays. Every optional field
 * is absent when the provider did not send it — nothing here is invented.
 */
export interface NuiteeHotelOffer {
  id: string;
  type: 'hotel';
  providerId: string;
  providerName: string;
  title: string;
  subtitle: string;
  description: string;
  imageUrl?: string;
  price: number;
  currency: string;
  rating?: number;
  reviewCount?: number;
  city: string;
  country?: string;
  checkIn: string;
  checkOut: string;
  roomType: string;
  amenities: any[];
  metadata: Record<string, any>;
  /**
   * Every valid room-type offer for the same hotel, cheapest first. The
   * top-level fields are the cheapest offer; this array is what the details
   * selector shows. It is never used to make the hotel look available: the
   * whole object exists only because at least one live offer was returned.
   */
  offers?: NuiteeHotelOffer[];
}
