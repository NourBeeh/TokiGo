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
Object.defineProperty(exports, "__esModule", { value: true });
exports.NuiteeFlightBookingProvider = void 0;
const common_1 = require("@nestjs/common");
const nuitee_flight_service_1 = require("../../nuitee/nuitee.flight.service");
/**
 * Booking adapter for Nuitee flight provider (Phase 4B — simplified sandbox).
 * Uses sandbox simulated payment (ACC_CREDIT_CARD) and simplified passenger data.
 */
let NuiteeFlightBookingProvider = class NuiteeFlightBookingProvider {
    flightService;
    constructor(flightService) {
        this.flightService = flightService;
    }
    providerId = 'nuitee-flight';
    get providerName() {
        return 'Nuitee Flights';
    }
    bookingCapability = {
        book: true,
        cancel: false,
        revalidate: true,
    };
    async revalidateBooking(offerId) {
        const prebook = await this.flightService.prebookFlight({
            offerId,
            contact: {
                firstName: 'Test',
                lastName: 'Guest',
                email: 'test@tokigo.app',
                phoneCountryCode: '+20',
                phoneNumber: '1234567890',
            },
            passengers: [
                {
                    passengerType: 'ADT',
                    firstName: 'Test',
                    lastName: 'Guest',
                },
            ],
            usePaymentSdk: false,
        });
        if (!prebook.success) {
            return {
                success: false,
                providerId: this.providerId,
                providerName: this.providerName,
                error: prebook.error ?? 'Nuitee flight prebook failed',
                timestamp: new Date(),
            };
        }
        return {
            success: true,
            providerId: this.providerId,
            providerName: this.providerName,
            data: {
                price: 0,
                currency: 'USD',
                available: true,
                expiresAt: new Date(Date.now() + 30 * 60 * 1000).toISOString(),
                priceChanged: false,
                oldPrice: 0,
                handoff: {
                    prebookId: String(prebook.prebookId),
                    transactionId: String(prebook.transactionId),
                    offerId,
                },
            },
            timestamp: new Date(),
        };
    }
    async createBooking(input) {
        const snapshot = (input.offerSnapshot ?? {});
        const prebookId = snapshot.prebookId;
        if (!prebookId) {
            return {
                success: false,
                providerId: this.providerId,
                providerName: this.providerName,
                error: 'Missing Nuitee flight prebookId in snapshot',
                timestamp: new Date(),
            };
        }
        const bookResult = await this.flightService.bookFlight({
            prebookId: String(prebookId),
            payment: { method: 'ACC_CREDIT_CARD' },
        });
        if (!bookResult.success) {
            return {
                success: false,
                providerId: this.providerId,
                providerName: this.providerName,
                error: bookResult.error ?? 'Nuitee flight booking failed',
                timestamp: new Date(),
            };
        }
        return {
            success: true,
            providerId: this.providerId,
            providerName: this.providerName,
            data: {
                reference: bookResult.bookingRef ?? bookResult.bookingId ?? String(prebookId),
                providerBookingId: bookResult.bookingId,
                status: bookResult.status ?? 'CREATED',
                amount: 0,
                currency: 'USD',
                raw: bookResult,
            },
            timestamp: new Date(),
        };
    }
    async cancelBooking(_input) {
        return {
            success: false,
            providerId: this.providerId,
            providerName: this.providerName,
            error: 'Nuitee flight cancellation not supported',
            timestamp: new Date(),
        };
    }
};
exports.NuiteeFlightBookingProvider = NuiteeFlightBookingProvider;
exports.NuiteeFlightBookingProvider = NuiteeFlightBookingProvider = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [nuitee_flight_service_1.NuiteeFlightService])
], NuiteeFlightBookingProvider);
//# sourceMappingURL=nuitee-flight-booking.provider.js.map