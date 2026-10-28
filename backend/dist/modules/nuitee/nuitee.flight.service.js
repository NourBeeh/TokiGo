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
var NuiteeFlightService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.NuiteeFlightService = void 0;
const common_1 = require("@nestjs/common");
const config_1 = require("@nestjs/config");
const duffel_service_1 = require("../duffel/duffel.service");
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
let NuiteeFlightService = NuiteeFlightService_1 = class NuiteeFlightService {
    configService;
    providerId = 'nuitee-flight';
    providerName = 'Nuitee Flights';
    logger = new common_1.Logger(NuiteeFlightService_1.name);
    apiKey;
    constructor(configService) {
        this.configService = configService;
        this.apiKey = this.configService.get('NUITEE_API_KEY');
        if (!this.apiKey) {
            this.logger.warn('NUITEE_API_KEY is not defined — Nuitee flight provider is disabled');
        }
    }
    headers() {
        return {
            'Content-Type': 'application/json',
            'X-API-Key': this.apiKey,
        };
    }
    async nuiteeFetch(path, init) {
        const response = await fetch(`${NUITEE_BASE_URL}${path}`, {
            ...init,
            signal: AbortSignal.timeout(FLIGHT_SEARCH_TIMEOUT_MS),
        });
        const text = await response.text();
        let body;
        try {
            body = JSON.parse(text);
        }
        catch {
            throw new Error(`Nuitee flights returned non-JSON (${response.status}): ${text.slice(0, 120)}`);
        }
        if (!response.ok) {
            const detail = body?.error?.message ?? body?.message ?? JSON.stringify(body).slice(0, 160);
            throw new Error(`Nuitee ${path} failed (${response.status}): ${String(detail)}`);
        }
        return body;
    }
    async searchFlights(params) {
        if (!this.apiKey) {
            return this.disabledResult();
        }
        const dateStr = (value) => (value instanceof Date ? value.toISOString() : String(value)).split('T')[0];
        try {
            // Legs-based itinerary (round-trip = outbound + inbound leg).
            const legs = [
                {
                    origin: (0, duffel_service_1.resolveIataCode)(params.origin),
                    destination: (0, duffel_service_1.resolveIataCode)(params.destination),
                    date: dateStr(params.departure),
                    direction: 'OUTBOUND',
                },
            ];
            if (params.returnDate) {
                legs.push({
                    origin: (0, duffel_service_1.resolveIataCode)(params.destination),
                    destination: (0, duffel_service_1.resolveIataCode)(params.origin),
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
        }
        catch (error) {
            return {
                success: false,
                providerId: this.providerId,
                providerName: this.providerName,
                error: `Failed Nuitee flights search: ${error.message}`,
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
    mapResponse(response, params) {
        const groups = Array.isArray(response?.data) ? response.data : [];
        const offers = [];
        for (const group of groups) {
            for (const journey of group?.journeys ?? []) {
                for (const offer of journey?.offers ?? []) {
                    const mapped = this.mapOffer(offer, journey, params);
                    if (mapped)
                        offers.push(mapped);
                }
            }
        }
        return offers;
    }
    /** Pure mapper — unit-testable without any HTTP. */
    mapOffer(offer, journey, params) {
        const offerId = offer?.offerId;
        const total = offer?.pricing?.display?.total;
        const currency = offer?.pricing?.display?.currency;
        // Malformed offers are dropped, never invented (3B rule).
        if (typeof offerId !== 'string' || typeof total !== 'number' || !currency) {
            return null;
        }
        const segments = Array.isArray(journey?.segments) ? journey.segments : [];
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
                expiresAt: offer?.expiration ?? new Date(Date.now() + 30 * 60 * 1000).toISOString(),
                // 3D — verbatim detail fields for the details page (never invented).
                fareFamily: offer?.fare?.family,
                refundable: offer?.terms?.refundable ?? undefined,
                baggage: offer?.baggage ?? undefined,
            },
        };
    }
    async prebookFlight(payload) {
        if (!this.apiKey)
            return { success: false, error: 'NUITEE_API_KEY missing' };
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
        }
        catch (error) {
            return { success: false, error: `Nuitee flight prebook failed: ${error.message}` };
        }
    }
    async bookFlight(payload) {
        if (!this.apiKey)
            return { success: false, error: 'NUITEE_API_KEY missing' };
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
        }
        catch (error) {
            return { success: false, error: `Nuitee flight book failed: ${error.message}` };
        }
    }
    async trackFlightBooking(bookingId) {
        if (!this.apiKey)
            return { success: false, error: 'NUITEE_API_KEY missing' };
        try {
            const response = await this.nuiteeFetch(`/flights/bookings/${bookingId}`, { method: 'GET', headers: this.headers() });
            const data = response?.data ?? response;
            return { success: true, status: data?.status ?? 'UNKNOWN', bookingRef: data?.bookingRef, timestamp: new Date() };
        }
        catch (error) {
            return { success: false, error: `Nuitee flight track failed: ${error.message}`, timestamp: new Date() };
        }
    }
    disabledResult() {
        return {
            success: false,
            providerId: this.providerId,
            providerName: this.providerName,
            data: [],
            error: 'NUITEE_API_KEY missing',
            timestamp: new Date(),
        };
    }
};
exports.NuiteeFlightService = NuiteeFlightService;
exports.NuiteeFlightService = NuiteeFlightService = NuiteeFlightService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [config_1.ConfigService])
], NuiteeFlightService);
//# sourceMappingURL=nuitee.flight.service.js.map