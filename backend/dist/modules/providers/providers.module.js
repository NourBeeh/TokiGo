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
exports.ProvidersModule = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const provider_entity_1 = require("../../database/entities/provider.entity");
const provider_registry_impl_1 = require("../../common/providers/provider.registry.impl");
const provider_instances_1 = require("./provider.instances");
const registry_sync_service_1 = require("./registry.sync.service");
const mock_flight_provider_1 = require("./adapters/mock.flight.provider");
const mock_hotel_provider_1 = require("./adapters/mock.hotel.provider");
const mock_car_provider_1 = require("./adapters/mock.car.provider");
const search_controller_1 = require("./search.controller");
const search_service_1 = require("./search.service");
const duffel_service_1 = require("../duffel/duffel.service");
const duffel_hotel_service_1 = require("../duffel/duffel.hotel.service");
const nuitee_service_1 = require("../nuitee/nuitee.service");
const nuitee_flight_service_1 = require("../nuitee/nuitee.flight.service");
const fx_service_1 = require("../../common/market/fx.service");
const pricing_service_1 = require("../../common/market/pricing.service");
let ProvidersModule = class ProvidersModule {
    registry;
    instances;
    sync;
    mockFlightProvider;
    duffelService;
    duffelHotelService;
    mockHotelProvider;
    mockCarProvider;
    nuiteeService;
    nuiteeFlightService;
    constructor(registry, instances, sync, mockFlightProvider, duffelService, duffelHotelService, mockHotelProvider, mockCarProvider, nuiteeService, nuiteeFlightService) {
        this.registry = registry;
        this.instances = instances;
        this.sync = sync;
        this.mockFlightProvider = mockFlightProvider;
        this.duffelService = duffelService;
        this.duffelHotelService = duffelHotelService;
        this.mockHotelProvider = mockHotelProvider;
        this.mockCarProvider = mockCarProvider;
        this.nuiteeService = nuiteeService;
        this.nuiteeFlightService = nuiteeFlightService;
    }
    async onModuleInit() {
        // Every constructed adapter is registered by its stable providerId — the
        // same key the `providers` table uses. Health checks must reach disabled
        // providers too, so registration is unconditional.
        this.instances.register('mock-flight', this.mockFlightProvider);
        this.instances.register('duffel-flight', this.duffelService);
        this.instances.register('nuitee-flight', this.nuiteeFlightService);
        this.instances.register('mock-hotel', this.mockHotelProvider);
        this.instances.register('nuitee', this.nuiteeService);
        this.instances.register('duffel-hotel', this.duffelHotelService);
        this.instances.register('mock-car', this.mockCarProvider);
        try {
            await this.sync.refresh();
            return;
        }
        catch (error) {
            // DB unavailable: keep the search endpoints working exactly as before
            // (ADM-B1 requirement — zero behaviour change when the DB is down). The
            // legacy ordering: Nuitee is now DEFAULT for both hotels AND flights
            // (owner decision 2026-10-22), Duffel is DISABLED temporarily.
            this.sync.applyLegacyOrdering({
                flight: [this.nuiteeFlightService],
                hotel: [this.nuiteeService],
                car: [this.mockCarProvider],
            });
        }
    }
};
exports.ProvidersModule = ProvidersModule;
exports.ProvidersModule = ProvidersModule = __decorate([
    (0, common_1.Module)({
        imports: [typeorm_1.TypeOrmModule.forFeature([provider_entity_1.Provider])],
        controllers: [search_controller_1.SearchController],
        providers: [
            provider_registry_impl_1.ProviderRegistryImpl,
            provider_instances_1.ProviderInstances,
            registry_sync_service_1.RegistrySyncService,
            search_service_1.SearchService,
            mock_flight_provider_1.MockFlightProvider,
            mock_hotel_provider_1.MockHotelProvider,
            mock_car_provider_1.MockCarProvider,
            duffel_service_1.DuffelService,
            duffel_hotel_service_1.DuffelHotelService,
            nuitee_service_1.NuiteeService,
            nuitee_flight_service_1.NuiteeFlightService,
            fx_service_1.FxService,
            pricing_service_1.PricingService,
        ],
        exports: [
            provider_registry_impl_1.ProviderRegistryImpl,
            provider_instances_1.ProviderInstances,
            registry_sync_service_1.RegistrySyncService,
            search_service_1.SearchService,
            duffel_service_1.DuffelService,
            duffel_hotel_service_1.DuffelHotelService,
            nuitee_service_1.NuiteeService,
            nuitee_flight_service_1.NuiteeFlightService,
            fx_service_1.FxService,
            pricing_service_1.PricingService,
        ],
    }),
    __metadata("design:paramtypes", [provider_registry_impl_1.ProviderRegistryImpl,
        provider_instances_1.ProviderInstances,
        registry_sync_service_1.RegistrySyncService,
        mock_flight_provider_1.MockFlightProvider,
        duffel_service_1.DuffelService,
        duffel_hotel_service_1.DuffelHotelService,
        mock_hotel_provider_1.MockHotelProvider,
        mock_car_provider_1.MockCarProvider,
        nuitee_service_1.NuiteeService,
        nuitee_flight_service_1.NuiteeFlightService])
], ProvidersModule);
//# sourceMappingURL=providers.module.js.map