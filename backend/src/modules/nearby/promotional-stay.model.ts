/**
 * Promotional Nearby Stays wire contract (R3/R4).
 *
 * A PromotionalStay is DISCOVERY information, not a booking offer. It never
 * carries a provider rate/offer id, a prebook id, or a `priceVerified` flag:
 * those belong to the live booking path, and a promotional price must never be
 * replayed as a payable amount.
 */

/** How the search center was established. */
export type NearbyLocationSource = 'gps' | 'city';

/** Confidence in the center, echoed to the client. */
export type NearbyLocationConfidence = 'high' | 'medium';

export interface PromotionalStay {
  /** Provider hotel id (Nuitee `hotelId`), stable across searches. */
  hotelId: string;
  hotelName: string;
  city: string;
  country: string;
  image: string | null;
  latitude: number;
  longitude: number;
  /** Actual great-circle distance from the search center, in kilometres. */
  distanceKm: number;
  /** Guest rating on the 5-point display scale; null when the provider said nothing. */
  rating: number | null;
  reviewCount: number | null;
  /** Minimum valid ONE-NIGHT promotional rate across the searched window. */
  promotionalMinimumPrice: number;
  currency: string;
  /** First/last calendar date of the seven-night promotional window. */
  searchedFromDate: string;
  searchedToDate: string;
  /** Adults the promotional price was quoted for. */
  occupancy: number;
  nationality: string;
  provider: string;
  fetchedAt: string;
  locationConfidence: NearbyLocationConfidence;
}

export interface NearbyStaysResponse {
  stays: PromotionalStay[];
  /** The radius stage that actually produced the result (km). */
  radiusKm: number;
  locationConfidence: NearbyLocationConfidence | null;
  locationSource: NearbyLocationSource | null;
  /** True when the caller supplied no usable center; no nationwide fallback. */
  locationRequired: boolean;
  /** Honest reason when no stays could be produced. */
  reason?: 'no_location' | 'unknown_city' | 'no_geotagged_inventory' | 'no_valid_promotional_price';
  searchedFromDate: string | null;
  searchedToDate: string | null;
  currency: string;
  occupancy: number;
  nationality: string;
  provider: string;
  rankingVersion: string;
  partialFailure: boolean;
  fetchedAt: string;
}

/** Bump when the ranking formula changes; part of the cache identity. */
export const NEARBY_RANKING_VERSION = 'nearby-ranking-v1';
