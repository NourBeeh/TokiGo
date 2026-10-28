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
exports.AdminController = void 0;
const common_1 = require("@nestjs/common");
const jwt_auth_guard_1 = require("../auth/jwt-auth.guard");
const roles_guard_1 = require("../../common/guards/roles.guard");
const roles_decorator_1 = require("../../common/decorators/roles.decorator");
const admin_dto_1 = require("../../common/dto/admin.dto");
const admin_service_1 = require("./admin.service");
/**
 * Admin-only Home content management. Every route requires a valid JWT whose
 * user carries `role === 'admin'` (JwtAuthGuard then RolesGuard).
 */
let AdminController = class AdminController {
    admin;
    constructor(admin) {
        this.admin = admin;
    }
    // ---------- Home sections ----------
    listSections() {
        return this.admin.listSections();
    }
    createSection(dto, req) {
        return this.admin.createSection(dto, adminUserId(req));
    }
    updateSection(id, dto, req) {
        return this.admin.updateSection(id, dto, adminUserId(req));
    }
    async deleteSection(id, req) {
        await this.admin.deleteSection(id, adminUserId(req));
        return { deleted: true };
    }
    async reorderSections(dto, req) {
        await this.admin.reorderSections(dto, adminUserId(req));
        return { reordered: true };
    }
    // ---------- Home cards ----------
    createCard(dto, req) {
        return this.admin.createCard(dto, adminUserId(req));
    }
    updateCard(id, dto, req) {
        return this.admin.updateCard(id, dto, adminUserId(req));
    }
    async deleteCard(id, req) {
        await this.admin.deleteCard(id, adminUserId(req));
        return { deleted: true };
    }
    async reorderCards(dto, req) {
        await this.admin.reorderCards(dto, adminUserId(req));
        return { reordered: true };
    }
    // ---------- Audit ----------
    auditLogs(limit) {
        return this.admin.listAuditLogs(limit ? Number(limit) : 50);
    }
};
exports.AdminController = AdminController;
__decorate([
    (0, common_1.Get)('home/sections'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], AdminController.prototype, "listSections", null);
__decorate([
    (0, common_1.Post)('home/sections'),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [admin_dto_1.CreateSectionDto, Object]),
    __metadata("design:returntype", void 0)
], AdminController.prototype, "createSection", null);
__decorate([
    (0, common_1.Patch)('home/sections/:id'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, admin_dto_1.UpdateSectionDto, Object]),
    __metadata("design:returntype", void 0)
], AdminController.prototype, "updateSection", null);
__decorate([
    (0, common_1.Delete)('home/sections/:id'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", Promise)
], AdminController.prototype, "deleteSection", null);
__decorate([
    (0, common_1.Post)('home/sections/reorder'),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [admin_dto_1.ReorderDto, Object]),
    __metadata("design:returntype", Promise)
], AdminController.prototype, "reorderSections", null);
__decorate([
    (0, common_1.Post)('home/cards'),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [admin_dto_1.CreateCardDto, Object]),
    __metadata("design:returntype", void 0)
], AdminController.prototype, "createCard", null);
__decorate([
    (0, common_1.Patch)('home/cards/:id'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, admin_dto_1.UpdateCardDto, Object]),
    __metadata("design:returntype", void 0)
], AdminController.prototype, "updateCard", null);
__decorate([
    (0, common_1.Delete)('home/cards/:id'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", Promise)
], AdminController.prototype, "deleteCard", null);
__decorate([
    (0, common_1.Post)('home/cards/reorder'),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [admin_dto_1.ReorderDto, Object]),
    __metadata("design:returntype", Promise)
], AdminController.prototype, "reorderCards", null);
__decorate([
    (0, common_1.Get)('audit-logs'),
    __param(0, (0, common_1.Query)('limit')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], AdminController.prototype, "auditLogs", null);
exports.AdminController = AdminController = __decorate([
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, roles_guard_1.RolesGuard),
    (0, roles_decorator_1.Roles)('admin'),
    (0, common_1.Controller)('admin'),
    __metadata("design:paramtypes", [admin_service_1.AdminService])
], AdminController);
/** Passport's Express.User is an empty interface; the JWT strategy always
 * attaches the full user entity, so the id is safely readable here. */
function adminUserId(req) {
    const user = req.user;
    return user?.id;
}
//# sourceMappingURL=admin.controller.js.map