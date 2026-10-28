"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.AdminModule = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const audit_log_entity_1 = require("../../database/entities/audit_log.entity");
const home_card_entity_1 = require("../../database/entities/home_card.entity");
const home_section_entity_1 = require("../../database/entities/home_section.entity");
const provider_entity_1 = require("../../database/entities/provider.entity");
const providers_module_1 = require("../providers/providers.module");
const admin_controller_1 = require("./admin.controller");
const admin_providers_controller_1 = require("./admin-providers.controller");
const admin_service_1 = require("./admin.service");
/**
 * Admin workstream:
 * - ADM-A1: Home content management endpoints (/admin/home/*).
 * - ADM-B1: provider switching endpoints (/admin/providers/*) backed by the
 *   persisted `providers` table via ProvidersModule's RegistrySyncService.
 */
let AdminModule = class AdminModule {
};
exports.AdminModule = AdminModule;
exports.AdminModule = AdminModule = __decorate([
    (0, common_1.Module)({
        imports: [
            typeorm_1.TypeOrmModule.forFeature([home_section_entity_1.HomeSection, home_card_entity_1.HomeCard, audit_log_entity_1.AuditLog, provider_entity_1.Provider]),
            providers_module_1.ProvidersModule,
        ],
        controllers: [admin_controller_1.AdminController, admin_providers_controller_1.AdminProvidersController],
        providers: [admin_service_1.AdminService],
    })
], AdminModule);
//# sourceMappingURL=admin.module.js.map