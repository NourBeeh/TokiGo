import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Hotel } from '../../database/entities/hotel.entity';
import { NuiteeModule } from '../nuitee/nuitee.module';
import { DiscoveryModule } from '../discovery/discovery.module';
import { CacheModule } from '../cache/cache.module';
import { NearbyHotelRepository } from './nearby-hotel.repository';
import { PromotionalPriceService } from './promotional-price.service';
import { NearbyStaysService } from './nearby-stays.service';
import { NearbyStaysController } from './nearby-stays.controller';

/**
 * Nearby Stays (R1–R4).
 *
 * PostgreSQL is the geographic source of truth (pure-SQL haversine, no PostGIS
 * dependency); Nuitee's `/hotels/min-rates` supplies the promotional one-night
 * minimum; the existing CacheService + CacheLockService provide the short-TTL
 * cache and single-flight. No new infrastructure is introduced.
 */
@Module({
  imports: [TypeOrmModule.forFeature([Hotel]), NuiteeModule, DiscoveryModule, CacheModule],
  controllers: [NearbyStaysController],
  providers: [NearbyHotelRepository, PromotionalPriceService, NearbyStaysService],
  exports: [NearbyStaysService],
})
export class NearbyModule {}
