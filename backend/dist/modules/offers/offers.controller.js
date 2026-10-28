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
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.OffersController = void 0;
const common_1 = require("@nestjs/common");
const revalidate_offer_dto_1 = require("../../common/dto/revalidate-offer.dto");
const duffel_service_1 = require("../duffel/duffel.service");
const nuitee_service_1 = require("../nuitee/nuitee.service");
/**
 * Offer revalidation endpoint (spec points 7-8): refreshes the authoritative
 * price/availability of a selected offer right before checkout.
 *
 * Flow: SELECTED -> PRICE_REVALIDATED. When the price moved, the response is
 * a structured PRICE_CHANGED outcome — payment must never proceed silently
 * on a changed amount.
 */
let OffersController = class OffersController {
    duffelService;
    nuiteeService;
    constructor(duffelService, nuiteeService) {
        this.duffelService = duffelService;
        this.nuiteeService = nuiteeService;
    }
    async revalidate(dto) {
        try {
            let result;
            switch (dto.providerId) {
                case 'duffel-flight':
                    result = await this.duffelService.revalidateOffer(dto.offerId);
                    break;
                case 'nuitee':
                    result = await this.nuiteeService.prebookHotel({
                        rateId: dto.offerId,
                        guests: dto.guests,
                    });
                    break;
                default:
                    // Unknown/legacy provider ids fall back to a fresh provider-side
                    // check when one exists; otherwise the offer cannot be trusted.
                    return {
                        status: 'UNAVAILABLE',
                        offerId: dto.offerId,
                        reason: `No revalidation path for provider ${dto.providerId}`,
                    };
            }
            if (!result?.success) {
                return {
                    status: 'UNAVAILABLE',
                    offerId: dto.offerId,
                    reason: result?.error,
                };
            }
            const data = result.data ?? {};
            const newPrice = Number(data.newPrice ?? data.price ?? data.total ?? data.net ?? 0);
            const currency = String(data.currency ?? 'USD');
            const oldPrice = dto.knownPrice !== undefined ? Number(dto.knownPrice) : undefined;
            const priceChanged = oldPrice !== undefined &&
                Math.abs(oldPrice - newPrice) > 0.01;
            if (priceChanged) {
                return {
                    status: 'PRICE_CHANGED',
                    offerId: dto.offerId,
                    oldPrice,
                    newPrice,
                    currency,
                    expiresAt: data.expiresAt,
                };
            }
            return {
                status: 'OK',
                offerId: dto.offerId,
                price: newPrice,
                currency,
                // Provider expiry only. A fallback window invented here would reach the
                // client as a real booking deadline.
                expiresAt: data.expiresAt,
            };
        }
        catch (error) {
            // Do not leak provider/internal error details to the client.
            // eslint-disable-next-line no-console
            console.error('[offers/revalidate]', error);
            return { status: 'ERROR', error: 'Revalidation failed' };
        }
    }
};
exports.OffersController = OffersController;
__decorate([
    (0, common_1.Post)('revalidate'),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [revalidate_offer_dto_1.RevalidateOfferDto]),
    __metadata("design:returntype", Promise)
], OffersController.prototype, "revalidate", null);
exports.OffersController = OffersController = __decorate([
    (0, common_1.Controller)('offers'),
    __metadata("design:paramtypes", [duffel_service_1.DuffelService,
        nuitee_service_1.NuiteeService])
], OffersController);
//# sourceMappingURL=offers.controller.js.map