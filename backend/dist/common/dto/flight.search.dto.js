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
exports.FlightSearchDto = exports.FlightLegDto = void 0;
const class_validator_1 = require("class-validator");
const class_transformer_1 = require("class-transformer");
const travel_mood_1 = require("../travel_mood");
/**
 * One leg of a multi-city itinerary: where it leaves from, where it lands and
 * when. The provider turns each leg into one slice of the offer request.
 */
class FlightLegDto {
    origin;
    destination;
    date;
}
exports.FlightLegDto = FlightLegDto;
__decorate([
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], FlightLegDto.prototype, "origin", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], FlightLegDto.prototype, "destination", void 0);
__decorate([
    (0, class_validator_1.IsDateString)(),
    __metadata("design:type", Date)
], FlightLegDto.prototype, "date", void 0);
class FlightSearchDto {
    origin;
    destination;
    departure;
    returnDate;
    passengers;
    /**
     * A multi-city itinerary (owner decision, 2026-10-20). When present it
     * REPLACES the single origin/destination/departure triple: one leg per
     * slice, in order. The legacy fields stay for one-way and round-trip.
     */
    legs;
    /** MarketContext selector (ISO-3166-1 alpha-2). Display currency/locale. */
    market;
    /** Informational traveller context; providers do not receive this field. */
    mood;
}
exports.FlightSearchDto = FlightSearchDto;
__decorate([
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], FlightSearchDto.prototype, "origin", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], FlightSearchDto.prototype, "destination", void 0);
__decorate([
    (0, class_validator_1.IsDateString)(),
    __metadata("design:type", Date)
], FlightSearchDto.prototype, "departure", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsDateString)(),
    __metadata("design:type", Date)
], FlightSearchDto.prototype, "returnDate", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsInt)(),
    (0, class_validator_1.Min)(1),
    __metadata("design:type", Number)
], FlightSearchDto.prototype, "passengers", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsArray)(),
    (0, class_validator_1.ArrayMinSize)(2),
    (0, class_validator_1.ArrayMaxSize)(6),
    (0, class_validator_1.ValidateNested)({ each: true }),
    (0, class_transformer_1.Type)(() => FlightLegDto),
    __metadata("design:type", Array)
], FlightSearchDto.prototype, "legs", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], FlightSearchDto.prototype, "market", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsIn)([...travel_mood_1.TRAVEL_MOODS]),
    __metadata("design:type", String)
], FlightSearchDto.prototype, "mood", void 0);
//# sourceMappingURL=flight.search.dto.js.map