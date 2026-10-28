import { CacheProvider } from '../../common/cache/cache.provider';

export class InMemoryCacheProvider implements CacheProvider {
  private store = new Map<string, { value: any; expireAt?: number }>();

  async get<T>(key: string): Promise<T | null> {
    const entry = this.store.get(key);
    if (!entry) return null;
    if (entry.expireAt && Date.now() > entry.expireAt) {
      this.store.delete(key);
      return null;
    }
    return entry.value as T;
  }

  async set<T>(key: string, value: T, ttlSeconds?: number): Promise<void> {
    const expireAt = ttlSeconds ? Date.now() + ttlSeconds * 1000 : undefined;
    this.store.set(key, { value, expireAt });
  }

  async delete(key: string): Promise<void> {
    this.store.delete(key);
  }

  async invalidate(pattern: string): Promise<void> {
    const regex = new RegExp(pattern.replace('*', '.*'));
    for (const key of this.store.keys()) {
      if (regex.test(key)) this.store.delete(key);
    }
  }
}
