"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.RecommendModule = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const recommended_hotel_service_1 = require("./recommended-hotel.service");
const recommended_hotels_controller_1 = require("./recommended-hotels.controller");
const nuitee_module_1 = require("../nuitee/nuitee.module");
const profile_module_1 = require("../profile/profile.module");
const ai_module_1 = require("../ai/ai.module");
const user_profile_entity_1 = require("../../database/entities/user_profile.entity");
let RecommendModule = class RecommendModule {
};
exports.RecommendModule = RecommendModule;
exports.RecommendModule = RecommendModule = __decorate([
    (0, common_1.Module)({
        imports: [
            nuitee_module_1.NuiteeModule,
            profile_module_1.ProfileModule,
            ai_module_1.AiModule,
            typeorm_1.TypeOrmModule.forFeature([user_profile_entity_1.UserProfile]),
        ],
        controllers: [recommended_hotels_controller_1.RecommendedHotelsController],
        providers: [recommended_hotel_service_1.RecommendedHotelService],
        exports: [recommended_hotel_service_1.RecommendedHotelService],
    })
], RecommendModule);
//# sourceMappingURL=recommend.module.js.map