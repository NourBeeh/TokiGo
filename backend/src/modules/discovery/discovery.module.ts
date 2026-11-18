import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Hotel } from '../../database/entities/hotel.entity';
import { ProvidersModule } from '../providers/providers.module';
import { HotelMetadataService } from './hotel-metadata.service';
import { MeilisearchHotelIndexService } from './meilisearch-hotel-index.service';
import { HotelDiscoveryService } from './hotel-discovery.service';
import { HotelSyncService } from './hotel-sync.service';
import { HotelSyncWorker } from './hotel-sync.worker';
import { HotelsController } from './hotels.controller';

/**
 * Hotel discovery module (high-load refactor).
 *
 * PostgreSQL (`hotels`) is the metadata source of truth; Meilisearch is an
 * optional acceleration index with a transparent fallback. BullMQ performs
 * background synchronization with bounded concurrency.
 */
@Module({
  imports: [TypeOrmModule.forFeature([Hotel]), ProvidersModule],
  controllers: [HotelsController],
  providers: [
    HotelMetadataService,
    MeilisearchHotelIndexService,
    HotelDiscoveryService,
    HotelSyncService,
    HotelSyncWorker,
  ],
  exports: [HotelMetadataService, MeilisearchHotelIndexService, HotelDiscoveryService],
})
export class DiscoveryModule {}
