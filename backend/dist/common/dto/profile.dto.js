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
exports.UpdateProfilePreferencesDto = void 0;
const class_validator_1 = require("class-validator");
/**
 * Explicit recommendation preferences a user (or the engine) can persist.
 * Free-form object so new signal types don't require migrations:
 *   { budgetMin, budgetMax, preferredStars, amenities, preferredDestinations }
 */
class UpdateProfilePreferencesDto {
    preferences;
    personalizationEnabled;
    countryCode;
    countryConfidence;
}
exports.UpdateProfilePreferencesDto = UpdateProfilePreferencesDto;
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsObject)(),
    __metadata("design:type", Object)
], UpdateProfilePreferencesDto.prototype, "preferences", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsBoolean)(),
    __metadata("design:type", Boolean)
], UpdateProfilePreferencesDto.prototype, "personalizationEnabled", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.Matches)(/^[A-Za-z]{2}$/),
    __metadata("design:type", String)
], UpdateProfilePreferencesDto.prototype, "countryCode", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsIn)(['high', 'medium', 'low']),
    __metadata("design:type", String)
], UpdateProfilePreferencesDto.prototype, "countryConfidence", void 0);
//# sourceMappingURL=profile.dto.js.map