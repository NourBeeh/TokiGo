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
    passengers: Array<{ passengerType: string; firstName: string; lastName: string; birthday?: string; gender?: string; nationality?: string; documentType?: string; documentNumber?: string; documentIssueCountry?: string; documentExpiry?: string }>;
    usePaymentSdk?: boolean;
  }): Promise<{ success: boolean; prebookId?: string; transactionId?: string; servicesAttachable?: any; error?: string; timestamp?: Date }> {
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
      return {
        success: true,
        prebookId: data?.prebookId,
        transactionId: data?.transactionId,
        servicesAttachable: data?.servicesAttachable ?? undefined,
        timestamp: new Date(),
      };
    } catch (error: any) {
      return { success: false, error: `Nuitee flight prebook failed: ${error.message}` };
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
