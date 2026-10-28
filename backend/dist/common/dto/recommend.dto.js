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
exports.RecommendedHotelsQueryDto = void 0;
const class_validator_1 = require("class-validator");
const class_transformer_1 = require("class-transformer");
class RecommendedHotelsQueryDto {
    /** Number of cards to return (5-10, default 6). */
    limit;
    /**
     * Country code (ISO-2). The engine enriches from the profile/geo when absent.
     * Normalised to upper-case before validation so `eg` and ` EG ` are the same
     * market instead of two different cache identities.
     */
    code;
}
exports.RecommendedHotelsQueryDto = RecommendedHotelsQueryDto;
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_transformer_1.Transform)(({ value }) => parseInt(value, 10)),
    (0, class_validator_1.IsInt)(),
    (0, class_validator_1.Min)(1),
    (0, class_validator_1.Max)(12),
    __metadata("design:type", Number)
], RecommendedHotelsQueryDto.prototype, "limit", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_transformer_1.Transform)(({ value }) => typeof value === 'string' ? value.trim().toUpperCase() : value),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.Matches)(/^[A-Z]{2}$/, { message: 'code must be an ISO-2 country code' }),
    __metadata("design:type", String)
], RecommendedHotelsQueryDto.prototype, "code", void 0);
//# sourceMappingURL=recommend.dto.js.map