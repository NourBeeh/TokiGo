import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { FlightProvider } from '../../common/providers/flight.provider';
import { ProviderResult } from '../../common/providers/provider.result';
import {
  termsFromChangedFlags,
  termsFromNormalizedFlightOffer,
  termsVersionOf,
} from '../../common/pricing/offer-terms';
import { resolveIataCode } from '../duffel/duffel.service';
import { flightDesignator } from '../providers/flight-itinerary';

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

function nonEmptyString(value: any): string | null {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  return trimmed ? trimmed : null;
}

function finiteAmount(value: any): number | null {
  const number = typeof value === 'number' ? value : Number(value);
  return Number.isFinite(number) ? number : null;
}

interface NuiteeCondition {
  allowed: boolean | null;
  penaltyAmount: number | null;
  penaltyCurrency: string | null;
  /** Provider signalled a fee applies even when it published no amount. */
  feeApplies: boolean | null;
}

/**
 * Maps one Nuitee booking-term block. `allowed` is the provider's boolean;
 * a missing boolean is UNKNOWN, never "not allowed". The fee amount is only
 * taken from `pricing.display.amount` (the customer-facing amount), never
 * guessed from `percent` or a sibling field.
 */
function nuiteeCondition(
  terms: any,
  allowedKey: 'refundable' | 'changeable',
  feeKey: 'refundFee' | 'changeFee',
  hasFeeKey: 'hasRefundFee' | 'hasChangeFee',
): NuiteeCondition | null {
  const allowed =
    typeof terms?.[allowedKey] === 'boolean' ? terms[allowedKey] : null;
  const fee = terms?.[feeKey];
  const penaltyAmount = finiteAmount(fee?.pricing?.display?.amount);
  const penaltyCurrency = nonEmptyString(fee?.pricing?.display?.currency);
  const hasFee =
    typeof terms?.[hasFeeKey] === 'boolean' ? terms[hasFeeKey] : null;
  if (allowed === null && penaltyAmount === null && hasFee === null) {
    return null;
  }
  return {
    allowed,
    penaltyAmount,
    penaltyCurrency: penaltyAmount !== null ? penaltyCurrency : null,
    feeApplies:
      hasFee === true || penaltyAmount !== null
        ? true
        : hasFee === false
          ? false
          : null,
  };
}

interface NuiteeBaggageAllowance {
  type: string;
  /** Pieces allowed; null when the provider states a weight-only allowance. */
  quantity: number | null;
  weightKg: number | null;
  description?: string;
  passengerType?: string;
}

function nuiteeBaggageAllowances(offer: any): NuiteeBaggageAllowance[] {
  const included = Array.isArray(offer?.baggage?.included)
    ? offer.baggage.included
    : [];
  const allowances: NuiteeBaggageAllowance[] = [];
  for (const item of included) {
    const type = nonEmptyString(item?.bagType);
    if (!type) continue;
    const pieces = finiteAmount(item?.pieces);
    const weightKg = finiteAmount(item?.weightKg);
    const description = nonEmptyString(item?.description);
    const passengerType = nonEmptyString(item?.passengerType);
    allowances.push({
      type,
      quantity:
        pieces !== null && pieces >= 0 ? Math.trunc(pieces) : null,
      weightKg,
      ...(description ? { description } : {}),
      ...(passengerType ? { passengerType } : {}),
    });
  }
  return allowances;
}

/**
 * Leg index per segment. Nuitee marks each segment with OUTBOUND/INBOUND;
 * a change of direction starts the next leg. Segments without a direction
 * stay in the first leg — never an invented split.
 */
function nuiteeLegIndexes(segments: any[]): number[] {
  const indexes: number[] = [];
  let leg = 0;
  let previousDirection: string | null = null;
  for (let i = 0; i < segments.length; i++) {
    const direction = nonEmptyString(segments[i]?.direction);
    if (i > 0 && direction && previousDirection && direction !== previousDirection) {
      leg++;
    }
    indexes.push(leg);
    if (direction) previousDirection = direction;
  }
  return indexes;
}

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
      const providerCode =
        body?.error?.code ?? body?.error?.errorCode ?? body?.code ?? body?.errorCode;
      const detail =
        body?.error?.message ?? body?.message ?? JSON.stringify(body).slice(0, 160);
      const codeSuffix =
        providerCode === undefined || providerCode === null
          ? ''
          : ` [${String(providerCode)}]`;
      throw new Error(
        `Nuitee ${path} failed (${response.status})${codeSuffix}: ${String(detail)}`,
      );
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

  /**
   * Pure mapper — unit-testable without any HTTP.
   *
   * Every field is provider truth. An offer without a usable id, price,
   * currency or complete ordered segments is DROPPED: a fabricated USD/zero
   * price or a route taken from the request would show a bookable-looking
   * flight the provider never sold.
   */
  mapOffer(
    offer: any,
    journey: any,
    _params: { origin: string; destination: string },
  ) {
    const offerId = nonEmptyString(offer?.offerId);
    const display = offer?.pricing?.display;
    const total = finiteAmount(display?.total);
    const currency = nonEmptyString(display?.currency);
    if (!offerId || total === null || total <= 0 || !currency) {
      return null;
    }

    const rawSegments: any[] = Array.isArray(journey?.segments)
      ? journey.segments
      : [];
    if (rawSegments.length === 0) return null;

    const segmentFares: any[] = Array.isArray(offer?.segmentFares)
      ? offer.segmentFares
      : [];
    const segmentAmenities: any[] = Array.isArray(offer?.segmentAmenities)
      ? offer.segmentAmenities
      : [];
    const legIndexes = nuiteeLegIndexes(rawSegments);
    const segments: any[] = [];

    for (let index = 0; index < rawSegments.length; index++) {
      const segment = rawSegments[index];
      const origin = nonEmptyString(segment?.originCode);
      const destination = nonEmptyString(segment?.destinationCode);
      const departureAt = nonEmptyString(segment?.departureTime);
      const arrivalAt = nonEmptyString(segment?.arrivalTime);
      if (!origin || !destination || !departureAt || !arrivalAt) return null;

      const segmentKey = nonEmptyString(segment?.segmentKey);
      const fare = segmentKey
        ? segmentFares.find((entry: any) => entry?.segmentKey === segmentKey)
        : undefined;
      const amenities = segmentKey
        ? segmentAmenities.find(
            (entry: any) => entry?.segmentKey === segmentKey,
          )
        : undefined;
      const rawStopCount = finiteAmount(segment?.stopCount);
      const stopCount =
        rawStopCount !== null && rawStopCount >= 0
          ? Math.trunc(rawStopCount)
          : null;

      segments.push({
        sliceIndex: legIndexes[index],
        segmentIndex: index,
        segmentKey: segmentKey ?? undefined,
        origin,
        destination,
        departureAt,
        arrivalAt,
        marketingCarrier: {
          code: nonEmptyString(segment?.carrier?.marketingCode) ?? '',
          name: nonEmptyString(segment?.carrier?.marketingName) ?? '',
        },
        operatingCarrier: {
          code: nonEmptyString(segment?.carrier?.operatingCode) ?? '',
          name: nonEmptyString(segment?.carrier?.operatingName) ?? '',
        },
        marketingFlightNumber:
          nonEmptyString(segment?.flight?.marketingNumber) ?? '',
        operatingFlightNumber:
          nonEmptyString(segment?.flight?.operatingNumber) ?? '',
        stopCount,
        cabinClass: nonEmptyString(fare?.cabin),
        fareBasisCode: nonEmptyString(fare?.fareBasisCode),
        aircraft: nonEmptyString(amenities?.aircraftType),
        duration: nonEmptyString(segment?.duration?.iso8601),
      });
    }

    const first = segments[0];
    const last = segments[segments.length - 1];

    // What the passenger sees is the marketing carrier; the operating carrier
    // is only a fallback. Never a placeholder airline string.
    const airline =
      first.marketingCarrier.name || first.operatingCarrier.name || '';
    const flightNumber =
      flightDesignator(
        first.marketingCarrier.code,
        first.marketingFlightNumber,
      ) ||
      flightDesignator(
        first.operatingCarrier.code,
        first.operatingFlightNumber,
      );

    // Leg starts, then the final arrival. A round trip names its return
    // ("JFK → CDG → JFK") instead of pretending the last segment ends abroad.
    const chain: string[] = [first.origin];
    for (let i = 1; i < segments.length; i++) {
      if (legIndexes[i] !== legIndexes[i - 1]) chain.push(segments[i].origin);
    }
    chain.push(last.destination);
    const uniqueChain = chain.filter(
      (code, index) => index === 0 || code !== chain[index - 1],
    );
    const title =
      uniqueChain.length > 2
        ? uniqueChain.join(' → ')
        : `${first.origin} → ${last.destination}`;

    const legCount = new Set(legIndexes).size;
    const connectionCount = Array.isArray(journey?.connections)
      ? journey.connections.length
      : Math.max(0, segments.length - legCount);
    const technicalStops = segments.reduce(
      (sum, segment) =>
        sum + (typeof segment.stopCount === 'number' ? segment.stopCount : 0),
      0,
    );
    const stops = Math.max(0, connectionCount + technicalStops);

    const connectionAirports: string[] = [];
    if (
      Array.isArray(journey?.connections) &&
      journey.connections.length > 0
    ) {
      for (const connection of journey.connections) {
        const code = nonEmptyString(connection?.arrivalAirportCode);
        if (code) connectionAirports.push(code);
      }
    } else {
      for (let i = 1; i < segments.length; i++) {
        if (legIndexes[i] === legIndexes[i - 1]) {
          connectionAirports.push(segments[i - 1].destination);
        }
      }
    }

    const cabins = new Set(
      segments
        .map((segment) => segment.cabinClass)
        .filter((value: any): value is string => Boolean(value)),
    );
    const cabinClass = cabins.size === 1 ? [...cabins][0] : undefined;
    const mixedCabin = offer?.fare?.mixedCabin === true || cabins.size > 1;

    const fareFamily = nonEmptyString(offer?.fare?.family);
    const mixedFareFamily = offer?.fare?.mixedFareFamily === true;
    // When legs are sold under different brands the documented `family`
    // reflects the first leg only; a single top-level brand would misstate
    // the return. The provider's raw label stays in metadata.
    const fareBrand = mixedFareFamily
      ? undefined
      : fareFamily ?? undefined;

    const refund = nuiteeCondition(
      offer?.terms,
      'refundable',
      'refundFee',
      'hasRefundFee',
    );
    const change = nuiteeCondition(
      offer?.terms,
      'changeable',
      'changeFee',
      'hasChangeFee',
    );
    const conditions =
      refund || change
        ? {
            refundBeforeDeparture: refund,
            changeBeforeDeparture: change,
          }
        : undefined;

    const baggageAllowances = nuiteeBaggageAllowances(offer);
    const legacyBaggage = baggageAllowances.find(
      (allowance) =>
        allowance.quantity !== null && allowance.quantity > 0,
    );

    const seatsRemaining = finiteAmount(offer?.fare?.seatsRemaining);
    const termsSummary = Array.isArray(offer?.terms?.summary)
      ? offer.terms.summary
          .map((entry: any) => ({
            level: nonEmptyString(entry?.level),
            message: nonEmptyString(entry?.message),
          }))
          .filter((entry: any) => entry.message)
      : [];

    const expiresAt = nonEmptyString(offer?.expiration);
    const searchId = nonEmptyString(offer?.searchId);
    const firstFareBasisCode = first.fareBasisCode;
    const firstAircraft = first.aircraft;

    return {
      id: offerId,
      type: 'flight',
      providerId: this.providerId,
      providerName: this.providerName,
      title,
      subtitle: airline || null,
      origin: first.origin,
      destination: last.destination,
      departureTime: first.departureAt,
      arrivalTime: last.arrivalAt,
      airline,
      flightNumber,
      price: total,
      currency,
      duration: nonEmptyString(journey?.totalDuration?.iso8601) ?? undefined,
      stops,
      cabinClass,
      fareBrand,
      conditions,
      baggageAllowances,
      segments,
      ...(expiresAt ? { validUntil: expiresAt } : {}),
      // Price provenance (spec point 7): search prices are provisional.
      // `expiresAt` is only carried when Nuitee actually sent one — an
      // invented "30 minutes from now" window would become a fake deadline.
      metadata: {
        providerOfferId: offerId,
        journeyKey: journey?.journeyKey,
        retrievedAt: new Date().toISOString(),
        ...(expiresAt ? { expiresAt } : {}),
        // 3D — verbatim detail fields for the details page (never invented).
        ...(fareFamily ? { fareFamily } : {}),
        ...(mixedFareFamily ? { mixedFareFamily: true } : {}),
        ...(typeof offer?.terms?.refundable === 'boolean'
          ? { refundable: offer.terms.refundable }
          : {}),
        ...(typeof offer?.terms?.changeable === 'boolean'
          ? { changeable: offer.terms.changeable }
          : {}),
        ...(termsSummary.length > 0 ? { termsSummary } : {}),
        ...(legacyBaggage && legacyBaggage.quantity !== null
          ? {
              baggage: {
                type: legacyBaggage.type,
                quantity: legacyBaggage.quantity,
              },
            }
          : {}),
        ...(seatsRemaining !== null && seatsRemaining >= 0
          ? { seatsLeft: Math.trunc(seatsRemaining) }
          : {}),
        ...(cabinClass ? { cabinClass } : {}),
        ...(firstFareBasisCode ? { fareBasisCode: firstFareBasisCode } : {}),
        ...(firstAircraft ? { aircraft: firstAircraft } : {}),
        ...(connectionAirports.length > 0
          ? {
              stopAirport: connectionAirports[0],
              connectionAirports,
            }
          : {}),
        ...(technicalStops > 0 ? { technicalStops } : {}),
        ...(mixedCabin ? { mixedCabin: true } : {}),
        ...(searchId ? { searchId } : {}),
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
    terms?: Record<string, any>;
    termsVersion?: string;
    changedTerms?: string[];
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

      // The verified offer may be nested under `offer`, or the response item
      // itself may carry the documented offer fields. Map only what exists;
      // an absent offer leaves the terms unknown rather than fabricated.
      const offerCandidate =
        first?.offer ??
        (typeof first?.offerId === 'string'
          ? first
          : Array.isArray(journey?.offers)
            ? journey.offers.find(
                (entry: any) => entry?.offerId === offerId,
              )
            : undefined);
      const mapped = offerCandidate
        ? this.mapOffer(offerCandidate, journey, {
            origin: '',
            destination: '',
          })
        : null;
      const terms = termsFromNormalizedFlightOffer(mapped);
      const providerFlags = termsFromChangedFlags(changes);
      const changedTerms = Object.keys(providerFlags);
      const combinedTerms =
        terms || changedTerms.length > 0
          ? { ...(terms ?? {}), ...providerFlags }
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
        ...(combinedTerms
          ? {
              terms: combinedTerms,
              termsVersion: termsVersionOf(combinedTerms),
            }
          : {}),
        ...(changedTerms.length > 0 ? { changedTerms } : {}),
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
    /** Up to five `^[A-Z0-9_-]+$` labels persisted with the booking. */
    customTags?: Record<string, string>;
  }): Promise<{
    success: boolean;
    bookingId?: string;
    bookingRef?: string;
    status?: string;
    amount?: number;
    currency?: string;
    order?: any;
    error?: string;
    timestamp?: Date;
  }> {
    if (!this.apiKey) return { success: false, error: 'NUITEE_API_KEY missing' };
    try {
      const response = await this.nuiteeFetch('/flights/bookings', {
        method: 'POST',
        headers: this.headers(),
        body: JSON.stringify({
          prebookId: payload.prebookId,
          payment: payload.payment,
          ...(payload.customTags && Object.keys(payload.customTags).length > 0
            ? { customTags: payload.customTags }
            : {}),
        }),
      });
      // Documented success shape: `data: [{ booking: FlightBooking, message }]`.
      // A bare object is tolerated for compatibility with older sandbox
      // responses, but the booking is always the object carrying bookingId.
      const entry = Array.isArray(response?.data)
        ? response.data[0]
        : response?.data;
      const booking = entry?.booking ?? entry ?? {};
      const price =
        booking?.journey?.price ?? entry?.price ?? booking?.price ?? {};
      // Prefer a finite provider amount; never fabricate 0/USD.
      const amount =
        typeof price?.total === 'number' && Number.isFinite(price.total)
          ? price.total
          : typeof price?.amount === 'number' && Number.isFinite(price.amount)
            ? price.amount
            : undefined;
      const currency =
        typeof price?.currency === 'string' && price.currency.trim()
          ? price.currency.trim().toUpperCase()
          : undefined;
      return {
        success: true,
        bookingId:
          typeof booking?.bookingId === 'string'
            ? booking.bookingId
            : undefined,
        bookingRef:
          typeof booking?.bookingRef === 'string'
            ? booking.bookingRef
            : undefined,
        status: typeof booking?.status === 'string' ? booking.status : undefined,
        amount,
        currency,
        order: booking,
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
