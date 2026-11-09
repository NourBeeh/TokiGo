import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { FlightProvider } from '../../common/providers/flight.provider';
import { ProviderResult } from '../../common/providers/provider.result';
import { resolveIataCode } from '../duffel/duffel.service';

/**
 * Phase 3B — Nuitee flights adapter behind the shared FlightProvider contract
 * (user decision 2026-09-08: flights = Duffel first, Nuitee as the swappable
 * alternative, switchable from the admin provider panel; same key gate as
 * the hotel adapter).
 *
 * API contract per docs.liteapi.travel (v3.0, verified 2026-09-08):
 *   POST /v3.0/flights/rates   header X-API-Key
 *   body: { legs: [{ origin, destination, date, direction? }], adults, currency }
 *   response: { data: [{ journeys: [{ journeyKey, segments, offers }] }] }
 *   offer: { offerId, expiration, pricing: { display: { total, currency } },
 *            fare: { family }, terms, baggage }
 *
 * The itinerary MUST be legs-based; top-level origin/destination/departureDate
 * are NOT supported by the endpoint.
 */

const NUITEE_BASE_URL = 'https://api.liteapi.travel/v3.0';

/** Per-provider budget for ONE search call (spec point 12/15 + 3B). */
const FLIGHT_SEARCH_TIMEOUT_MS = 20_000;

@Injectable()
export class NuiteeFlightService implements FlightProvider {
  providerId = 'nuitee-flight';
  providerName = 'Nuitee Flights';

  private readonly logger = new Logger(NuiteeFlightService.name);
  private readonly apiKey?: string;

  constructor(private configService: ConfigService) {
    this.apiKey = this.configService.get<string>('NUITEE_API_KEY');
    if (!this.apiKey) {
      this.logger.warn('NUITEE_API_KEY is not defined — Nuitee flight provider is disabled');
    }
  }

  private headers(): Record<string, string> {
    return {
      'Content-Type': 'application/json',
      'X-API-Key': this.apiKey!,
    };
  }

  private async nuiteeFetch(path: string, init: RequestInit): Promise<any> {
    const response = await fetch(`${NUITEE_BASE_URL}${path}`, {
      ...init,
      signal: AbortSignal.timeout(FLIGHT_SEARCH_TIMEOUT_MS),
    });
    const text = await response.text();
    let body: any;
    try {
      body = JSON.parse(text);
    } catch {
      throw new Error(`Nuitee flights returned non-JSON (${response.status}): ${text.slice(0, 120)}`);
    }
    if (!response.ok) {
      const detail =
        body?.error?.message ?? body?.message ?? JSON.stringify(body).slice(0, 160);
      throw new Error(`Nuitee ${path} failed (${response.status}): ${String(detail)}`);
    }
    return body;
  }

  async searchFlights(params: {
    origin: string;
    destination: string;
    departure: Date;
    returnDate?: Date;
    passengers?: number;
  }): Promise<ProviderResult<any[]>> {
    if (!this.apiKey) {
      return this.disabledResult();
    }

    const dateStr = (value: Date) =>
      (value instanceof Date ? value.toISOString() : String(value)).split('T')[0];

    try {
      // Legs-based itinerary (round-trip = outbound + inbound leg).
      const legs: Array<Record<string, string>> = [
        {
          origin: resolveIataCode(params.origin),
          destination: resolveIataCode(params.destination),
          date: dateStr(params.departure),
          direction: 'OUTBOUND',
        },
      ];
      if (params.returnDate) {
        legs.push({
          origin: resolveIataCode(params.destination),
          destination: resolveIataCode(params.origin),
          date: dateStr(params.returnDate),
          direction: 'INBOUND',
        });
      }

      const response = await this.nuiteeFetch('/flights/rates', {
        method: 'POST',
        headers: this.headers(),
        body: JSON.stringify({
          legs,
          adults: params.passengers ?? 1,
          currency: 'USD',
        }),
      });

      const mapped = this.mapResponse(response, params);
      return {
        success: true,
        providerId: this.providerId,
        providerName: this.providerName,
        data: mapped,
        timestamp: new Date(),
        metadata: { engine: 'flights/rates', source: 'nuitee' },
      };
    } catch (error) {
      return {
        success: false,
        providerId: this.providerId,
        providerName: this.providerName,
        error: `Failed Nuitee flights search: ${(error as Error).message}`,
        data: [],
        timestamp: new Date(),
      };
    }
  }

  /**
   * Maps the documented journeys>offers shape into the shared flight offer
   * format. One offer per (journey, offer) pair — provider offerId is the
   * bookable identity and is preserved verbatim as the offer id + metadata.
   */
  mapResponse(response: any, params: { origin: string; destination: string }) {
    const groups = Array.isArray(response?.data) ? response.data : [];
    const offers: any[] = [];
    for (const group of groups) {
      for (const journey of group?.journeys ?? []) {
        for (const offer of journey?.offers ?? []) {
          const mapped = this.mapOffer(offer, journey, params);
          if (mapped) offers.push(mapped);
        }
      }
    }
    return offers;
  }

  /** Pure mapper — unit-testable without any HTTP. */
  mapOffer(
    offer: any,
    journey: any,
    params: { origin: string; destination: string },
  ) {
    const offerId = offer?.offerId;
    const total = offer?.pricing?.display?.total;
    const currency = offer?.pricing?.display?.currency;
    // Malformed offers are dropped, never invented (3B rule).
    if (typeof offerId !== 'string' || typeof total !== 'number' || !currency) {
      return null;
    }

    const segments: any[] = Array.isArray(journey?.segments) ? journey.segments : [];
    const first = segments[0];
    const last = segments[segments.length - 1];
    const carrier = first?.carrier?.marketingName ?? first?.carrier?.marketingCode;
    const flightNumber = first?.flight?.marketingNumber
      ? `${first?.carrier?.marketingCode ?? ''}${first.flight.marketingNumber}`
      : '';

    return {
      id: offerId,
      type: 'flight',
      providerId: this.providerId,
      providerName: this.providerName,
      title: `${first?.originCode ?? params.origin} → ${last?.destinationCode ?? params.destination}`,
      subtitle: carrier ?? 'Airline',
      origin: first?.originCode ?? params.origin,
      destination: last?.destinationCode ?? params.destination,
      departureTime: first?.departureTime,
      arrivalTime: last?.arrivalTime,
      airline: carrier ?? '',
      flightNumber,
      price: total,
      currency,
      duration: journey?.totalDuration?.iso8601,
      stops: Math.max(0, segments.length - 1),
      fareFamily: offer?.fare?.family,
      refundable: offer?.terms?.refundable ?? undefined,
      // Price provenance (spec point 7): search prices are provisional.
      metadata: {
        providerOfferId: offerId,
        journeyKey: journey?.journeyKey,
        retrievedAt: new Date().toISOString(),
        expiresAt:
          offer?.expiration ?? new Date(Date.now() + 30 * 60 * 1000).toISOString(),
        // 3D — verbatim detail fields for the details page (never invented).
        fareFamily: offer?.fare?.family,
        refundable: offer?.terms?.refundable ?? undefined,
        baggage: offer?.baggage ?? undefined,
      },
    };
  }

  async prebookFlight(payload: {
    offerId: string;
    contact: { firstName: string; lastName: string; email: string; phoneCountryCode: string; phoneNumber: string };
    passengers: Array<{ passengerType: number | string; firstName: string; lastName: string; birthday?: string; gender?: string; nationality?: string; documentType?: string; documentNumber?: string; documentIssueCountry?: string; documentExpiry?: string }>;
    usePaymentSdk?: boolean;
  }): Promise<{ success: boolean; prebookId?: string; transactionId?: string; servicesAttachable?: any; price?: number; currency?: string; error?: string; timestamp?: Date }> {
    if (!this.apiKey) return { success: false, error: 'NUITEE_API_KEY missing' };
    try {
      const response = await this.nuiteeFetch('/flights/prebooks', {
        method: 'POST',
        headers: this.headers(),
        body: JSON.stringify({
          offerId: payload.offerId,
          contact: payload.contact,
          passengers: payload.passengers,
          usePaymentSdk: payload.usePaymentSdk ?? false,
        }),
      });
      const data = response?.data ?? response;
      const booking = data?.booking ?? data?.data?.booking;
      const price = booking?.journey?.price;
      return {
        success: true,
        prebookId: data?.prebookId,
        transactionId: data?.transactionId,
        servicesAttachable: data?.servicesAttachable ?? undefined,
        // The prebook response carries the journey price — the ONLY
        // provider-side price source for a flight offer. Absent stays absent.
        price: typeof price?.total === 'number' ? price.total : undefined,
        currency: typeof price?.currency === 'string' ? price.currency : undefined,
        timestamp: new Date(),
      };
    } catch (error: any) {
      return { success: false, error: `Nuitee flight prebook failed: ${error.message}` };
    }
  }

  /**
   * Read-only offer verification — `POST /flights/verify`.
   *
   * LiteAPI's documented pre-booking check: "Confirm a flight offer is still
   * available and retrieve the latest pricing before proceeding to booking."
   * It takes ONLY the offerId (no passenger identities, no inventory hold), so
   * it is the legitimate review-stage price source. A 404 means the offer
   * expired; a `changes` block means the provider itself reports a price or
   * fare move since the search.
   */
  async verifyFlightOffer(offerId: string): Promise<{
    success: boolean;
    price?: number;
    currency?: string;
    available?: boolean;
    priceChanged?: boolean;
    oldPrice?: number;
    newPrice?: number;
    expiresAt?: string;
    error?: string;
    timestamp?: Date;
  }> {
    if (!this.apiKey) return { success: false, error: 'NUITEE_API_KEY missing' };
    try {
      const response = await this.nuiteeFetch('/flights/verify', {
        method: 'POST',
        headers: this.headers(),
        body: JSON.stringify({ offerId }),
      });
      const results = Array.isArray(response?.data) ? response.data : [];
      const first = results[0];
      const journey = first?.journey;
      const display = journey?.pricing?.display;
      const price = typeof display?.total === 'number' ? display.total : undefined;
      const currency =
        typeof display?.currency === 'string' ? display.currency : undefined;
      const changes = first?.changes;
      const changesOld =
        typeof changes?.pricing?.old?.display?.total === 'number'
          ? changes.pricing.old.display.total
          : undefined;
      const changesNew =
        typeof changes?.pricing?.new?.display?.total === 'number'
          ? changes.pricing.new.display.total
          : undefined;
      return {
        success: true,
        price,
        currency,
        available: price !== undefined && price > 0,
        // The provider's OWN search-vs-verified comparison — the only
        // apples-to-apples price signal for this offer.
        priceChanged: changes?.priceChanged === true,
        oldPrice: changesOld,
        newPrice: changesNew,
        expiresAt: journey?.expiration,
        timestamp: new Date(),
      };
    } catch (error: any) {
      return {
        success: false,
        error: `Nuitee flight verify failed: ${error.message}`,
        timestamp: new Date(),
      };
    }
  }

  /**
   * Read-only prebook retrieval — `GET /flights/prebooks/{prebookId}`.
   *
   * Returns the SAME `FlightPrebookData` shape as `POST /flights/prebooks`
   * (journey, pricing, payment intent, servicesAttachable). It creates no
   * inventory hold, so the review stage can validate an existing prebook and
   * read its frozen quote without prebooking a second time. A 404 means the
   * prebook is gone — the caller must fail closed, never reuse it.
   */
  async getFlightPrebook(prebookId: string): Promise<{
    success: boolean;
    prebookId?: string;
    transactionId?: string;
    price?: number;
    currency?: string;
    available?: boolean;
    expiresAt?: string;
    error?: string;
    timestamp?: Date;
  }> {
    if (!this.apiKey) return { success: false, error: 'NUITEE_API_KEY missing' };
    try {
      const response = await this.nuiteeFetch(
        `/flights/prebooks/${encodeURIComponent(prebookId)}`,
        { method: 'GET', headers: this.headers() },
      );
      const data = response?.data ?? response;
      // The prebook payload is an object in the documented contract; accept a
      // single-element array too so a wrapper change cannot silently yield
      // `price: undefined`.
      const payload = Array.isArray(data) ? data[0] : data;
      const booking = payload?.booking ?? payload?.data?.booking ?? payload;
      const journey = booking?.journey ?? payload?.journey;
      const legacyPrice = journey?.price;
      const display = journey?.pricing?.display;
      const total =
        typeof legacyPrice?.total === 'number'
          ? legacyPrice.total
          : typeof display?.total === 'number'
            ? display.total
            : undefined;
      const currency =
        typeof legacyPrice?.currency === 'string'
          ? legacyPrice.currency
          : typeof display?.currency === 'string'
            ? display.currency
            : undefined;
      return {
        success: true,
        prebookId: payload?.prebookId ?? prebookId,
        transactionId: payload?.transactionId,
        price: total,
        currency,
        available: total !== undefined && total > 0,
        expiresAt: payload?.servicesAttachable?.expiresAt,
        timestamp: new Date(),
      };
    } catch (error: any) {
      return {
        success: false,
        error: `Nuitee flight prebook lookup failed: ${error.message}`,
        timestamp: new Date(),
      };
    }
  }

  async bookFlight(payload: {
    prebookId: string;
    payment: { method: string; token?: string; transactionId?: string };
  }): Promise<{ success: boolean; bookingId?: string; bookingRef?: string; status?: string; order?: any; error?: string; timestamp?: Date }> {
    if (!this.apiKey) return { success: false, error: 'NUITEE_API_KEY missing' };
    try {
      const response = await this.nuiteeFetch('/flights/bookings', {
        method: 'POST',
        headers: this.headers(),
        body: JSON.stringify({
          prebookId: payload.prebookId,
          payment: payload.payment,
        }),
      });
      const data = response?.data ?? response;
      return {
        success: true,
        bookingId: data?.bookingId,
        bookingRef: data?.bookingRef,
        status: data?.status,
        order: data?.order,
        timestamp: new Date(),
      };
    } catch (error: any) {
      return { success: false, error: `Nuitee flight book failed: ${error.message}` };
    }
  }

  async trackFlightBooking(bookingId: string): Promise<{ success: boolean; status?: string; bookingRef?: string; error?: string; timestamp?: Date }> {
    if (!this.apiKey) return { success: false, error: 'NUITEE_API_KEY missing' };
    try {
      const response = await this.nuiteeFetch(`/flights/bookings/${bookingId}`, { method: 'GET', headers: this.headers() });
      const data = response?.data ?? response;
      return { success: true, status: data?.status ?? 'UNKNOWN', bookingRef: data?.bookingRef, timestamp: new Date() };
    } catch (error: any) {
      return { success: false, error: `Nuitee flight track failed: ${error.message}`, timestamp: new Date() };
    }
  }

  private disabledResult(): ProviderResult<any[]> {
    return {
      success: false,
      providerId: this.providerId,
      providerName: this.providerName,
      data: [],
      error: 'NUITEE_API_KEY missing',
      timestamp: new Date(),
    };
  }
}
