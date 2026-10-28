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
exports.ProfileController = void 0;
const common_1 = require("@nestjs/common");
const jwt_auth_guard_1 = require("../auth/jwt-auth.guard");
const profile_dto_1 = require("../../common/dto/profile.dto");
const profile_service_1 = require("./profile.service");
const derived_preference_profile_service_1 = require("../memory/derived_preference_profile.service");
const explicit_preference_signal_service_1 = require("../memory/explicit_preference_signal.service");
/**
 * User profile for personalization (workstream R). Requires a valid JWT.
 * Guards read the user id from the request (JwtStrategy attaches the entity).
 */
let ProfileController = class ProfileController {
    profileService;
    derivedService;
    explicitSignalService;
    constructor(profileService, derivedService, explicitSignalService) {
        this.profileService = profileService;
        this.derivedService = derivedService;
        this.explicitSignalService = explicitSignalService;
    }
    async me(req) {
        const view = await this.profileService.getView(userId(req));
        // Phase 2B — attach the computed Derived Preference Profile (additive,
        // backward-compatible field). buildForUserSafe degrades to an empty
        // profile on failure, so /profile/me can never break because of it.
        // PH-7 — attach the separate Explicit Preference Signal (also additive,
        // null when personalization is disabled / no signal / on failure). This
        // is the ONLY place explicit conversation memories may influence Home
        // Ranking; DerivedPreferenceProfile semantics stay untouched.
        return {
            ...view,
            derivedPreferences: await this.derivedService.buildForUserSafe(userId(req), view),
            explicitPreferences: await this.explicitSignalService.buildForUserSafe(userId(req), view.personalizationEnabled),
        };
    }
    async update(req, dto) {
        const id = userId(req);
        if (dto.countryCode) {
            await this.profileService.setCountryIfMoreConfident(id, dto.countryCode.toUpperCase(), dto.countryConfidence ?? 'low');
        }
        if (dto.preferences !== undefined || dto.personalizationEnabled !== undefined) {
            return this.profileService.updatePreferences(id, dto);
        }
        return this.profileService.getView(id);
    }
};
exports.ProfileController = ProfileController;
__decorate([
    (0, common_1.Get)('me'),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], ProfileController.prototype, "me", null);
__decorate([
    (0, common_1.Patch)('me'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, profile_dto_1.UpdateProfilePreferencesDto]),
    __metadata("design:returntype", Promise)
], ProfileController.prototype, "update", null);
exports.ProfileController = ProfileController = __decorate([
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, common_1.Controller)('profile'),
    __metadata("design:paramtypes", [profile_service_1.ProfileService,
        derived_preference_profile_service_1.DerivedPreferenceProfileService,
        explicit_preference_signal_service_1.ExplicitPreferenceSignalService])
], ProfileController);
/** Passport's Express.User is an empty interface; the JWT strategy attaches
 * the full user entity, so the id is safely readable here. */
function userId(req) {
    const user = req.user;
    if (!user?.id)
        throw new Error('Authenticated request missing user id.');
    return user.id;
}
//# sourceMappingURL=profile.controller.js.map