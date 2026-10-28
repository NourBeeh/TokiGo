/**
 * DI token for the bound cache implementation.
 *
 * [CacheProvider] is an interface, so it exists only at compile time: using it
 * directly as a NestJS token emitted a reference to an erased import and the
 * application crashed on boot with `ReferenceError: cache_provider_1 is not
 * defined`. A `Symbol` survives compilation and mirrors the token convention
 * already used by `AI_PROVIDER` in `src/modules/ai/ai.provider.ts`.
 */
export const CACHE_PROVIDER = Symbol('CACHE_PROVIDER');

export interface CacheProvider {
  get<T>(key: string): Promise<T | null>;
  set<T>(key: string, value: T, ttlSeconds?: number): Promise<void>;
  delete(key: string): Promise<void>;
  invalidate(pattern: string): Promise<void>;
}
