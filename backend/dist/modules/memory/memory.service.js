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
var MemoryService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.MemoryService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const user_memory_entity_1 = require("../../database/entities/user_memory.entity");
const memory_dto_1 = require("../../common/dto/memory.dto");
/**
 * Memory Spine service (Phase 2A — Foundation).
 *
 * User-owned facts with provenance and confidence. Every method takes the
 * caller's userId from the JWT — there is no code path where a client can
 * read, mutate, or clear another user's memories.
 *
 * Behaviour contracts (documented + tested):
 * - Listing is deterministic: `updatedAt DESC`, optional type/source
 *   filters, and EXPIRED records hidden by default (includeExpired to see
 *   them; nothing is ever auto-deleted in 2A).
 * - Recording the same logical fact (userId+type+key) UPDATES the existing
 *   row (value/source/confidence/expiresAt/updatedAt) instead of creating
 *   a duplicate. The DB backs this with a unique index.
 * - The value tree must be structured facts: any sensitive key
 *   (credentials/payment/precise location) at any depth is rejected.
 */
let MemoryService = MemoryService_1 = class MemoryService {
    memories;
    logger = new common_1.Logger(MemoryService_1.name);
    constructor(memories) {
        this.memories = memories;
    }
    /** Lists the caller's memories, newest first, expired hidden by default. */
    async listForUser(userId, opts = {}) {
        const rows = await this.memories.find({
            where: {
                userId,
                ...(opts.type ? { type: opts.type } : {}),
                ...(opts.source ? { source: opts.source } : {}),
            },
            order: { updatedAt: 'DESC' },
        });
        if (opts.includeExpired)
            return rows;
        const now = Date.now();
        return rows.filter((r) => {
            const expiry = r.expiresAt ? new Date(r.expiresAt).getTime() : null;
            return expiry === null || expiry > now;
        });
    }
    /**
     * Finds one behavioral memory row by its exact key (Phase 2B read helper
     * for extraction/dedup). Expired rows are still returned — the caller
     * decides semantics; nothing is auto-deleted.
     */
    async findBehavioral(userId, key) {
        try {
            const rows = await this.memories.find({
                where: { userId, type: 'behavior', key },
            });
            return rows[0] ?? null;
        }
        catch (error) {
            this.logger.warn(`findBehavioral failed (${key}): ${error.message}`);
            return null;
        }
    }
    /**
     * Creates the fact or updates the existing row for the same logical
     * memory (userId+type+key) — no duplicate accumulation.
     */
    async upsert(userId, dto) {
        if ((0, memory_dto_1.containsSensitiveData)(dto.value)) {
            throw new common_1.BadRequestException('Memory value contains forbidden (sensitive) keys.');
        }
        // Phase 2D — single-line strings only (prompt line-forgery guard).
        if ((0, memory_dto_1.containsControlCharacters)(dto.value)) {
            throw new common_1.BadRequestException('Memory value must not contain control characters.');
        }
        const existing = await this.memories.findOne({
            where: { userId, type: dto.type, key: dto.key },
        });
        if (existing) {
            existing.value = dto.value;
            existing.source = dto.source;
            if (dto.confidence !== undefined) {
                existing.confidence = dto.confidence;
            }
            existing.expiresAt = dto.expiresAt ? new Date(dto.expiresAt) : null;
            return this.memories.save(existing);
        }
        const created = this.memories.create({
            userId,
            type: dto.type,
            key: dto.key,
            value: dto.value,
            source: dto.source,
            confidence: dto.confidence ?? 1,
            expiresAt: dto.expiresAt ? new Date(dto.expiresAt) : null,
        });
        return this.memories.save(created);
    }
    /** Updates a memory owned by [userId]; foreign records are Forbidden. */
    async updateOwn(userId, id, dto) {
        if (dto.value !== undefined && (0, memory_dto_1.containsSensitiveData)(dto.value)) {
            throw new common_1.BadRequestException('Memory value contains forbidden (sensitive) keys.');
        }
        // Phase 2D — single-line strings only (prompt line-forgery guard).
        if (dto.value !== undefined && (0, memory_dto_1.containsControlCharacters)(dto.value)) {
            throw new common_1.BadRequestException('Memory value must not contain control characters.');
        }
        const memory = await this.memories.findOne({ where: { id } });
        if (!memory)
            throw new common_1.NotFoundException('Memory not found.');
        if (memory.userId !== userId) {
            throw new common_1.ForbiddenException('Not your memory.');
        }
        if (dto.value !== undefined)
            memory.value = dto.value;
        if (dto.source !== undefined)
            memory.source = dto.source;
        if (dto.confidence !== undefined)
            memory.confidence = dto.confidence;
        if (dto.expiresAt !== undefined) {
            memory.expiresAt = dto.expiresAt ? new Date(dto.expiresAt) : null;
        }
        return this.memories.save(memory);
    }
    /** Deletes one memory owned by [userId]; foreign records are Forbidden. */
    async deleteOwn(userId, id) {
        const memory = await this.memories.findOne({ where: { id } });
        if (!memory)
            throw new common_1.NotFoundException('Memory not found.');
        if (memory.userId !== userId) {
            throw new common_1.ForbiddenException('Not your memory.');
        }
        await this.memories.delete({ id });
    }
    /** Clears EVERY memory owned by [userId] — and only those. */
    async clearOwn(userId) {
        await this.memories.delete({ userId });
    }
};
exports.MemoryService = MemoryService;
exports.MemoryService = MemoryService = MemoryService_1 = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(user_memory_entity_1.UserMemory)),
    __metadata("design:paramtypes", [typeorm_2.Repository])
], MemoryService);
//# sourceMappingURL=memory.service.js.map