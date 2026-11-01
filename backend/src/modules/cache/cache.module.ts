import { Module, Global } from '@nestjs/common';
import { CacheService } from './cache.service';
import { InMemoryCacheProvider } from '../../common/cache/in.memory.cache.provider';
import { RedisCacheProvider } from '../../common/cache/redis.cache.provider';
import { CACHE_PROVIDER } from '../../common/cache/cache.provider';

/**
 * One cache provider for the whole app.
 *
 * Redis is opt-in through `REDIS_URL` / `REDIS_HOST`. Without it (the local
 * default) the process uses its in-memory map, exactly as before. The Redis
 * implementation falls back to that same map on any error, so enabling Redis
 * can only make the cache shared — never less available.
 */
@Global()
@Module({
  providers: [
    {
      provide: CACHE_PROVIDER,
      useFactory: () => {
        const wantsRedis = Boolean(
          process.env.REDIS_URL?.trim() || process.env.REDIS_HOST?.trim(),
        );
        return wantsRedis
          ? new RedisCacheProvider()
          : new InMemoryCacheProvider();
      },
    },
    CacheService,
  ],
  exports: [CacheService, CACHE_PROVIDER],
})
export class CacheModule {}
