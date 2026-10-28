import { Module, Global } from '@nestjs/common';
import { CacheService } from './cache.service';
import { InMemoryCacheProvider } from '../../common/cache/in.memory.cache.provider';
import { CACHE_PROVIDER } from '../../common/cache/cache.provider';

@Global()
@Module({
  providers: [
    {
      provide: CACHE_PROVIDER,
      useClass: InMemoryCacheProvider,
    },
    CacheService,
  ],
  exports: [CacheService, CACHE_PROVIDER],
})
export class CacheModule {}
