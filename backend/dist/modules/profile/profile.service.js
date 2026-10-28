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
exports.ProfileService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const user_profile_entity_1 = require("../../database/entities/user_profile.entity");
let ProfileService = class ProfileService {
    profiles;
    constructor(profiles) {
        this.profiles = profiles;
    }
    /** Returns the user's profile, creating a sensible default on first use. */
    async getOrCreate(userId) {
        const existing = await this.profiles.findOne({ where: { userId } });
        if (existing)
            return existing;
        const created = await this.profiles.save(this.profiles.create({ userId }));
        return created;
    }
    async getView(userId) {
        const profile = await this.getOrCreate(userId);
        return this.toView(profile);
    }
    /** Merges explicit preferences (deep merge of scalar + array patch). */
    async updatePreferences(userId, patch) {
        const profile = await this.getOrCreate(userId);
        if (patch.preferences !== undefined) {
            profile.preferences = {
                ...(profile.preferences ?? {}),
                ...patch.preferences,
            };
        }
        if (patch.personalizationEnabled !== undefined) {
            profile.personalizationEnabled = patch.personalizationEnabled;
        }
        const saved = await this.profiles.save(profile);
        return this.toView(saved);
    }
    /** Engine-side update used by the events aggregator (not exposed publicly). */
    async updateDerived(userId, derived) {
        const profile = await this.getOrCreate(userId);
        profile.derived = { ...(profile.derived ?? {}), ...derived };
        return this.profiles.save(profile);
    }
    async setCountry(userId, countryCode, confidence) {
        const profile = await this.getOrCreate(userId);
        profile.countryCode = countryCode;
        profile.countryConfidence = confidence;
        return this.profiles.save(profile);
    }
    /** Updates the country only when the new detection is more confident. */
    async setCountryIfMoreConfident(userId, countryCode, confidence) {
        const profile = await this.getOrCreate(userId);
        const order = { low: 0, medium: 1, high: 2 };
        const current = profile.countryConfidence ?? 'low';
        const incoming = confidence;
        if (order[incoming] >= order[current]) {
            profile.countryCode = countryCode;
            profile.countryConfidence = confidence;
            return this.profiles.save(profile);
        }
        return profile;
    }
    async findByCountry(countryCode) {
        return this.profiles.find({ where: { countryCode } });
    }
    toView(profile) {
        if (!profile)
            throw new common_1.NotFoundException('Profile not found.');
        return {
            userId: profile.userId,
            preferences: profile.preferences ?? {},
            derived: profile.derived ?? {},
            countryCode: profile.countryCode,
            countryConfidence: profile.countryConfidence,
            personalizationEnabled: profile.personalizationEnabled ?? true,
            updatedAt: profile.updatedAt,
        };
    }
};
exports.ProfileService = ProfileService;
exports.ProfileService = ProfileService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(user_profile_entity_1.UserProfile)),
    __metadata("design:paramtypes", [typeorm_2.Repository])
], ProfileService);
//# sourceMappingURL=profile.service.js.map