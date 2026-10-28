import { Inject, Injectable } from '@nestjs/common';
import { CACHE_PROVIDER, CacheProvider } from '../../common/cache/cache.provider';

@Injectable()
export class CacheService {
  constructor(
    @Inject(CACHE_PROVIDER) private readonly provider: CacheProvider,
  ) {}

  async get<T>(key: string): Promise<T | null> {
    return this.provider.get<T>(key);
  }

  async set<T>(key: string, value: T, ttlSeconds?: number): Promise<void> {
    return this.provider.set<T>(key, value, ttlSeconds);
  }

  async delete(key: string): Promise<void> {
    return this.provider.delete(key);
  }

  async invalidate(pattern: string): Promise<void> {
    return this.provider.invalidate(pattern);
  }
}
