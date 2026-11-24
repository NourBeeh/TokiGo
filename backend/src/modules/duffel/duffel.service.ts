import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Duffel } from '@duffel/api';
import {
  termsFromNormalizedFlightOffer,
  termsVersionOf,
} from '../../common/pricing/offer-terms';
import { FlightProvider } from '../../common/providers/flight.provider';
import { ProviderResult } from '../../common/providers/provider.result';
import { flightDesignator } from '../providers/flight-itinerary';

export const CITY_TO_IATA: Record<string, string> = {
  // Egypt
  'cairo': 'CAI', 'القاهرة': 'CAI', 'القاهره': 'CAI', 'مصر': 'CAI', 'cai': 'CAI',
  'alexandria': 'HBE', 'الاسكندرية': 'HBE', 'الإسكندرية': 'HBE', 'الاسكندريه': 'HBE',
  'hurghada': 'HRG', 'الغردقة': 'HRG', 'الغردقه': 'HRG',
  'sharm el sheikh': 'SSH', 'شرم الشيخ': 'SSH',
  'luxor': 'LXR', 'الأقصر': 'LXR', 'الاقصر': 'LXR',
  'aswan': 'ASW', 'أسوان': 'ASW', 'اسوان': 'ASW',
  'marsa alam': 'RMF', 'مرسى علم': 'RMF', 'مرسي علم': 'RMF',

  // UAE
  'dubai': 'DXB', 'دبي': 'DXB', 'dxb': 'DXB',
  'abu dhabi': 'AUH', 'أبوظبي': 'AUH', 'ابوظبي': 'AUH', 'auh': 'AUH',
  'sharjah': 'SHJ', 'الشارقة': 'SHJ', 'الشارقه': 'SHJ',

  // Saudi Arabia
  'riyadh': 'RUH', 'الرياض': 'RUH', 'ruh': 'RUH',
  'jeddah': 'JED', 'جدة': 'JED', 'جده': 'JED', 'jed': 'JED',
  'dammam': 'DMM', 'الدمام': 'DMM', 'dmm': 'DMM',
  'medina': 'MED', 'المدينة': 'MED', 'المدينة المنورة': 'MED', 'المدينه': 'MED',
  'mecca': 'JED', 'مكة': 'JED', 'مكة المكرمة': 'JED', 'مكه': 'JED',

  // UK & Europe
  'london': 'LHR', 'لندن': 'LHR', 'lhr': 'LHR', 'gatwick': 'LGW', 'lgw': 'LGW',
  'paris': 'CDG', 'باريس': 'CDG', 'cdg': 'CDG',
  'rome': 'FCO', 'روما': 'FCO', 'fco': 'FCO',
  'milan': 'MXP', 'ميلان': 'MXP', 'ميلانو': 'MXP', 'mxp': 'MXP',
  'madrid': 'MAD', 'مدريد': 'MAD', 'mad': 'MAD',
  'barcelona': 'BCN', 'برشلونة': 'BCN', 'برشلونه': 'BCN', 'bcn': 'BCN',
  'amsterdam': 'AMS', 'أمستردام': 'AMS', 'امستردام': 'AMS', 'ams': 'AMS',
  'berlin': 'BER', 'برلين': 'BER', 'ber': 'BER',
  'frankfurt': 'FRA', 'فرانكفورت': 'FRA', 'fra': 'FRA',
  'munich': 'MUC', 'ميونخ': 'MUC', 'ميونيخ': 'MUC', 'muc': 'MUC',
  'vienna': 'VIE', 'فيينا': 'VIE', 'vie': 'VIE',
  'istanbul': 'IST', 'اسطنبول': 'IST', 'إسطنبول': 'IST', 'ist': 'IST',
  'athens': 'ATH', 'أثينا': 'ATH', 'اثينا': 'ATH', 'ath': 'ATH',
  // Snow-relevant airports (Gudauri/Shahdag have none and stay unmapped).
  'innsbruck': 'INN', 'tbilisi': 'TBS', 'تبليسي': 'TBS',
  'baku': 'GYD', 'باكو': 'GYD',
  'almaty': 'ALA', 'sapporo': 'CTS', 'rovaniemi': 'RVN', 'tromso': 'TOS',

  // USA & Americas
  'new york': 'JFK', 'نيويورك': 'JFK', 'jfk': 'JFK', 'nyc': 'JFK',
  'los angeles': 'LAX', 'لوس انجلوس': 'LAX', 'لوس أنجلوس': 'LAX', 'lax': 'LAX',
  'chicago': 'ORD', 'شيكاغو': 'ORD', 'ord': 'ORD',
  'miami': 'MIA', 'ميامي': 'MIA', 'mia': 'MIA',
  'san francisco': 'SFO', 'سان فرانسيسكو': 'SFO', 'sfo': 'SFO',
  'toronto': 'YYZ', 'تورونتو': 'YYZ', 'yyz': 'YYZ',

  // Middle East & North Africa
  'doha': 'DOH', 'الدوحة': 'DOH', 'الدوحه': 'DOH', 'قطر': 'DOH', 'doh': 'DOH',
  'kuwait': 'KWI', 'الكويت': 'KWI', 'kwi': 'KWI',
  'manama': 'BAH', 'المنامة': 'BAH', 'المنامه': 'BAH', 'البحرين': 'BAH', 'bah': 'BAH',
  'muscat': 'MCT', 'مسقط': 'MCT', 'عمان': 'MCT', 'سلطنة عمان': 'MCT', 'mct': 'MCT',
  'amman': 'AMM', 'عمان الأردن': 'AMM', 'عمّان': 'AMM', 'الأردن': 'AMM', 'amm': 'AMM',
  'beirut': 'BEY', 'بيروت': 'BEY', 'لبنان': 'BEY', 'bey': 'BEY',
  'casablanca': 'CMN', 'الدار البيضاء': 'CMN', 'كازابلانكا': 'CMN', 'المغرب': 'CMN', 'cmn': 'CMN',
  'tunis': 'TUN', 'تونس': 'TUN', 'tun': 'TUN',
  'algiers': 'ALG', 'الجزائر': 'ALG', 'alg': 'ALG',

  // Asia
  'tokyo': 'HND', 'طوكيو': 'HND', 'hnd': 'HND', 'nrt': 'NRT',
  'bangkok': 'BKK', 'بانكوك': 'BKK', 'تايلاند': 'BKK', 'bkk': 'BKK',
  'singapore': 'SIN', 'سنغافورة': 'SIN', 'سنغافوره': 'SIN', 'sin': 'SIN',
  'kuala lumpur': 'KUL', 'كوالالمبور': 'KUL', 'ماليزيا': 'KUL', 'kul': 'KUL',
};

export function resolveIataCode(input: string): string {
  if (!input) return '';
  const trimmed = input.trim().toLowerCase();
  if (CITY_TO_IATA[trimmed]) {
    return CITY_TO_IATA[trimmed];
  }
  // If it's already a 3-letter string, return it in uppercase
  if (/^[a-zA-Z]{3}$/.test(trimmed)) {
    return trimmed.toUpperCase();
  }
  return input.trim().toUpperCase();
}

/**
 * Maps a search party to Duffel's offer-request passenger entries.
 *
 * Pure and exported for unit testing: the type/age mapping IS the provider
 * contract, and an adult-only array would silently drop child/infant pricing.
 * `passengers` is the adult-count fallback both flight providers use. A
 * missing age keeps the type (Duffel validates it) — never an invented age.
 */
export function buildDuffelPassengerEntries(params: {
  passengers?: number;
  adults?: number;
  children?: number;
  infants?: number;
  childAges?: number[];
  infantAges?: number[];
}): any[] {
  const adultsCount = params.adults ?? params.passengers ?? 1;
  const childrenCount = params.children ?? 0;
  const infantsCount = params.infants ?? 0;
  const childAges = params.childAges ?? [];
  const infantAges = params.infantAges ?? [];

  const passengerEntries: any[] = [];
  for (let i = 0; i < adultsCount; i++) {
    passengerEntries.push({ type: 'adult' });
  }
  for (let i = 0; i < childrenCount; i++) {
    const age = childAges[i];
    passengerEntries.push(age != null ? { type: 'child', age } : { type: 'child' });
  }
  for (let i = 0; i < infantsCount; i++) {
    const age = infantAges[i];
    passengerEntries.push(
      age != null
        ? { type: 'infant_without_seat', age }
        : { type: 'infant_without_seat' },
    );
  }
  return passengerEntries;
}

function nonEmptyString(value: any): string | null {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  return trimmed ? trimmed : null;
}

function amountOf(value: any): number | null {
  const number =
    typeof value === 'number' ? value : Number.parseFloat(String(value ?? ''));
  return Number.isFinite(number) ? number : null;
}

interface DuffelCondition {
  allowed: boolean | null;
  penaltyAmount: number | null;
  penaltyCurrency: string | null;
}

function mapDuffelCondition(value: any): DuffelCondition | null {
  if (!value || typeof value !== 'object') return null;
  return {
    allowed: typeof value.allowed === 'boolean' ? value.allowed : null,
    penaltyAmount: amountOf(value.penalty_amount),
    penaltyCurrency: nonEmptyString(value.penalty_currency),
  };
}

/**
 * Offer-level conditions are authoritative. Duffel also exposes slice-level
 * conditions; they are used only when EVERY slice agrees, otherwise the
 * combined condition is unknown (null), never guessed.
 */
function duffelCondition(
  offer: any,
  key: 'refund_before_departure' | 'change_before_departure',
): DuffelCondition | null {
  const direct = offer?.conditions?.[key];
  if (direct && typeof direct === 'object') {
    return mapDuffelCondition(direct);
  }
  const slices = Array.isArray(offer?.slices) ? offer.slices : [];
  if (slices.length === 0) return null;
  const values = slices.map((slice: any) => slice?.conditions?.[key]);
  if (values.some((value: any) => !value || typeof value !== 'object')) {
    return null;
  }
  const first = JSON.stringify(values[0]);
  if (values.some((value: any) => JSON.stringify(value) !== first)) {
    return null;
  }
  return mapDuffelCondition(values[0]);
}

interface DuffelSegmentBaggage {
  known: boolean;
  allowances: Array<{ type: string; quantity: number }>;
}

/**
 * Duffel states baggage per segment per passenger. A segment whose passenger
 * entries carry no `baggages` array is UNKNOWN, not "no bag"; an empty array
 * is a known "none included". The offer-level summary uses the minimum every
 * passenger is guaranteed, so a row can never overstate an allowance.
 */
function duffelSegmentBaggage(segment: any): DuffelSegmentBaggage {
  const passengers = Array.isArray(segment?.passengers)
    ? segment.passengers
    : [];
  if (passengers.length === 0) return { known: false, allowances: [] };
  if (passengers.some((p: any) => !Array.isArray(p?.baggages))) {
    return { known: false, allowances: [] };
  }

  const perPassenger: any[][] = passengers.map((p: any) => p.baggages);
  const types = new Set<string>();
  for (const list of perPassenger) {
    for (const bag of list) {
      const type = nonEmptyString(bag?.type);
      if (type) types.add(type);
    }
  }

  const allowances: Array<{ type: string; quantity: number }> = [];
  for (const type of types) {
    const quantities = perPassenger.map((list) =>
      list
        .filter((bag: any) => bag?.type === type)
        .reduce((sum: number, bag: any) => {
          const quantity =
            typeof bag?.quantity === 'number' &&
            Number.isFinite(bag.quantity) &&
            bag.quantity > 0
              ? Math.trunc(bag.quantity)
              : 0;
          return sum + quantity;
        }, 0),
    );
    const minimum = Math.min(...quantities);
    if (minimum > 0) allowances.push({ type, quantity: minimum });
  }
  return { known: true, allowances };
}

/**
 * Maps one Duffel offer into the shared normalized flight shape.
 *
 * Every field is provider truth: no `USD` fallback, no zero price, no
 * invented departure time, no placeholder airline. An offer that cannot be
 * mapped faithfully returns null and is dropped instead of being shown as a
 * fake itinerary.
 */
export function mapDuffelOffer(
  offer: any,
  providerId: string,
  providerName: string,
): any | null {
  if (!offer || typeof offer !== 'object') return null;
  const id = nonEmptyString(offer.id);
  const total = amountOf(offer.total_amount);
  const currency = nonEmptyString(offer.total_currency);
  if (!id || total === null || total <= 0 || !currency) return null;

  const slices = Array.isArray(offer.slices) ? offer.slices : [];
  if (slices.length === 0) return null;

  const segments: any[] = [];
  const baggageKnownBySegment: boolean[] = [];
  for (let sliceIndex = 0; sliceIndex < slices.length; sliceIndex++) {
    const slice = slices[sliceIndex];
    const sliceSegments = Array.isArray(slice?.segments) ? slice.segments : [];
    if (sliceSegments.length === 0) return null;
    for (
      let segmentIndex = 0;
      segmentIndex < sliceSegments.length;
      segmentIndex++
    ) {
      const segment = sliceSegments[segmentIndex];
      const origin = nonEmptyString(segment?.origin?.iata_code);
      const destination = nonEmptyString(segment?.destination?.iata_code);
      const departureAt = nonEmptyString(segment?.departing_at);
      const arrivalAt = nonEmptyString(segment?.arriving_at);
      if (!origin || !destination || !departureAt || !arrivalAt) return null;

      const passenger = Array.isArray(segment?.passengers)
        ? segment.passengers[0]
        : undefined;
      const baggage = duffelSegmentBaggage(segment);
      baggageKnownBySegment.push(baggage.known);

      segments.push({
        sliceIndex,
        segmentIndex,
        origin,
        destination,
        departureAt,
        arrivalAt,
        marketingCarrier: {
          code: nonEmptyString(segment?.marketing_carrier?.iata_code) ?? '',
          name: nonEmptyString(segment?.marketing_carrier?.name) ?? '',
        },
        operatingCarrier: {
          code: nonEmptyString(segment?.operating_carrier?.iata_code) ?? '',
          name: nonEmptyString(segment?.operating_carrier?.name) ?? '',
        },
        marketingFlightNumber:
          nonEmptyString(segment?.marketing_carrier_flight_number) ?? '',
        operatingFlightNumber:
          nonEmptyString(segment?.operating_carrier_flight_number) ?? '',
        // Duffel's `stops` are technical stops inside one flight number; an
        // absent list means none.
        stopCount: Array.isArray(segment?.stops) ? segment.stops.length : 0,
        cabinClass: nonEmptyString(passenger?.cabin_class),
        cabinClassMarketingName: nonEmptyString(
          passenger?.cabin_class_marketing_name,
        ),
        fareBasisCode: nonEmptyString(passenger?.fare_basis_code),
        aircraft:
          nonEmptyString(segment?.aircraft?.name) ??
          nonEmptyString(segment?.aircraft?.iata_code),
        duration: nonEmptyString(segment?.duration),
        baggage: baggage.allowances,
      });
    }
  }

  const first = segments[0];
  const last = segments[segments.length - 1];

  // What the passenger sees is the marketing carrier; the owner is only a
  // fallback. Never a placeholder airline string.
  const airline =
    first.marketingCarrier.name ||
    nonEmptyString(offer.owner?.name) ||
    first.operatingCarrier.name ||
    '';
  const flightNumber =
    flightDesignator(
      first.marketingCarrier.code,
      first.marketingFlightNumber,
    ) ||
    flightDesignator(
      first.operatingCarrier.code,
      first.operatingFlightNumber,
    );

  // A multi-city offer names the whole chain, never only its first hop.
  const chain: string[] = [];
  for (const slice of slices) {
    const origin = nonEmptyString(slice?.origin?.iata_code);
    if (origin) chain.push(origin);
  }
  const finalDestination =
    nonEmptyString(slices[slices.length - 1]?.destination?.iata_code) ??
    last.destination;
  if (finalDestination) chain.push(finalDestination);
  const title =
    chain.length > 2 ? chain.join(' → ') : `${first.origin} → ${last.destination}`;

  // Connections are between segments of one slice; technical stops are inside
  // a segment. Both are stops the traveller experiences.
  const connections = Math.max(0, segments.length - slices.length);
  const technicalStops = segments.reduce(
    (sum, segment) =>
      sum +
      (typeof segment.stopCount === 'number' ? segment.stopCount : 0),
    0,
  );

  const cabinClasses = new Set(
    segments
      .map((segment) => segment.cabinClass)
      .filter((value: any): value is string => Boolean(value)),
  );
  const mixedCabin = cabinClasses.size > 1;
  const cabinClass =
    cabinClasses.size === 1 ? [...cabinClasses][0] : undefined;

  const sliceFareBrands = slices
    .map((slice: any) => nonEmptyString(slice?.fare_brand_name))
    .filter((value: any): value is string => Boolean(value));
  const uniqueFareBrands = new Set(sliceFareBrands);
  // A mixed-brand round trip has no single honest top-level brand; each
  // segment still carries its own slice brand in `sliceFareBrands`.
  const fareBrand =
    uniqueFareBrands.size === 1 ? [...uniqueFareBrands][0] : undefined;

  const refund = duffelCondition(offer, 'refund_before_departure');
  const change = duffelCondition(offer, 'change_before_departure');
  const conditions =
    refund || change
      ? {
          refundBeforeDeparture: refund,
          changeBeforeDeparture: change,
        }
      : undefined;

  // Offer-level baggage is stated only when every segment's allowance is
  // known; per-segment lists stay on each segment.
  let baggageAllowances: Array<{ type: string; quantity: number }> = [];
  if (
    baggageKnownBySegment.length > 0 &&
    baggageKnownBySegment.every(Boolean)
  ) {
    const types = new Set<string>();
    for (const segment of segments) {
      for (const bag of segment.baggage) types.add(bag.type);
    }
    for (const type of types) {
      const quantities = segments.map((segment) =>
        segment.baggage
          .filter((bag: any) => bag.type === type)
          .reduce(
            (sum: number, bag: any) =>
              sum + (typeof bag.quantity === 'number' ? bag.quantity : 0),
            0,
          ),
      );
      const minimum = Math.min(...quantities);
      if (minimum > 0) baggageAllowances.push({ type, quantity: minimum });
    }
  }

  const seatsLeft =
    typeof offer.number_of_bookable_seats === 'number' &&
    Number.isFinite(offer.number_of_bookable_seats)
      ? offer.number_of_bookable_seats
      : undefined;

  const connectionAirports: string[] = [];
  for (let sliceIndex = 0; sliceIndex < slices.length; sliceIndex++) {
    const sliceSegments = segments.filter(
      (segment) => segment.sliceIndex === sliceIndex,
    );
    for (let i = 1; i < sliceSegments.length; i++) {
      connectionAirports.push(sliceSegments[i - 1].destination);
    }
  }

  const expiresAt = nonEmptyString(offer.expires_at);
  const comparisonKey = nonEmptyString(slices[0]?.comparison_key);
  const firstAircraft = first.aircraft;
  const legacyBaggage =
    baggageAllowances.length > 0
      ? {
          type: baggageAllowances[0].type,
          quantity: baggageAllowances[0].quantity,
        }
      : undefined;

  return {
    id,
    type: 'flight',
    providerId,
    providerName,
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
    duration: nonEmptyString(slices[0]?.duration) ?? undefined,
    stops: Math.max(0, connections + technicalStops),
    cabinClass,
    fareBrand,
    conditions,
    baggageAllowances,
    segments,
    ...(expiresAt ? { validUntil: expiresAt } : {}),
    metadata: {
      providerOfferId: id,
      retrievedAt: new Date().toISOString(),
      ...(expiresAt ? { expiresAt } : {}),
      ...(fareBrand ? { fareFamily: fareBrand } : {}),
      ...(refund && refund.allowed !== null
        ? { refundable: refund.allowed }
        : {}),
      ...(change && change.allowed !== null
        ? { changeable: change.allowed }
        : {}),
      ...(seatsLeft !== undefined ? { seatsLeft } : {}),
      ...(cabinClass ? { cabinClass } : {}),
      ...(first.fareBasisCode ? { fareBasisCode: first.fareBasisCode } : {}),
      ...(firstAircraft ? { aircraft: firstAircraft } : {}),
      ...(comparisonKey ? { comparisonKey } : {}),
      ...(connectionAirports.length > 0
        ? {
            stopAirport: connectionAirports[0],
            connectionAirports,
          }
        : {}),
      ...(sliceFareBrands.length > 0 ? { sliceFareBrands } : {}),
      ...(mixedCabin ? { mixedCabin: true } : {}),
      ...(technicalStops > 0 ? { technicalStops } : {}),
      ...(legacyBaggage ? { baggage: legacyBaggage } : {}),
    },
  };
}

@Injectable()
export class DuffelService implements FlightProvider {
  providerId = 'duffel-flight';
  providerName = 'Duffel Flight Provider';
  
  private duffelClient?: Duffel;

  constructor(private configService: ConfigService) {
    const apiKey = this.configService.get<string>('DUFFEL_ACCESS_TOKEN') || this.configService.get<string>('DUFFEL_API_KEY');
    if (!apiKey) {
      console.warn('DUFFEL_ACCESS_TOKEN (and DUFFEL_API_KEY as fallback) are not defined - Duffel flights will be disabled');
    } else {
      this.duffelClient = new Duffel({ token: apiKey });
    }
  }

  async searchFlights(params: {
    origin: string;
    destination: string;
    departure: Date;
    returnDate?: Date;
    passengers?: number;
    adults?: number;
    children?: number;
    infants?: number;
    childAges?: number[];
    infantAges?: number[];
    cabinClass?: string;
    directOnly?: boolean;
  }): Promise<ProviderResult<any[]>> {
    if (!this.duffelClient) {
      return {
        success: true,
        providerId: this.providerId,
        providerName: this.providerName,
        data: [],
        timestamp: new Date(),
      };
    }

    try {
      const originCode = resolveIataCode(params.origin);
      const destCode = resolveIataCode(params.destination);
      const departureDate = params.departure instanceof Date 
        ? params.departure.toISOString().split('T')[0]
        : String(params.departure).split('T')[0];
      const passengerEntries = buildDuffelPassengerEntries(params);

      // A multi-city itinerary is one slice per leg, in order. The legacy
      // single triple stays a one-slice request.
      const legs: any[] = Array.isArray((params as any).legs)
        ? (params as any).legs
        : [];
      const slices =
        legs.length > 0
          ? legs.map((leg: any) => ({
              origin: resolveIataCode(leg.origin),
              destination: resolveIataCode(leg.destination),
              departure_date:
                leg.date instanceof Date
                  ? leg.date.toISOString().split('T')[0]
                  : String(leg.date).split('T')[0],
            }))
          : [
              {
                origin: originCode,
                destination: destCode,
                departure_date: departureDate,
              },
            ];

      // Create offer request with Duffel API
      const cabinClass = params.cabinClass?.trim().toLowerCase();
      const directOnly = params.directOnly === true;
      const request = await this.duffelClient?.offerRequests.create({
        slices: slices as any[],
        passengers: passengerEntries,
        return_offers: true,
        // Cabin class the traveller picked in the Flights form; Duffel
        // honours it verbatim and prices/offers accordingly. Absent ⇒ Duffel
        // default (economy), matching the client-side default.
        ...(cabinClass
          ? { cabin_class: cabinClass as any }
          : {}),
        // Non-stop only: Duffel caps any slice's connection count at 0.
        ...(directOnly ? { max_connections: 0 } : {}),
      });

      // Map every Duffel offer through the shared contract mapper: complete
      // ordered segments, marketing/operating carriers (codeshares), tri-state
      // conditions, per-segment baggage, fare brand and provider-only expiry.
      // An offer that cannot be mapped faithfully is dropped instead of being
      // shown as a fake flight with invented price/airline/times.
      const mappedOffers = (request?.data?.offers || [])
        .map((offer: any) =>
          mapDuffelOffer(offer, this.providerId, this.providerName),
        )
        .filter((offer: any): offer is any => offer !== null);

      return {
        success: true,
        providerId: this.providerId,
        providerName: this.providerName,
        data: mappedOffers,
        timestamp: new Date(),
      };
    } catch (error) {
      return {
        success: false,
        providerId: this.providerId,
        providerName: this.providerName,
        error: `Failed to search flights: ${(error as Error).message}`,
        data: [],
        timestamp: new Date(),
      };
    }
  }

  // Legacy method for backward compatibility with existing AI service
  async searchFlightsLegacy(originIata: string, destinationIata: string, departureDate: string, passengersCount: number) {
    const params = {
      origin: originIata,
      destination: destinationIata,
      departure: new Date(departureDate),
      passengers: passengersCount,
    };
    const result = await this.searchFlights(params);
    return { offers: result.data };
  }

  async createOrder(
    offerId: string,
    passengers: any[],
    payments: any[],
    metadata?: Record<string, string>,
  ) {
    if (!this.duffelClient) {
      throw new Error('Duffel API is not configured - cannot create booking');
    }
    // An instant order without a payment is not a booking. Refuse before the
    // provider call instead of silently sending `payments: []`.
    if (!Array.isArray(payments) || payments.length === 0) {
      throw new Error(
        'Duffel instant order requires at least one payment instrument',
      );
    }

    try {
      const response = await this.duffelClient.orders.create({
        type: 'instant',
        selected_offers: [offerId],
        passengers,
        payments,
        ...(metadata && Object.keys(metadata).length > 0 ? { metadata } : {}),
      });
      return response.data;
    } catch (error) {
      throw new Error(`Failed to create booking: ${(error as Error).message}`);
    }
  }

  /**
   * Revalidation (spec points 7-8): fetch the live offer and return its
   * authoritative price/availability + expiry. The caller (offers
   * controller) compares against the known price and produces a structured
   * PRICE_CHANGED outcome instead of charging silently.
   *
   * P3-D5: the offer ALSO carries the passenger list created by the original
   * offer request (`Offer.passengers[].id`). Those ids are the ONLY valid
   * `id` values on an order passenger, and they are recoverable from the
   * stored offer id alone — so they are surfaced here and persisted in the
   * booking snapshot instead of being dropped at search time.
   */
  async revalidateOffer(offerId: string): Promise<ProviderResult<any>> {
    if (!this.duffelClient) {
      return {
        success: false,
        providerId: this.providerId,
        providerName: this.providerName,
        error: 'Duffel API is not configured',
        timestamp: new Date(),
      };
    }
    try {
      const response = await this.duffelClient.offers.get(offerId);
      const offer = response?.data ?? response;
      // Fail closed: a revalidation that cannot read a positive price and the
      // provider's currency is NOT a successful revalidation. Defaulting to
      // USD/0 here would let checkout proceed on a fabricated amount.
      const price = amountOf(offer?.total_amount);
      const currency = nonEmptyString(offer?.total_currency);
      if (price === null || price <= 0 || !currency) {
        return {
          success: false,
          providerId: this.providerId,
          providerName: this.providerName,
          error: 'Duffel offer is missing a usable price or currency',
          timestamp: new Date(),
        };
      }
      const rawPassengers = Array.isArray(offer?.passengers)
        ? offer.passengers
        : [];
      // The normalized offer is the same shape the search results expose, so
      // the live fare/condition facts can be compared to what the customer
      // originally saw. A partial offer yields null; terms then stay unknown.
      const normalized = mapDuffelOffer(
        offer,
        this.providerId,
        this.providerName,
      );
      const terms = termsFromNormalizedFlightOffer(normalized);
      return {
        success: true,
        providerId: this.providerId,
        providerName: this.providerName,
        data: {
          price,
          currency,
          amountText: String(offer.total_amount),
          // Duffel offers expire; expose provider truth when present. No
          // invented fallback window — an expiry we made up would become a
          // fake booking deadline on the client.
          expiresAt: offer?.expires_at ?? undefined,
          available: price > 0,
          rawId: offerId,
          ...(terms
            ? { terms, termsVersion: termsVersionOf(terms) }
            : {}),
          // Verbatim offer passengers (id/type/age). A passenger without a
          // non-empty id is dropped — it can never be booked, and an invented
          // replacement is forbidden.
          passengers: rawPassengers
            .filter(
              (p: any) => p && typeof p.id === 'string' && p.id.length > 0,
            )
            .map((p: any) => ({
              id: p.id,
              type: p.type ?? null,
              age: typeof p.age === 'number' ? p.age : null,
            })),
          // Conditional document requirement, read from the offer itself.
          passengerIdentityDocumentsRequired:
            offer?.passenger_identity_documents_required === true,
          supportedPassengerIdentityDocumentTypes: Array.isArray(
            offer?.supported_passenger_identity_document_types,
          )
            ? offer.supported_passenger_identity_document_types
            : [],
        },
        timestamp: new Date(),
      };
    } catch (error) {
      return {
        success: false,
        providerId: this.providerId,
        providerName: this.providerName,
        error: `Failed to revalidate offer: ${(error as Error).message}`,
        timestamp: new Date(),
      };
    }
  }
}