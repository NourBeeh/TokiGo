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
exports.DuffelBookingProvider = void 0;
const common_1 = require("@nestjs/common");
const duffel_service_1 = require("../../duffel/duffel.service");
/**
 * Booking capability adapter for the Duffel flight provider (Phase 4A).
 *
 * Reuses the EXISTING DuffelService methods (`revalidateOffer`, `createOrder`)
 * — it does not re-implement any provider call. Duffel flights can be booked
 * and revalidated; cancellation is unsupported, so `cancel` is false and the
 * service will surface a structured capability error instead of calling a
 * non-existent path.
 *
 * Payment is deliberately NOT part of this adapter (spec: 4A ships no
 * payment). `createOrder` runs in `instant` mode per existing behaviour.
 */
let DuffelBookingProvider = class DuffelBookingProvider {
    duffel;
    constructor(duffel) {
        this.duffel = duffel;
    }
    providerId = 'duffel-flight';
    get providerName() {
        return this.duffel.providerName;
    }
    bookingCapability = {
        book: true,
        cancel: false,
        revalidate: true,
    };
    async revalidateBooking(offerId) {
        const result = await this.duffel.revalidateOffer(offerId);
        if (!result.success || !result.data) {
            return {
                success: false,
                providerId: this.providerId,
                providerName: this.providerName,
                error: result.error ?? 'Duffel revalidation failed',
                timestamp: result.timestamp,
            };
        }
        const data = result.data;
        return {
            success: true,
            providerId: this.providerId,
            providerName: this.providerName,
            data: {
                price: Number(data.price ?? 0),
                currency: String(data.currency ?? 'USD'),
                available: data.available !== false && Number(data.price ?? 0) > 0,
                expiresAt: data.expiresAt,
            },
            timestamp: result.timestamp,
        };
    }
    async createBooking(input) {
        try {
            const order = await this.duffel.createOrder(input.offerId, input.travelers ?? [], []);
            const reference = order?.booking_reference ?? order?.id ?? String(order?.id ?? '');
            return {
                success: true,
                providerId: this.providerId,
                providerName: this.providerName,
                data: {
                    reference: String(reference),
                    providerBookingId: order?.id,
                    status: order?.status,
                    amount: order?.total_amount ? Number(order.total_amount) : undefined,
                    currency: order?.total_currency,
                    raw: order,
                },
                timestamp: new Date(),
            };
        }
        catch (error) {
            return {
                success: false,
                providerId: this.providerId,
                providerName: this.providerName,
                error: error.message,
                timestamp: new Date(),
            };
        }
    }
    async cancelBooking(_input) {
        return {
            success: false,
            providerId: this.providerId,
            providerName: this.providerName,
            error: 'Duffel cancellation is not supported',
            timestamp: new Date(),
        };
    }
};
exports.DuffelBookingProvider = DuffelBookingProvider;
exports.DuffelBookingProvider = DuffelBookingProvider = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [duffel_service_1.DuffelService])
], DuffelBookingProvider);
//# sourceMappingURL=duffel-booking.provider.js.map