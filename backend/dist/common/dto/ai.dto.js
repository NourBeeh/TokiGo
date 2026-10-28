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
exports.AiChatDto = exports.AiSuggestDto = exports.AiQueryDto = exports.AiContextDto = exports.TravelDatesDto = exports.GeolocationDto = void 0;
const class_validator_1 = require("class-validator");
const class_transformer_1 = require("class-transformer");
/** Geolocation coordinates for context-aware AI queries */
class GeolocationDto {
    lat;
    lng;
}
exports.GeolocationDto = GeolocationDto;
__decorate([
    (0, class_validator_1.IsOptional)(),
    __metadata("design:type", Number)
], GeolocationDto.prototype, "lat", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    __metadata("design:type", Number)
], GeolocationDto.prototype, "lng", void 0);
/** Travel date range for context-aware AI queries */
class TravelDatesDto {
    from; // ISO 8601 date string
    to; // ISO 8601 date string
}
exports.TravelDatesDto = TravelDatesDto;
__decorate([
    (0, class_validator_1.IsOptional)(),
    __metadata("design:type", String)
], TravelDatesDto.prototype, "from", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    __metadata("design:type", String)
], TravelDatesDto.prototype, "to", void 0);
/** Full context object for AI queries, matching Flutter's AiQueryContext */
class AiContextDto {
    route;
    screenTitle;
    selectedOfferIds;
    geolocation;
    travelDates;
    metadata;
}
exports.AiContextDto = AiContextDto;
__decorate([
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], AiContextDto.prototype, "route", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], AiContextDto.prototype, "screenTitle", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    __metadata("design:type", Array)
], AiContextDto.prototype, "selectedOfferIds", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.ValidateNested)(),
    (0, class_transformer_1.Type)(() => GeolocationDto),
    __metadata("design:type", GeolocationDto)
], AiContextDto.prototype, "geolocation", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.ValidateNested)(),
    (0, class_transformer_1.Type)(() => TravelDatesDto),
    __metadata("design:type", TravelDatesDto)
], AiContextDto.prototype, "travelDates", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    __metadata("design:type", Object)
], AiContextDto.prototype, "metadata", void 0);
/** POST /ai/query request body. White-listed by the global ValidationPipe. */
class AiQueryDto {
    prompt;
    context;
}
exports.AiQueryDto = AiQueryDto;
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.IsNotEmpty)({ message: 'prompt must not be empty' }),
    (0, class_validator_1.MaxLength)(4000, { message: 'prompt must be at most 4000 characters' }),
    __metadata("design:type", String)
], AiQueryDto.prototype, "prompt", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.ValidateNested)(),
    (0, class_transformer_1.Type)(() => AiContextDto),
    __metadata("design:type", AiContextDto)
], AiQueryDto.prototype, "context", void 0);
/**
 * POST /ai/suggest request body — live typeahead for the smart search sheet.
 * `query` is deliberately short: this is a partial prompt, not a full one.
 */
class AiSuggestDto {
    query;
}
exports.AiSuggestDto = AiSuggestDto;
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.IsNotEmpty)({ message: 'query must not be empty' }),
    (0, class_validator_1.MaxLength)(120, { message: 'query must be at most 120 characters' }),
    __metadata("design:type", String)
], AiSuggestDto.prototype, "query", void 0);
/**
 * POST /ai/chat request body (Phase 2C-B). Same prompt contract as
 * AiQueryDto; the endpoint itself is JWT-only and enriches the call with
 * the caller's relevant explicit conversation memories server-side.
 */
class AiChatDto {
    prompt;
    context;
}
exports.AiChatDto = AiChatDto;
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.IsNotEmpty)({ message: 'prompt must not be empty' }),
    (0, class_validator_1.MaxLength)(4000, { message: 'prompt must be at most 4000 characters' }),
    __metadata("design:type", String)
], AiChatDto.prototype, "prompt", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.ValidateNested)(),
    (0, class_transformer_1.Type)(() => AiContextDto),
    __metadata("design:type", AiContextDto)
], AiChatDto.prototype, "context", void 0);
//# sourceMappingURL=ai.dto.js.map