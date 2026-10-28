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
exports.UserProfile = void 0;
const typeorm_1 = require("typeorm");
/**
 * Aggregated user profile for the recommendation engine (workstream R).
 *
 * Combines explicit preferences (set by the user or updated implicitly) with
 * derived behavioural signals. Stored as JSON so the schema can grow without
 * migrations. Optional for guests: rows exist only for registered users
 * (userId) — guest behaviour lives in the user_events table keyed by deviceId,
 * and the recommendation engine works from events alone for them.
 */
let UserProfile = class UserProfile {
    id;
    userId;
    /** Explicit preferences: price range, star rating, amenities, destinations. */
    preferences;
    /** Derived behavioural profile: top destinations, price band, seasons, etc. */
    derived;
    /** Last country detected (ISO-2) with confidence. */
    countryCode;
    countryConfidence;
    /** Opt-out for personalised recommendations (privacy). */
    personalizationEnabled;
    createdAt;
    updatedAt;
};
exports.UserProfile = UserProfile;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], UserProfile.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ unique: true }),
    __metadata("design:type", String)
], UserProfile.prototype, "userId", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'jsonb', default: () => "'{}'::jsonb" }),
    __metadata("design:type", Object)
], UserProfile.prototype, "preferences", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'jsonb', default: () => "'{}'::jsonb" }),
    __metadata("design:type", Object)
], UserProfile.prototype, "derived", void 0);
__decorate([
    (0, typeorm_1.Column)({ nullable: true }),
    __metadata("design:type", String)
], UserProfile.prototype, "countryCode", void 0);
__decorate([
    (0, typeorm_1.Column)({ nullable: true }),
    __metadata("design:type", String)
], UserProfile.prototype, "countryConfidence", void 0);
__decorate([
    (0, typeorm_1.Column)({ default: false }),
    __metadata("design:type", Boolean)
], UserProfile.prototype, "personalizationEnabled", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)(),
    __metadata("design:type", Date)
], UserProfile.prototype, "createdAt", void 0);
__decorate([
    (0, typeorm_1.UpdateDateColumn)(),
    __metadata("design:type", Date)
], UserProfile.prototype, "updatedAt", void 0);
exports.UserProfile = UserProfile = __decorate([
    (0, typeorm_1.Entity)('user_profiles')
], UserProfile);
//# sourceMappingURL=user_profile.entity.js.map