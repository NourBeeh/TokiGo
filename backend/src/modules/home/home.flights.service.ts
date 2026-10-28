import { Injectable, Logger } from '@nestjs/common';
import { CacheService } from '../cache/cache.service';
import { CITY_TO_IATA } from '../duffel/duffel.service';
import { NuiteeFlightService } from '../nuitee/nuitee.flight.service';
import { HomeService } from './home.service';
import { TRAVEL_MOODS } from '../../common/travel_mood';
import type { TravelMood } from '../../common/travel_mood';

/**
 * Phase 2 — the real flight rail behind a Home travel mood.
 *
 * OWNER DECISION (2026-10-22): Nuitee is now the DEFAULT provider for both
 * flights AND hotels. Duffel is DISABLED temporarily.
 *
 * Until now Home filtered `state.sections` for flight cards that carried
 * `originCountryCode` / `seatsLeft` / `destinationCity` metadata. No producer
 * ever wrote those fields and the database holds zero flight cards, so the
 * "lowest fares" rail was permanently empty. This service produces the rail
 * from live Nuitee offers instead of inventing cards:
 *
 * - the origin is the curated primary airport of the traveller's country
 *   (a suggestion, editable on the flight search page — never a claim about
 *   the nearest airport);
 * - destinations are the published destination cards whose AUTHORED mood
 *   taxonomy contains the requested mood (`metadata.moods`), at most three;
 * - one live Nuitee search per destination, and only the cheapest real offer
 *   with a positive price is returned;
 * - provider failure for a city drops that city — the response is an honest
 *   shorter list, never a fabricated fare;
 * - successful responses are cached for 10 minutes to reduce repeated
 *   provider calls without leaving a fare snapshot stale for long. Booking
 *   truth stays with offer revalidation.
 */

/** The only moods the content model knows (mirrors the Flutter enum). */
export { TRAVEL_MOODS };
export type { TravelMood } from '../../common/travel_mood';

/** Home mood rail cache — keep provider fares fresh across Home visits. */
export const MOOD_FLIGHTS_TTL_SECONDS = 10 * 60;

/** The rail never asks for more than three live searches per request. */
export const MAX_MOOD_CITIES = 3;

/** Stable near-term departure: a two-week scan, not "today's" last seats. */
export const DEPARTURE_DAYS_AHEAD = 14;

/**
 * Curated primary-airport suggestions per country. This mirrors the Flutter
 * `suggestedAirportCodeForCountry` table and is intentionally a *suggestion*:
 * the traveller can change the origin on the flight search page.
 */
export const ORIGIN_AIRPORT_BY_COUNTRY: Record<string, string> = {
  EG: 'CAI',
  AE: 'DXB',
  SA: 'RUH',
  QA: 'DOH',
  KW: 'KWI',
  BH: 'BAH',
  OM: 'MCT',
  JO: 'AMM',
  LB: 'BEY',
  TR: 'IST',
  GB: 'LHR',
  IE: 'DUB',
  FR: 'CDG',
  DE: 'FRA',
  ES: 'MAD',
  IT: 'FCO',
  PT: 'LIS',
  NL: 'AMS',
  BE: 'BRU',
  CH: 'ZRH',
  AT: 'VIE',
  SE: 'ARN',
  NO: 'OSL',
  DK: 'CPH',
  FI: 'HEL',
  PL: 'WAW',
  CZ: 'PRG',
  HU: 'BUD',
  RO: 'OTP',
  GR: 'ATH',
  US: 'JFK',
  CA: 'YYZ',
  BR: 'GRU',
  MA: 'CMN',
  TN: 'TUN',
  DZ: 'ALG',
  ZA: 'JNB',
  KE: 'NBO',
  NG: 'LOS',
  IN: 'DEL',
  TH: 'BKK',
  SG: 'SIN',
  MY: 'KUL',
  ID: 'CGK',
  JP: 'HND',
  KR: 'ICN',
  CN: 'PEK',
  HK: 'HKG',
  AU: 'SYD',
  RU: 'SVO',
};

export interface MoodFlightCard {
  id: string;
  type: 'flight';
  title: string;
  subtitle: string;
  price: number;
  currency: string;
  metadata: Record<string, any>;
}

export interface MoodFlightsPayload {
  /** Suggested origin airport (IATA), or null when the country is unknown. */
  origin: string | null;
  /** Echo of the normalised country, or null when it was not usable. */
  originCountryCode: string | null;
  /** Echo of the requested mood (null when it is outside the taxonomy). */
  mood: TravelMood | null;
  /** The departure date every offer was searched for (yyyy-mm-dd). */
  departureDate: string;
  flights: MoodFlightCard[];
}

@Injectable()
export class HomeFlightsService {
  private readonly logger = new Logger(HomeFlightsService.name);

  constructor(
    private readonly home: HomeService,
    private readonly nuitee: NuiteeFlightService,
    private readonly cache: CacheService,
  ) {}

  async getFlightsForMood(input: {
    country?: string;
    mood?: string;
    limit?: number;
  }): Promise<MoodFlightsPayload> {
    const departure = this.departureDate();
    const departureDate = departure.toISOString().slice(0, 10);
    const country = (input.country ?? '').trim().toUpperCase();
    const mood = (input.mood ?? '').trim().toLowerCase();
    const limit = Math.min(
      Math.max(Math.trunc(input.limit ?? MAX_MOOD_CITIES) || MAX_MOOD_CITIES, 1),
      MAX_MOOD_CITIES,
    );

    const empty = (): MoodFlightsPayload => ({
      origin: null,
      originCountryCode: country.length === 2 ? country : null,
      mood: null,
      departureDate,
      flights: [],
    });

    if (!/^[A-Z]{2}$/.test(country)) return empty();
    if (!(TRAVEL_MOODS as readonly string[]).includes(mood)) return empty();

    const origin = ORIGIN_AIRPORT_BY_COUNTRY[country];
    if (!origin) return empty();

    const cacheKey = `home:flights:${country}:${mood}:${departureDate}:${limit}`;
    const cached = await this.cache.get<MoodFlightsPayload>(cacheKey);
    if (cached) return cached;

    const cities = await this.moodCities(mood, limit);
    const payload: MoodFlightsPayload = {
      origin,
      originCountryCode: country,
      mood: mood as TravelMood,
      departureDate,
      flights: [],
    };

    if (cities.length === 0) {
      // No published city carries this mood: an honest empty rail.
      return payload;
    }

    const settled = await Promise.allSettled(
      cities.map((city) => this.cheapestFlightTo(city, origin, country, mood as TravelMood, departure)),
    );
    for (let index = 0; index < settled.length; index += 1) {
      const result = settled[index];
      if (result.status === 'fulfilled' && result.value) {
        payload.flights.push(result.value);
      } else if (result.status === 'rejected') {
        this.logger.warn(
          `Mood flights: ${cities[index].city} unavailable (${String(result.reason)})`,
        );
      }
    }
    payload.flights.sort((a, b) => a.price - b.price);

    // Cache only a successful, non-empty snapshot — an outage must be able to
    // recover on the next Home open.
    if (payload.flights.length > 0) {
      await this.cache.set(cacheKey, payload, MOOD_FLIGHTS_TTL_SECONDS);
    }
    return payload;
  }

  /**
   * Published destinations whose authored taxonomy contains [mood], in the
   * feed's own order. The same publication filters as `/home/sections` apply
   * because the sections come straight from [HomeService].
   */
  private async moodCities(
    mood: string,
    limit: number,
  ): Promise<Array<{ city: string; iata: string }>> {
    const sections = await this.home.getSections();
    const seen = new Set<string>();
    const cities: Array<{ city: string; iata: string }> = [];
    for (const section of sections) {
      for (const card of section.cards ?? []) {
        if (card.type !== 'destination') continue;
        const moods = card.metadata?.moods;
        if (!Array.isArray(moods)) continue;
        const declared = moods.map((value: unknown) =>
          String(value ?? '').trim().toLowerCase(),
        );
        if (!declared.includes(mood)) continue;
        const city = String(card.title ?? '').trim();
        if (city.length === 0) continue;
        const iata = CITY_TO_IATA[city.toLowerCase()];
        // A destination without a mapped airport cannot produce an honest
        // fare, so it is skipped rather than guessed.
        if (!iata) continue;
        const key = city.toLowerCase();
        if (seen.has(key)) continue;
        seen.add(key);
        cities.push({ city, iata });
        if (cities.length >= limit) return cities;
      }
    }
    return cities;
  }

  /** The cheapest real, bookable offer to one destination, or null. */
  private async cheapestFlightTo(
    city: { city: string; iata: string },
    origin: string,
    country: string,
    mood: TravelMood,
    departure: Date,
  ): Promise<MoodFlightCard | null> {
    const result = await this.nuitee.searchFlights({
      origin,
      destination: city.iata,
      departure,
      passengers: 1,
    });
    if (!result.success || !Array.isArray(result.data) || result.data.length === 0) {
      if (!result.success && result.error) {
        this.logger.warn(`Mood flights: ${city.city} provider error (${result.error})`);
      }
      return null;
    }

    let best: any = null;
    let bestPrice = Number.POSITIVE_INFINITY;
    for (const offer of result.data) {
      const price =
        typeof offer?.price === 'number'
          ? offer.price
          : Number.parseFloat(String(offer?.price ?? ''));
      if (!Number.isFinite(price) || price <= 0) continue;
      const seats = offer?.metadata?.seatsLeft;
      // A provider-reported sold-out offer is not a recommendation.
      if (typeof seats === 'number' && seats <= 0) continue;
      if (price < bestPrice) {
        best = offer;
        bestPrice = price;
      }
    }
    if (!best) return null;
    return this.toCard(best, city.city, country, mood);
  }

  /**
   * Flatten a provider offer into the card the Home flight list already
   * renders, keeping every provider fact verbatim and omitting absent ones.
   */
  private toCard(
    offer: any,
    destinationCity: string,
    country: string,
    mood: TravelMood,
  ): MoodFlightCard {
    const seats = offer?.metadata?.seatsLeft;
    const baggage = offer?.metadata?.baggage;
    return {
      id: String(offer.id),
      type: 'flight',
      title: String(offer.title ?? ''),
      subtitle: String(offer.subtitle ?? ''),
      price: Number(offer.price),
      currency: String(offer.currency ?? 'USD'),
      metadata: {
        providerId: offer.providerId,
        providerName: offer.providerName,
        providerOfferId: offer.metadata?.providerOfferId ?? offer.id,
        origin: offer.origin,
        destination: offer.destination,
        // The city the mood rail asked for — used to keep Home honest when a
        // provider maps a metro area to a secondary airport.
        destinationCity,
        originCountryCode: country,
        departureTime: offer.departureTime,
        arrivalTime: offer.arrivalTime,
        airline: offer.airline,
        flightNumber: offer.flightNumber,
        duration: offer.duration,
        stops: offer.stops,
        ...(typeof seats === 'number' ? { seatsLeft: seats } : {}),
        ...(typeof baggage === 'string' && baggage.length > 0 ? { baggage } : {}),
        ...(offer.metadata?.expiresAt ? { expiresAt: offer.metadata.expiresAt } : {}),
        ...(offer.metadata?.retrievedAt ? { retrievedAt: offer.metadata.retrievedAt } : {}),
        travelMood: mood,
      },
    };
  }

  /** Midnight UTC, two weeks out — stable within a cache window. */
  private departureDate(now = new Date()): Date {
    const date = new Date(now);
    date.setUTCHours(0, 0, 0, 0);
    date.setUTCDate(date.getUTCDate() + DEPARTURE_DAYS_AHEAD);
    return date;
  }
}
