"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var HomeFlightsService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.HomeFlightsService = exports.ORIGIN_AIRPORT_BY_COUNTRY = exports.DEPARTURE_DAYS_AHEAD = exports.MAX_MOOD_CITIES = exports.MOOD_FLIGHTS_TTL_SECONDS = exports.TRAVEL_MOODS = void 0;
const common_1 = require("@nestjs/common");
const cache_service_1 = require("../cache/cache.service");
const duffel_service_1 = require("../duffel/duffel.service");
const nuitee_flight_service_1 = require("../nuitee/nuitee.flight.service");
const home_service_1 = require("./home.service");
const travel_mood_1 = require("../../common/travel_mood");
Object.defineProperty(exports, "TRAVEL_MOODS", { enumerable: true, get: function () { return travel_mood_1.TRAVEL_MOODS; } });
/** Home mood rail cache — keep provider fares fresh across Home visits. */
exports.MOOD_FLIGHTS_TTL_SECONDS = 10 * 60;
/** The rail never asks for more than three live searches per request. */
exports.MAX_MOOD_CITIES = 3;
/** Stable near-term departure: a two-week scan, not "today's" last seats. */
exports.DEPARTURE_DAYS_AHEAD = 14;
/**
 * Curated primary-airport suggestions per country. This mirrors the Flutter
 * `suggestedAirportCodeForCountry` table and is intentionally a *suggestion*:
 * the traveller can change the origin on the flight search page.
 */
exports.ORIGIN_AIRPORT_BY_COUNTRY = {
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
let HomeFlightsService = HomeFlightsService_1 = class HomeFlightsService {
    home;
    nuitee;
    cache;
    logger = new common_1.Logger(HomeFlightsService_1.name);
    constructor(home, nuitee, cache) {
        this.home = home;
        this.nuitee = nuitee;
        this.cache = cache;
    }
    async getFlightsForMood(input) {
        const departure = this.departureDate();
        const departureDate = departure.toISOString().slice(0, 10);
        const country = (input.country ?? '').trim().toUpperCase();
        const mood = (input.mood ?? '').trim().toLowerCase();
        const limit = Math.min(Math.max(Math.trunc(input.limit ?? exports.MAX_MOOD_CITIES) || exports.MAX_MOOD_CITIES, 1), exports.MAX_MOOD_CITIES);
        const empty = () => ({
            origin: null,
            originCountryCode: country.length === 2 ? country : null,
            mood: null,
            departureDate,
            flights: [],
        });
        if (!/^[A-Z]{2}$/.test(country))
            return empty();
        if (!travel_mood_1.TRAVEL_MOODS.includes(mood))
            return empty();
        const origin = exports.ORIGIN_AIRPORT_BY_COUNTRY[country];
        if (!origin)
            return empty();
        const cacheKey = `home:flights:${country}:${mood}:${departureDate}:${limit}`;
        const cached = await this.cache.get(cacheKey);
        if (cached)
            return cached;
        const cities = await this.moodCities(mood, limit);
        const payload = {
            origin,
            originCountryCode: country,
            mood: mood,
            departureDate,
            flights: [],
        };
        if (cities.length === 0) {
            // No published city carries this mood: an honest empty rail.
            return payload;
        }
        const settled = await Promise.allSettled(cities.map((city) => this.cheapestFlightTo(city, origin, country, mood, departure)));
        for (let index = 0; index < settled.length; index += 1) {
            const result = settled[index];
            if (result.status === 'fulfilled' && result.value) {
                payload.flights.push(result.value);
            }
            else if (result.status === 'rejected') {
                this.logger.warn(`Mood flights: ${cities[index].city} unavailable (${String(result.reason)})`);
            }
        }
        payload.flights.sort((a, b) => a.price - b.price);
        // Cache only a successful, non-empty snapshot — an outage must be able to
        // recover on the next Home open.
        if (payload.flights.length > 0) {
            await this.cache.set(cacheKey, payload, exports.MOOD_FLIGHTS_TTL_SECONDS);
        }
        return payload;
    }
    /**
     * Published destinations whose authored taxonomy contains [mood], in the
     * feed's own order. The same publication filters as `/home/sections` apply
     * because the sections come straight from [HomeService].
     */
    async moodCities(mood, limit) {
        const sections = await this.home.getSections();
        const seen = new Set();
        const cities = [];
        for (const section of sections) {
            for (const card of section.cards ?? []) {
                if (card.type !== 'destination')
                    continue;
                const moods = card.metadata?.moods;
                if (!Array.isArray(moods))
                    continue;
                const declared = moods.map((value) => String(value ?? '').trim().toLowerCase());
                if (!declared.includes(mood))
                    continue;
                const city = String(card.title ?? '').trim();
                if (city.length === 0)
                    continue;
                const iata = duffel_service_1.CITY_TO_IATA[city.toLowerCase()];
                // A destination without a mapped airport cannot produce an honest
                // fare, so it is skipped rather than guessed.
                if (!iata)
                    continue;
                const key = city.toLowerCase();
                if (seen.has(key))
                    continue;
                seen.add(key);
                cities.push({ city, iata });
                if (cities.length >= limit)
                    return cities;
            }
        }
        return cities;
    }
    /** The cheapest real, bookable offer to one destination, or null. */
    async cheapestFlightTo(city, origin, country, mood, departure) {
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
        let best = null;
        let bestPrice = Number.POSITIVE_INFINITY;
        for (const offer of result.data) {
            const price = typeof offer?.price === 'number'
                ? offer.price
                : Number.parseFloat(String(offer?.price ?? ''));
            if (!Number.isFinite(price) || price <= 0)
                continue;
            const seats = offer?.metadata?.seatsLeft;
            // A provider-reported sold-out offer is not a recommendation.
            if (typeof seats === 'number' && seats <= 0)
                continue;
            if (price < bestPrice) {
                best = offer;
                bestPrice = price;
            }
        }
        if (!best)
            return null;
        return this.toCard(best, city.city, country, mood);
    }
    /**
     * Flatten a provider offer into the card the Home flight list already
     * renders, keeping every provider fact verbatim and omitting absent ones.
     */
    toCard(offer, destinationCity, country, mood) {
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
    departureDate(now = new Date()) {
        const date = new Date(now);
        date.setUTCHours(0, 0, 0, 0);
        date.setUTCDate(date.getUTCDate() + exports.DEPARTURE_DAYS_AHEAD);
        return date;
    }
};
exports.HomeFlightsService = HomeFlightsService;
exports.HomeFlightsService = HomeFlightsService = HomeFlightsService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [home_service_1.HomeService,
        nuitee_flight_service_1.NuiteeFlightService,
        cache_service_1.CacheService])
], HomeFlightsService);
//# sourceMappingURL=home.flights.service.js.map