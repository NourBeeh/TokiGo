"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.HomeModule = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const home_section_entity_1 = require("../../database/entities/home_section.entity");
const home_card_entity_1 = require("../../database/entities/home_card.entity");
const nuitee_module_1 = require("../nuitee/nuitee.module");
const cache_module_1 = require("../cache/cache.module");
const duffel_module_1 = require("../duffel/duffel.module");
const home_controller_1 = require("./home.controller");
const home_service_1 = require("./home.service");
const home_flights_service_1 = require("./home.flights.service");
let HomeModule = class HomeModule {
};
exports.HomeModule = HomeModule;
exports.HomeModule = HomeModule = __decorate([
    (0, common_1.Module)({
        imports: [
            typeorm_1.TypeOrmModule.forFeature([home_section_entity_1.HomeSection, home_card_entity_1.HomeCard]),
            // Real hotel source (Nuitee) + real flight source (Duffel) + the
            // short-TTL snapshot cache.
            nuitee_module_1.NuiteeModule,
            duffel_module_1.DuffelModule,
            cache_module_1.CacheModule,
        ],
        controllers: [home_controller_1.HomeController],
        providers: [home_service_1.HomeService, home_flights_service_1.HomeFlightsService],
    })
], HomeModule);
//# sourceMappingURL=home.module.js.map