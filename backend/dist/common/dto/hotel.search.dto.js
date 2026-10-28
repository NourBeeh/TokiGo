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
exports.HotelSearchDto = void 0;
const class_validator_1 = require("class-validator");
const travel_mood_1 = require("../travel_mood");
class HotelSearchDto {
    city;
    checkIn;
    checkOut;
    guests;
    /**
     * Phase 3A (Flutter) sends the rich hotel search fields; Phase 3B adds
     * them to this DTO so the whitelist pipe accepts the contract the client
     * already implements. Explicit null = unset (the client sends null for
     * omitted fields; class-validator treats null as absent for @IsOptional
     * in non-strict mode — verified by the 3B contract spec).
     */
    rooms;
    minRating;
    maxPrice;
    minPrice;
    amenities;
    /**
     * Optional ISO-3166-1 alpha-2 country of the searched city. The provider
     * rates endpoint requires a country alongside the city name; without it a
     * city such as Gudauri would be queried under the fallback country and
     * return an empty (but false) answer. Discover cards send their own country.
     */
    country;
    /** MarketContext selector (ISO-3166-1 alpha-2). Display currency/locale. */
    market;
    /** Informational traveller context; providers do not receive this field. */
    mood;
}
exports.HotelSearchDto = HotelSearchDto;
__decorate([
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], HotelSearchDto.prototype, "city", void 0);
__decorate([
    (0, class_validator_1.IsDateString)(),
    __metadata("design:type", Date)
], HotelSearchDto.prototype, "checkIn", void 0);
__decorate([
    (0, class_validator_1.IsDateString)(),
    __metadata("design:type", Date)
], HotelSearchDto.prototype, "checkOut", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsInt)(),
    (0, class_validator_1.Min)(1),
    __metadata("design:type", Number)
], HotelSearchDto.prototype, "guests", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsInt)(),
    (0, class_validator_1.Min)(1),
    __metadata("design:type", Object)
], HotelSearchDto.prototype, "rooms", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsNumber)(),
    (0, class_validator_1.Min)(0),
    (0, class_validator_1.Max)(5),
    __metadata("design:type", Object)
], HotelSearchDto.prototype, "minRating", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsNumber)(),
    (0, class_validator_1.Min)(0),
    __metadata("design:type", Object)
], HotelSearchDto.prototype, "maxPrice", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsNumber)(),
    (0, class_validator_1.Min)(0),
    __metadata("design:type", Object)
], HotelSearchDto.prototype, "minPrice", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsArray)(),
    (0, class_validator_1.IsString)({ each: true }),
    (0, class_validator_1.MinLength)(1, { each: true }),
    __metadata("design:type", Object)
], HotelSearchDto.prototype, "amenities", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.Matches)(/^[A-Za-z]{2}$/),
    __metadata("design:type", Object)
], HotelSearchDto.prototype, "country", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], HotelSearchDto.prototype, "market", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsIn)([...travel_mood_1.TRAVEL_MOODS]),
    __metadata("design:type", String)
], HotelSearchDto.prototype, "mood", void 0);
//# sourceMappingURL=hotel.search.dto.js.map