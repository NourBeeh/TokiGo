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
exports.MemoryController = void 0;
const common_1 = require("@nestjs/common");
const jwt_auth_guard_1 = require("../auth/jwt-auth.guard");
const memory_dto_1 = require("../../common/dto/memory.dto");
const memory_service_1 = require("./memory.service");
/**
 * User Memory Spine API (Phase 2A — Foundation).
 *
 * SECURITY MODEL: every route derives the caller identity from the JWT via
 * [userId] below — the request can NEVER specify or observe another user's
 * id. There is deliberately no `GET /memory/:userId` route; the listing
 * surface is `/memory/me` only, and every mutation verifies ownership in the
 * service layer (defense in depth on top of the route shape).
 */
let MemoryController = class MemoryController {
    memoryService;
    constructor(memoryService) {
        this.memoryService = memoryService;
    }
    /** Lists the caller's memories (updatedAt DESC; expired hidden by default). */
    async listMine(req, query) {
        return this.memoryService.listForUser(userId(req), {
            type: query.type,
            source: query.source,
            includeExpired: query.includeExpired,
        });
    }
    /** Records (or updates) one structured fact for the caller. */
    async create(req, dto) {
        return this.memoryService.upsert(userId(req), dto);
    }
    /** Updates a memory owned by the caller (value/source/confidence/expiry). */
    async update(req, id, dto) {
        return this.memoryService.updateOwn(userId(req), id, dto);
    }
    /** Deletes one memory owned by the caller. */
    async remove(req, id) {
        await this.memoryService.deleteOwn(userId(req), id);
        return { deleted: true };
    }
    /** Clears ALL memories owned by the caller ("Forget everything"). */
    async clearMine(req) {
        await this.memoryService.clearOwn(userId(req));
        return { cleared: true };
    }
};
exports.MemoryController = MemoryController;
__decorate([
    (0, common_1.Get)('me'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Query)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, memory_dto_1.ListMemoryQueryDto]),
    __metadata("design:returntype", Promise)
], MemoryController.prototype, "listMine", null);
__decorate([
    (0, common_1.Post)(),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, memory_dto_1.CreateMemoryDto]),
    __metadata("design:returntype", Promise)
], MemoryController.prototype, "create", null);
__decorate([
    (0, common_1.Patch)(':id'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(2, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String, memory_dto_1.UpdateMemoryDto]),
    __metadata("design:returntype", Promise)
], MemoryController.prototype, "update", null);
__decorate([
    (0, common_1.Delete)(':id'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", Promise)
], MemoryController.prototype, "remove", null);
__decorate([
    (0, common_1.Delete)('me'),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], MemoryController.prototype, "clearMine", null);
exports.MemoryController = MemoryController = __decorate([
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, common_1.Controller)('memory'),
    __metadata("design:paramtypes", [memory_service_1.MemoryService])
], MemoryController);
/** Passport's Express.User is an empty interface; the JWT strategy attaches
 * the full user entity, so the id is safely readable here. */
function userId(req) {
    const user = req.user;
    if (!user?.id)
        throw new Error('Authenticated request missing user id.');
    return user.id;
}
//# sourceMappingURL=memory.controller.js.map