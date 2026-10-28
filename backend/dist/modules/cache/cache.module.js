"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.CacheModule = void 0;
const common_1 = require("@nestjs/common");
const cache_service_1 = require("./cache.service");
const in_memory_cache_provider_1 = require("../../common/cache/in.memory.cache.provider");
const cache_provider_1 = require("../../common/cache/cache.provider");
let CacheModule = class CacheModule {
};
exports.CacheModule = CacheModule;
exports.CacheModule = CacheModule = __decorate([
    (0, common_1.Global)(),
    (0, common_1.Module)({
        providers: [
            {
                provide: cache_provider_1.CACHE_PROVIDER,
                useClass: in_memory_cache_provider_1.InMemoryCacheProvider,
            },
            cache_service_1.CacheService,
        ],
        exports: [cache_service_1.CacheService, cache_provider_1.CACHE_PROVIDER],
    })
], CacheModule);
//# sourceMappingURL=cache.module.js.map