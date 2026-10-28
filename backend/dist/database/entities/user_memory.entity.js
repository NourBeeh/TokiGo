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
exports.UserMemory = void 0;
const typeorm_1 = require("typeorm");
/**
 * User Memory Spine (Phase 2A — Foundation).
 *
 * One structured fact about a user — NOT a conversation transcript store:
 * each record is a small, typed `key → value` fact with provenance (source)
 * and a validated confidence. Everything flows from the JWT-authenticated
 * user; the client can never supply or query another user's memories.
 *
 * Logical uniqueness is enforced at the DATABASE level on
 * (userId, type, key): re-recording the same fact updates it instead of
 * piling duplicates (upsert semantics live in MemoryService).
 *
 * Supported types:   preference | behavior | conversation | derived
 * Supported sources: user_explicit | behavior_event | ai_conversation |
 *                    system_derived
 * (Validated at the DTO boundary via MEMORY_TYPES / MEMORY_SOURCES.)
 */
let UserMemory = class UserMemory {
    id;
    /** Owning user — ALWAYS derived from the JWT, never from the request body. */
    userId;
    /** Fact category (see MEMORY_TYPES in common/dto/memory.dto.ts). */
    type;
    /** Stable fact key, e.g. `preferred_destination`, `budget_max`. */
    key;
    /** Structured fact value ONLY (jsonb) — transcripts are rejected upstream. */
    value;
    /** Provenance (see MEMORY_SOURCES in common/dto/memory.dto.ts). */
    source;
    /** 0.0 <= confidence <= 1.0 — validated at the DTO boundary. */
    confidence;
    /** Optional expiry — expired records stay persisted but are hidden from
     * the default GET listing until includeExpired is requested. */
    expiresAt;
    createdAt;
    updatedAt;
};
exports.UserMemory = UserMemory;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], UserMemory.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)(),
    __metadata("design:type", String)
], UserMemory.prototype, "userId", void 0);
__decorate([
    (0, typeorm_1.Column)(),
    __metadata("design:type", String)
], UserMemory.prototype, "type", void 0);
__decorate([
    (0, typeorm_1.Column)(),
    __metadata("design:type", String)
], UserMemory.prototype, "key", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'jsonb' }),
    __metadata("design:type", Object)
], UserMemory.prototype, "value", void 0);
__decorate([
    (0, typeorm_1.Column)(),
    __metadata("design:type", String)
], UserMemory.prototype, "source", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'real', default: 1 }),
    __metadata("design:type", Number)
], UserMemory.prototype, "confidence", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'timestamp', nullable: true }),
    __metadata("design:type", Object)
], UserMemory.prototype, "expiresAt", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)(),
    __metadata("design:type", Date)
], UserMemory.prototype, "createdAt", void 0);
__decorate([
    (0, typeorm_1.UpdateDateColumn)(),
    __metadata("design:type", Date)
], UserMemory.prototype, "updatedAt", void 0);
exports.UserMemory = UserMemory = __decorate([
    (0, typeorm_1.Entity)('user_memories'),
    (0, typeorm_1.Index)('idx_user_memories_user_type_key', ['userId', 'type', 'key'], {
        unique: true,
    })
], UserMemory);
//# sourceMappingURL=user_memory.entity.js.map