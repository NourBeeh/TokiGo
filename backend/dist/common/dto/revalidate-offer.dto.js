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
exports.RevalidateOfferDto = void 0;
const class_validator_1 = require("class-validator");
/**
 * Offer revalidation request (spec points 7-8): the selected offer must be
 * re-checked for price/availability immediately before payment. Response
 * carries a structured PRICE_CHANGED result instead of a silent new price.
 */
class RevalidateOfferDto {
    offerId;
    providerId;
    offerType;
    knownPrice;
    guests;
}
exports.RevalidateOfferDto = RevalidateOfferDto;
__decorate([
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], RevalidateOfferDto.prototype, "offerId", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], RevalidateOfferDto.prototype, "providerId", void 0);
__decorate([
    (0, class_validator_1.IsIn)(['flight', 'hotel', 'car', 'package']),
    __metadata("design:type", String)
], RevalidateOfferDto.prototype, "offerType", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], RevalidateOfferDto.prototype, "knownPrice", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsInt)(),
    (0, class_validator_1.Min)(1),
    __metadata("design:type", Number)
], RevalidateOfferDto.prototype, "guests", void 0);
//# sourceMappingURL=revalidate-offer.dto.js.map