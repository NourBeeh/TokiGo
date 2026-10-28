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
exports.Provider = void 0;
const typeorm_1 = require("typeorm");
let Provider = class Provider {
    id;
    /** Stable key == the provider instance `providerId` (e.g. 'nuitee'). */
    providerKey;
    name;
    config;
    isActive;
    /** Search vertical this provider serves: flight | hotel | car. */
    vertical;
    /** Lower runs first within the vertical (1 = primary). */
    priority;
    /** Marks documented fallback providers (admin UI hint). */
    isFallback;
    /** Last health probe outcome: healthy | unhealthy | unknown. */
    healthStatus;
    latencyMs;
    lastCheckedAt;
    createdAt;
    updatedAt;
};
exports.Provider = Provider;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], Provider.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ unique: true }),
    __metadata("design:type", String)
], Provider.prototype, "providerKey", void 0);
__decorate([
    (0, typeorm_1.Column)(),
    __metadata("design:type", String)
], Provider.prototype, "name", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'jsonb', nullable: true }),
    __metadata("design:type", Object)
], Provider.prototype, "config", void 0);
__decorate([
    (0, typeorm_1.Column)({ default: true }),
    __metadata("design:type", Boolean)
], Provider.prototype, "isActive", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', nullable: true }),
    __metadata("design:type", String)
], Provider.prototype, "vertical", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'int', default: 0 }),
    __metadata("design:type", Number)
], Provider.prototype, "priority", void 0);
__decorate([
    (0, typeorm_1.Column)({ default: false }),
    __metadata("design:type", Boolean)
], Provider.prototype, "isFallback", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', nullable: true, default: 'unknown' }),
    __metadata("design:type", String)
], Provider.prototype, "healthStatus", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'int', nullable: true }),
    __metadata("design:type", Number)
], Provider.prototype, "latencyMs", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'timestamptz', nullable: true }),
    __metadata("design:type", Date)
], Provider.prototype, "lastCheckedAt", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)(),
    __metadata("design:type", Date)
], Provider.prototype, "createdAt", void 0);
__decorate([
    (0, typeorm_1.UpdateDateColumn)(),
    __metadata("design:type", Date)
], Provider.prototype, "updatedAt", void 0);
exports.Provider = Provider = __decorate([
    (0, typeorm_1.Entity)('providers')
], Provider);
//# sourceMappingURL=provider.entity.js.map