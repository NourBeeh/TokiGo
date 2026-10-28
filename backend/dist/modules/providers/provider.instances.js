"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.ProviderInstances = void 0;
const common_1 = require("@nestjs/common");
/**
 * providerKey -> provider instance map for every known adapter, active or not.
 *
 * The registry only holds ACTIVE providers (admin-managed), while health
 * checks and rebuilds must be able to reach disabled instances too — hence
 * this separate registry of everything the module constructs.
 */
let ProviderInstances = class ProviderInstances {
    map = new Map();
    register(key, instance) {
        this.map.set(key, instance);
    }
    get(key) {
        return this.map.get(key) ?? null;
    }
    keys() {
        return [...this.map.keys()];
    }
};
exports.ProviderInstances = ProviderInstances;
exports.ProviderInstances = ProviderInstances = __decorate([
    (0, common_1.Injectable)()
], ProviderInstances);
//# sourceMappingURL=provider.instances.js.map