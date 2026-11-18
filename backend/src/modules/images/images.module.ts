import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { HotelImage } from '../../database/entities/hotel-image.entity';
import { ObjectStorageService } from '../../common/storage/object-storage.service';
import { ImageProxyService } from './image-proxy.service';
import { ImageService } from './image.service';
import { ImageProcessingService } from './image-processing.service';
import { ImageProcessingWorker } from './image-processing.worker';
import { ImagesController } from './images.controller';

/**
 * Image module (high-load refactor).
 *
 * Keeps the original resize proxy (`GET /images/hotel`) untouched for contract
 * compatibility and adds the provider→WebP→S3/R2 pipeline with PostgreSQL
 * metadata + CDN URL persistence, processed by a bounded BullMQ worker.
 */
@Module({
  imports: [TypeOrmModule.forFeature([HotelImage])],
  controllers: [ImagesController],
  providers: [
    ImageProxyService,
    ObjectStorageService,
    ImageService,
    ImageProcessingService,
    ImageProcessingWorker,
  ],
  exports: [ImageService, ImageProcessingService, ObjectStorageService],
})
export class ImagesModule {}
