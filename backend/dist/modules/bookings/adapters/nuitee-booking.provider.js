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
exports.NuiteeBookingProvider = void 0;
const common_1 = require("@nestjs/common");
const nuitee_service_1 = require("../../nuitee/nuitee.service");
/**
 * Booking capability adapter for the Nuitee Connect hotel provider (Phase 4A).
 *
 * Reuses the EXISTING NuiteeService methods (`prebookHotel`, `bookHotel`).
 * The prebook handoff (`prebookId` / `transactionId`) is single-use and NOT
 * recoverable if lost, so `revalidateBooking` surfaces it through `handoff`
 * and the booking service persists it in `offerSnapshot` until create.
 *
 * Cancellation is unsupported → `cancel` false → structured capability error.
 * Payment stays out of scope (spec: no payment in 4A).
 */
let NuiteeBookingProvider = class NuiteeBookingProvider {
    nuitee;
    constructor(nuitee) {
        this.nuitee = nuitee;
    }
    providerId = 'nuitee';
    get providerName() {
        return this.nuitee.providerName;
    }
    bookingCapability = {
        book: true,
        cancel: false,
        revalidate: true,
    };
    async revalidateBooking(offerId) {
        const result = await this.nuitee.prebookHotel({ rateId: offerId });
        if (!result.success) {
            return {
                success: false,
                providerId: this.providerId,
                providerName: this.providerName,
                error: result.error ?? 'Nuitee prebook failed',
                timestamp: new Date(),
            };
        }
        const price = Number(result.newPrice ?? 0);
        return {
            success: true,
            providerId: this.providerId,
            providerName: this.providerName,
            data: {
                price,
                currency: result.currency ?? 'USD',
                available: price > 0,
                expiresAt: result.expiresAt,
                priceChanged: result.priceChanged,
                oldPrice: result.oldPrice,
                handoff: {
                    rateId: offerId,
                    prebookId: result.prebookId,
                    transactionId: result.transactionId,
                },
            },
            timestamp: new Date(),
        };
    }
    async createBooking(input) {
        const snapshot = input.offerSnapshot ?? {};
        const prebookId = snapshot.prebookId;
        const transactionId = snapshot.transactionId;
        if (!prebookId || !transactionId) {
            return {
                success: false,
                providerId: this.providerId,
                providerName: this.providerName,
                error: 'Missing Nuitee prebook handoff (prebookId/transactionId)',
                timestamp: new Date(),
            };
        }
        const travelers = input.travelers ?? [];
        const names = travelers
            .map((t) => `${t?.firstName ?? ''} ${t?.lastName ?? ''}`.trim())
            .filter(Boolean);
        const holderName = names[0] ?? 'TokiGo Guest';
        const holderEmail = travelers[0]?.email;
        const result = await this.nuitee.bookHotel({
            prebookId: String(prebookId),
            transactionId: String(transactionId),
            holderName,
            holderEmail,
            guestNames: names.length ? names : [holderName],
        });
        if (!result.success || !result.data) {
            return {
                success: false,
                providerId: this.providerId,
                providerName: this.providerName,
                error: result.error ?? 'Nuitee booking failed',
                timestamp: result.timestamp ?? new Date(),
            };
        }
        const data = result.data;
        return {
            success: true,
            providerId: this.providerId,
            providerName: this.providerName,
            data: {
                reference: String(data.reference ?? data.bookingId ?? ''),
                providerBookingId: data.bookingId,
                status: data.status,
                amount: data.total,
                currency: data.currency,
                raw: data,
            },
            timestamp: result.timestamp ?? new Date(),
        };
    }
    async cancelBooking(_input) {
        return {
            success: false,
            providerId: this.providerId,
            providerName: this.providerName,
            error: 'Nuitee cancellation is not supported',
            timestamp: new Date(),
        };
    }
};
exports.NuiteeBookingProvider = NuiteeBookingProvider;
exports.NuiteeBookingProvider = NuiteeBookingProvider = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [nuitee_service_1.NuiteeService])
], NuiteeBookingProvider);
//# sourceMappingURL=nuitee-booking.provider.js.map