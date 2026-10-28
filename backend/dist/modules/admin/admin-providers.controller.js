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
exports.AdminProvidersController = void 0;
const common_1 = require("@nestjs/common");
const jwt_auth_guard_1 = require("../auth/jwt-auth.guard");
const roles_guard_1 = require("../../common/guards/roles.guard");
const roles_decorator_1 = require("../../common/decorators/roles.decorator");
const admin_dto_1 = require("../../common/dto/admin.dto");
const admin_service_1 = require("./admin.service");
/**
 * Admin provider management (ADM-B1): switch active providers per vertical,
 * reorder priorities, edit config and probe health — all at runtime, no
 * backend restart required.
 */
let AdminProvidersController = class AdminProvidersController {
    admin;
    constructor(admin) {
        this.admin = admin;
    }
    listProviders() {
        return this.admin.listProviders();
    }
    setStatus(key, dto, req) {
        return this.admin.setProviderStatus(key, dto.isActive, adminUserId(req));
    }
    setPriority(key, dto, req) {
        return this.admin.setProviderPriority(key, dto.priority, adminUserId(req));
    }
    setConfig(key, dto, req) {
        return this.admin.setProviderConfig(key, dto.config, adminUserId(req));
    }
    healthCheck(key, req) {
        return this.admin.runHealthCheck(key, adminUserId(req));
    }
    refreshRegistry(req) {
        return this.admin.refreshRegistry(adminUserId(req));
    }
};
exports.AdminProvidersController = AdminProvidersController;
__decorate([
    (0, common_1.Get)(),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], AdminProvidersController.prototype, "listProviders", null);
__decorate([
    (0, common_1.Patch)(':key/status'),
    __param(0, (0, common_1.Param)('key')),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, admin_dto_1.UpdateProviderStatusDto, Object]),
    __metadata("design:returntype", void 0)
], AdminProvidersController.prototype, "setStatus", null);
__decorate([
    (0, common_1.Patch)(':key/priority'),
    __param(0, (0, common_1.Param)('key')),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, admin_dto_1.UpdateProviderPriorityDto, Object]),
    __metadata("design:returntype", void 0)
], AdminProvidersController.prototype, "setPriority", null);
__decorate([
    (0, common_1.Patch)(':key/config'),
    __param(0, (0, common_1.Param)('key')),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, admin_dto_1.UpdateProviderConfigDto, Object]),
    __metadata("design:returntype", void 0)
], AdminProvidersController.prototype, "setConfig", null);
__decorate([
    (0, common_1.Post)(':key/health-check'),
    __param(0, (0, common_1.Param)('key')),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", void 0)
], AdminProvidersController.prototype, "healthCheck", null);
__decorate([
    (0, common_1.Post)('refresh-registry'),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", void 0)
], AdminProvidersController.prototype, "refreshRegistry", null);
exports.AdminProvidersController = AdminProvidersController = __decorate([
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, roles_guard_1.RolesGuard),
    (0, roles_decorator_1.Roles)('admin'),
    (0, common_1.Controller)('admin/providers'),
    __metadata("design:paramtypes", [admin_service_1.AdminService])
], AdminProvidersController);
/** Passport's Express.User is an empty interface; the JWT strategy always
 * attaches the full user entity, so the id is safely readable here. */
function adminUserId(req) {
    const user = req.user;
    return user?.id;
}
//# sourceMappingURL=admin-providers.controller.js.map