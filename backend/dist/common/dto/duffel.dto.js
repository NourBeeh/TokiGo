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
exports.DuffelCreateBookingDto = exports.DuffelFlightSearchDto = void 0;
const class_transformer_1 = require("class-transformer");
const class_validator_1 = require("class-validator");
/**
 * Duffel HTTP contracts (Stage-2 refactor, 2026-10-25).
 *
 * The controller previously took inline `any[]` bodies: `create-booking`
 * forwarded whatever the caller sent straight to the airline provider — an
 * unauthenticated endpoint that could spend real money. The bodies are now
 * validated shapes, and the booking route is JWT-guarded.
 *
 * The passenger/payment ITEMS stay provider-shaped: Duffel owns that schema
 * and duplicating it here would drift. The contract pinned here is the part we
 * actually depend on — a non-empty array of objects, sent with a real offer id.
 */
/** Flight search (public: it only reads prices). */
class DuffelFlightSearchDto {
    /** IATA airport code, e.g. CAI. */
    origin;
    destination;
    /** ISO-8601 date (YYYY-MM-DD accepted). */
    departureDate;
    passengers;
}
exports.DuffelFlightSearchDto = DuffelFlightSearchDto;
__decorate([
    (0, class_transformer_1.Transform)(({ value }) => typeof value === 'string' ? value.trim().toUpperCase() : value),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MinLength)(3),
    (0, class_validator_1.Matches)(/^[A-Z]{3}$/, { message: 'origin must be a 3-letter IATA code' }),
    __metadata("design:type", String)
], DuffelFlightSearchDto.prototype, "origin", void 0);
__decorate([
    (0, class_transformer_1.Transform)(({ value }) => typeof value === 'string' ? value.trim().toUpperCase() : value),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MinLength)(3),
    (0, class_validator_1.Matches)(/^[A-Z]{3}$/, { message: 'destination must be a 3-letter IATA code' }),
    __metadata("design:type", String)
], DuffelFlightSearchDto.prototype, "destination", void 0);
__decorate([
    (0, class_validator_1.IsISO8601)(),
    __metadata("design:type", String)
], DuffelFlightSearchDto.prototype, "departureDate", void 0);
__decorate([
    (0, class_validator_1.IsInt)(),
    (0, class_validator_1.Min)(1),
    (0, class_validator_1.Max)(9),
    __metadata("design:type", Number)
], DuffelFlightSearchDto.prototype, "passengers", void 0);
/** Booking creation (JWT-guarded: it moves money). */
class DuffelCreateBookingDto {
    offerId;
    /** Provider-shaped passenger objects, forwarded verbatim. */
    passengers;
    /** Provider-shaped payment objects, forwarded verbatim. */
    payments;
}
exports.DuffelCreateBookingDto = DuffelCreateBookingDto;
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.IsNotEmpty)(),
    __metadata("design:type", String)
], DuffelCreateBookingDto.prototype, "offerId", void 0);
__decorate([
    (0, class_validator_1.IsArray)(),
    (0, class_validator_1.ArrayNotEmpty)(),
    (0, class_validator_1.IsObject)({ each: true, message: 'each passenger must be an object' }),
    __metadata("design:type", Array)
], DuffelCreateBookingDto.prototype, "passengers", void 0);
__decorate([
    (0, class_validator_1.IsArray)(),
    (0, class_validator_1.ArrayNotEmpty)(),
    (0, class_validator_1.IsObject)({ each: true, message: 'each payment must be an object' }),
    __metadata("design:type", Array)
], DuffelCreateBookingDto.prototype, "payments", void 0);
//# sourceMappingURL=duffel.dto.js.map