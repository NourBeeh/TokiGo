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
var RegistrySyncService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.RegistrySyncService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const provider_entity_1 = require("../../database/entities/provider.entity");
const provider_registry_impl_1 = require("../../common/providers/provider.registry.impl");
const provider_instances_1 = require("./provider.instances");
/**
 * Keeps the in-memory ProviderRegistryImpl in sync with the persisted
 * `providers` table. The table is the single source of truth for which
 * provider serves each vertical and in which order (admin workstream ADM-B1).
 */
let RegistrySyncService = class RegistrySyncService {
    static { RegistrySyncService_1 = this; }
    providers;
    registry;
    instances;
    logger = new common_1.Logger(RegistrySyncService_1.name);
    constructor(providers, registry, instances) {
        this.providers = providers;
        this.registry = registry;
        this.instances = instances;
    }
    /** Known adapters: key must equal the instance `providerId`. */
    static DEFAULTS = [
        { key: 'duffel-flight', name: 'Duffel Flights', vertical: 'flight', priority: 1, isFallback: false },
        { key: 'nuitee-flight', name: 'Nuitee Flights', vertical: 'flight', priority: 2, isFallback: true },
        { key: 'mock-flight', name: 'Mock Flights', vertical: 'flight', priority: 3, isFallback: true },
        { key: 'nuitee', name: 'Nuitee Hotels', vertical: 'hotel', priority: 1, isFallback: false },
        // Duffel Stays is not live on this account: the adapter falls back to a
        // curated fake catalogue, so it must stay OFF. An honest empty answer is
        // the only truthful result when Nuitee has no stay.
        { key: 'duffel-hotel', name: 'Duffel Hotels', vertical: 'hotel', priority: 2, isFallback: true, isActive: false },
        { key: 'mock-hotel', name: 'Mock Hotels', vertical: 'hotel', priority: 3, isFallback: true, isActive: false },
        { key: 'mock-car', name: 'Mock Cars', vertical: 'car', priority: 1, isFallback: false },
    ];
    /** Inserts missing default rows; never touches user-edited existing rows. */
    async seedDefaults() {
        for (const def of RegistrySyncService_1.DEFAULTS) {
            const existing = await this.providers.findOne({
                where: { providerKey: def.key },
            });
            if (existing)
                continue;
            await this.providers.save(this.providers.create({
                providerKey: def.key,
                name: def.name,
                vertical: def.vertical,
                priority: def.priority,
                isFallback: def.isFallback,
                isActive: def.isActive ?? true,
                config: {},
                healthStatus: 'unknown',
            }));
        }
    }
    /** Rebuilds registry lists from active DB rows, ordered by priority. */
    async syncFromDatabase() {
        const rows = await this.providers.find({
            where: { isActive: true },
            order: { priority: 'ASC' },
        });
        const byVertical = {
            flight: [],
            hotel: [],
            car: [],
        };
        for (const row of rows) {
            const instance = this.instances.get(row.providerKey);
            if (!instance)
                continue;
            const vertical = row.vertical ?? '';
            if (!(vertical in byVertical))
                continue;
            byVertical[vertical].push(instance);
        }
        this.registry.setFlightProviders(byVertical.flight);
        this.registry.setHotelProviders(byVertical.hotel);
        this.registry.setCarProviders(byVertical.car);
    }
    /** Seeds + rebuilds in one call; used at boot and after admin mutations. */
    async refresh() {
        await this.seedDefaults();
        await this.syncFromDatabase();
    }
    /** Fallback used when the DB is unreachable: legacy hardcoded ordering. */
    applyLegacyOrdering(legacy) {
        this.registry.setFlightProviders(legacy.flight);
        this.registry.setHotelProviders(legacy.hotel);
        this.registry.setCarProviders(legacy.car);
        this.logger.warn('Provider registry fell back to legacy hardcoded ordering (database unavailable or empty).');
    }
};
exports.RegistrySyncService = RegistrySyncService;
exports.RegistrySyncService = RegistrySyncService = RegistrySyncService_1 = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(provider_entity_1.Provider)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        provider_registry_impl_1.ProviderRegistryImpl,
        provider_instances_1.ProviderInstances])
], RegistrySyncService);
//# sourceMappingURL=registry.sync.service.js.map