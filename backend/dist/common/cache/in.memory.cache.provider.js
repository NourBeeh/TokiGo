"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.InMemoryCacheProvider = void 0;
class InMemoryCacheProvider {
    store = new Map();
    async get(key) {
        const entry = this.store.get(key);
        if (!entry)
            return null;
        if (entry.expireAt && Date.now() > entry.expireAt) {
            this.store.delete(key);
            return null;
        }
        return entry.value;
    }
    async set(key, value, ttlSeconds) {
        const expireAt = ttlSeconds ? Date.now() + ttlSeconds * 1000 : undefined;
        this.store.set(key, { value, expireAt });
    }
    async delete(key) {
        this.store.delete(key);
    }
    async invalidate(pattern) {
        const regex = new RegExp(pattern.replace('*', '.*'));
        for (const key of this.store.keys()) {
            if (regex.test(key))
                this.store.delete(key);
        }
    }
}
exports.InMemoryCacheProvider = InMemoryCacheProvider;
//# sourceMappingURL=in.memory.cache.provider.js.map