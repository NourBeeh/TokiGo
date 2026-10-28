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
  /** ISO-2 country of the city. Omitted → resolved from the city table. */
  country?: string;
}

/** Prebook outcome: the frozen quote plus the ids Nuitee will not re-issue. */
export interface NuiteePrebookResult {
  success: boolean;
  providerId: string;
  prebookId?: string;
  transactionId?: string;
  priceChanged?: boolean;
  oldPrice?: number;
  newPrice?: number;
  currency?: string;
  expiresAt?: string;
  error?: string;
}

/** One `{hotel, roomType, rate}` entry extracted from a rates response. */
export interface NuiteeRateEntry {
  hotelId?: string;
  offerId?: string;
  roomType?: string;
  rate: any;
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
}
