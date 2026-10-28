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
exports.CreateBookingDto = exports.RevalidateBookingDto = exports.PrepareBookingDto = exports.BOOKING_TYPES = void 0;
const class_validator_1 = require("class-validator");
/**
 * Booking DTOs (Phase 4A) — validated at the HTTP boundary (global
 * ValidationPipe with whitelist + forbidNonWhitelisted in main.ts).
 *
 * SECURITY: userId is NEVER part of any DTO. Ownership is derived from the
 * JWT and enforced in the service; a client can never book on behalf of
 * another user. Prices are NEVER accepted from the client either — the
 * authoritative amount always comes from a provider-side revalidation.
 */
exports.BOOKING_TYPES = ['flight', 'hotel', 'car', 'package'];
class PrepareBookingDto {
    offerId;
    providerId;
    searchId;
    offerType;
    providerName;
}
exports.PrepareBookingDto = PrepareBookingDto;
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MinLength)(1),
    (0, class_validator_1.MaxLength)(200),
    __metadata("design:type", String)
], PrepareBookingDto.prototype, "offerId", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MinLength)(1),
    (0, class_validator_1.MaxLength)(80),
    __metadata("design:type", String)
], PrepareBookingDto.prototype, "providerId", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MaxLength)(120),
    __metadata("design:type", String)
], PrepareBookingDto.prototype, "searchId", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsIn)(exports.BOOKING_TYPES),
    __metadata("design:type", String)
], PrepareBookingDto.prototype, "offerType", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MaxLength)(120),
    __metadata("design:type", String)
], PrepareBookingDto.prototype, "providerName", void 0);
class RevalidateBookingDto {
    bookingId;
}
exports.RevalidateBookingDto = RevalidateBookingDto;
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MinLength)(1),
    (0, class_validator_1.MaxLength)(120),
    __metadata("design:type", String)
], RevalidateBookingDto.prototype, "bookingId", void 0);
class CreateBookingDto {
    bookingId;
    /** Mandatory idempotency key — a retried create can never double-book. */
    idempotencyKey;
    travelers;
}
exports.CreateBookingDto = CreateBookingDto;
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MinLength)(1),
    (0, class_validator_1.MaxLength)(120),
    __metadata("design:type", String)
], CreateBookingDto.prototype, "bookingId", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MinLength)(1),
    (0, class_validator_1.MaxLength)(200),
    __metadata("design:type", String)
], CreateBookingDto.prototype, "idempotencyKey", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsArray)(),
    (0, class_validator_1.ArrayMaxSize)(20),
    __metadata("design:type", Array)
], CreateBookingDto.prototype, "travelers", void 0);
//# sourceMappingURL=booking.dto.js.map