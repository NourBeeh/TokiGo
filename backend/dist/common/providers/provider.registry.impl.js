"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.ProviderRegistryImpl = void 0;
const common_1 = require("@nestjs/common");
let ProviderRegistryImpl = class ProviderRegistryImpl {
    flightProviders = [];
    hotelProviders = [];
    carProviders = [];
    registerFlight(provider) {
        this.flightProviders.push(provider);
    }
    registerHotel(provider) {
        this.hotelProviders.push(provider);
    }
    registerCar(provider) {
        this.carProviders.push(provider);
    }
    /** Atomically replace a vertical's provider list (admin runtime switching). */
    setFlightProviders(providers) {
        this.flightProviders = [...providers];
    }
    setHotelProviders(providers) {
        this.hotelProviders = [...providers];
    }
    setCarProviders(providers) {
        this.carProviders = [...providers];
    }
    getFlightProviders() {
        return this.flightProviders;
    }
    getHotelProviders() {
        return this.hotelProviders;
    }
    getCarProviders() {
        return this.carProviders;
    }
    findFlightProvider(id) {
        return this.flightProviders.find(p => p.providerId === id);
    }
    findHotelProvider(id) {
        return this.hotelProviders.find(p => p.providerId === id);
    }
    findCarProvider(id) {
        return this.carProviders.find(p => p.providerId === id);
    }
    /** Finds a registered provider instance by its providerId across verticals. */
    getProviderByKey(key) {
        return ([...this.flightProviders, ...this.hotelProviders, ...this.carProviders]
            .find(p => p.providerId === key) ?? null);
    }
};
exports.ProviderRegistryImpl = ProviderRegistryImpl;
exports.ProviderRegistryImpl = ProviderRegistryImpl = __decorate([
    (0, common_1.Injectable)()
], ProviderRegistryImpl);
//# sourceMappingURL=provider.registry.impl.js.map