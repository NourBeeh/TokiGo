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
var NuiteeService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.NuiteeService = void 0;
const common_1 = require("@nestjs/common");
const config_1 = require("@nestjs/config");
const nuitee_client_1 = require("./nuitee.client");
const nuitee_cities_1 = require("./nuitee.cities");
const nuitee_mapper_1 = require("./nuitee.mapper");
/**
 * Nuitee Connect hotel provider (spec point 25).
 *
 * Orchestration only: it decides WHICH call to make and what an honest answer
 * looks like. Transport lives in `nuitee.client.ts`, payload mapping in
 * `nuitee.mapper.ts`, the city→country table in `nuitee.cities.ts`.
 *
 * Implements the shared HotelProvider contract so it can be registered,
 * routed and replaced without touching domain or Flutter code.
 *
 * Workflow mapping (Nuitee Connect REST v3):
 *   searchHotels  -> POST /v3.0/hotels/rates   (rates search)
 *   prebookHotel  -> POST /v3.0/rates/prebook
 *   bookHotel     -> POST /v3.0/rates/book    (ACC_CREDIT_CARD sandbox)
 *   hotelContent  -> GET  /v3.0/data/hotels    (metadata list)
 */
let NuiteeService = NuiteeService_1 = class NuiteeService {
    providerId = 'nuitee';
    providerName = 'Nuitee Connect';
    logger = new common_1.Logger(NuiteeService_1.name);
    client;
    constructor(configService) {
        this.client = new nuitee_client_1.NuiteeClient(configService);
    }
    /**
     * Rates search mapped into the shared hotel offer shape.
     * One offer per (hotel, cheapest rate) so every bookable hotel surfaces once
     * with its live provider price.
     */
    async searchHotels(params) {
        if (!this.client.enabled) {
            return this.disabledResult();
        }
        const checkInStr = (0, nuitee_mapper_1.dateStr)(params.checkIn);
        const checkOutStr = (0, nuitee_mapper_1.dateStr)(params.checkOut);
        const guests = params.guests ?? 2;
        const rooms = params.rooms ?? 1;
        try {
            const body = {
                cityName: params.city,
                countryCode: params.country ?? (0, nuitee_cities_1.countryFor)(params.city) ?? 'EG',
                checkin: checkInStr,
                checkout: checkOutStr,
                currency: 'USD',
                guestNationality: 'EG',
                occupancies: [{ rooms, adults: guests }],
                // Keep responses lean: top rate per room type, capped hotel set.
                maxRatesPerHotel: 2,
                limit: 40,
                includeHotelData: true,
            };
            const response = await this.client.request('/hotels/rates', {
                method: 'POST',
                body,
            });
            const hotelMeta = (0, nuitee_mapper_1.hotelMetaIndex)(response);
            const perHotel = (0, nuitee_mapper_1.cheapestPerHotel)((0, nuitee_mapper_1.extractRateResults)(response));
            const mapped = [...perHotel.values()]
                .map(({ entry }) => (0, nuitee_mapper_1.mapRateToOffer)(entry, hotelMeta, params, checkInStr, checkOutStr, this))
                .filter((offer) => offer !== null)
                // Cheapest-first order; capped hotel set keeps responses lean.
                .sort((a, b) => a.price - b.price)
                .slice(0, 40);
            return {
                success: true,
                providerId: this.providerId,
                providerName: this.providerName,
                data: mapped,
                timestamp: new Date(),
                metadata: {
                    engine: 'hotels/rates',
                    source: 'nuitee',
                    sandbox: response?.sandbox ?? false,
                },
            };
        }
        catch (error) {
            const message = error.message;
            this.logger.warn(`Rates search failed: ${message}`);
            return {
                ...this.disabledResult(),
                error: `Failed Nuitee rates search: ${message}`,
            };
        }
    }
    /**
     * Prebook — revalidates price/availability and freezes the quote
     * (spec points 8, 27). Preserves prebookId/transactionId because Nuitee
     * docs state they are NOT recoverable after the response is lost.
     */
    async prebookHotel(input) {
        if (!this.client.enabled) {
            return {
                success: false,
                providerId: this.providerId,
                error: 'NUITEE_API_KEY missing',
            };
        }
        try {
            const response = await this.client.request('/rates/prebook', {
                method: 'POST',
                body: {
                    offerId: input.rateId,
                    rooms: input.rooms ?? 1,
                    adults: input.guests ?? 2,
                    usePaymentSdk: false,
                },
            });
            const data = response?.data ?? response;
            return {
                success: true,
                providerId: this.providerId,
                prebookId: data?.prebookId,
                transactionId: data?.transactionId,
                priceChanged: Boolean(data?.priceChanged),
                newPrice: (0, nuitee_mapper_1.numberOrUndefined)(data?.net) ?? (0, nuitee_mapper_1.firstAmount)(data?.retailRate?.total),
                currency: data?.currency ?? data?.retailRate?.total?.[0]?.currency,
                expiresAt: data?.expiresAt ?? data?.holdExpiresAt,
            };
        }
        catch (error) {
            return {
                success: false,
                providerId: this.providerId,
                error: `Nuitee prebook failed: ${error.message}`,
            };
        }
    }
    /**
     * Book with the ACC_CREDIT_CARD strategy — TokiGo is merchant of record for
     * the customer payment; sandbox keys charge the attached hidden test account
     * card (spec point 27 / O.3).
     */
    async bookHotel(input) {
        if (!this.client.enabled) {
            return {
                ...this.disabledResult(),
                error: 'NUITEE_API_KEY missing',
            };
        }
        try {
            const response = await this.client.request('/rates/book', {
                method: 'POST',
                body: {
                    prebookId: input.prebookId,
                    transactionId: input.transactionId,
                    payment: { method: 'ACC_CREDIT_CARD' },
                    holder: {
                        firstName: firstNameOf(input.holderName),
                        lastName: lastNameOf(input.holderName),
                        email: input.holderEmail ?? 'guest@tokigo.app',
                    },
                    guests: input.guestNames.map((name, i) => ({
                        name: {
                            firstName: firstNameOf(name),
                            lastName: lastNameOf(name),
                        },
                        adult: i === 0,
                    })),
                },
            });
            const data = response?.data ?? response;
            return {
                success: true,
                providerId: this.providerId,
                providerName: this.providerName,
                data: {
                    bookingId: data?.bookingId ?? data?.id,
                    reference: data?.hotelConfirmationNumber ?? data?.confirmationCode,
                    status: data?.status ?? 'CONFIRMED',
                    total: (0, nuitee_mapper_1.firstAmount)(data?.total) ?? (0, nuitee_mapper_1.numberOrUndefined)(data?.net),
                    currency: data?.currency ?? data?.total?.[0]?.currency,
                },
                timestamp: new Date(),
            };
        }
        catch (error) {
            return {
                success: false,
                providerId: this.providerId,
                providerName: this.providerName,
                error: `Nuitee book failed: ${error.message}`,
                timestamp: new Date(),
            };
        }
    }
    /** Hotel metadata list (names/photos/facilities) for detail pages. */
    async hotelContent(city, country) {
        if (!this.client.enabled) {
            return { ...this.disabledResult(), error: 'NUITEE_API_KEY missing' };
        }
        try {
            const query = new URLSearchParams({ cityName: city });
            const countryCode = country ?? (0, nuitee_cities_1.countryFor)(city);
            if (countryCode)
                query.set('countryCode', countryCode);
            const response = await this.client.request(`/data/hotels?${query.toString()}`, { method: 'GET' });
            const hotels = response?.data ?? response?.hotels ?? [];
            return {
                success: true,
                providerId: this.providerId,
                providerName: this.providerName,
                data: hotels.slice(0, 50),
                timestamp: new Date(),
            };
        }
        catch (error) {
            return {
                success: false,
                providerId: this.providerId,
                providerName: this.providerName,
                error: `Nuitee content failed: ${error.message}`,
                timestamp: new Date(),
            };
        }
    }
    /** Honest "provider disabled" payload — never fake availability. */
    /** Minimal live tracking (5C) — fetches booking details from provider. */
    async trackBooking(bookingId) {
        if (!this.client.enabled)
            return { ...this.disabledResult(), error: 'NUITEE_API_KEY missing' };
        try {
            const response = await this.client.request(`/bookings/${bookingId}`, { method: 'GET' });
            return {
                success: true,
                providerId: this.providerId,
                providerName: this.providerName,
                data: response?.data ?? response,
                timestamp: new Date(),
            };
        }
        catch (error) {
            return { ...this.disabledResult(), error: `Nuitee track failed: ${error.message}` };
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
exports.NuiteeService = NuiteeService;
exports.NuiteeService = NuiteeService = NuiteeService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [config_1.ConfigService])
], NuiteeService);
function firstNameOf(fullName) {
    return fullName.trim().split(' ')[0];
}
/** Single-word holder names keep `-` rather than inventing a surname. */
function lastNameOf(fullName) {
    return fullName.trim().split(' ').slice(1).join(' ') || '-';
}
//# sourceMappingURL=nuitee.service.js.map