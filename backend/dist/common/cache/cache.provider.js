"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.CACHE_PROVIDER = void 0;
/**
 * DI token for the bound cache implementation.
 *
 * [CacheProvider] is an interface, so it exists only at compile time: using it
 * directly as a NestJS token emitted a reference to an erased import and the
 * application crashed on boot with `ReferenceError: cache_provider_1 is not
 * defined`. A `Symbol` survives compilation and mirrors the token convention
 * already used by `AI_PROVIDER` in `src/modules/ai/ai.provider.ts`.
 */
exports.CACHE_PROVIDER = Symbol('CACHE_PROVIDER');
//# sourceMappingURL=cache.provider.js.map