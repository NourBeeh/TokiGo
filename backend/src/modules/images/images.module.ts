import { Module } from '@nestjs/common';
import { ImageProxyService } from './image-proxy.service';
import { ImagesController } from './images.controller';

/**
 * Server-side image resizing + disk cache. Global-free on purpose: only the
 * controller needs the service today, and the app reaches it over HTTP.
 */
@Module({
  controllers: [ImagesController],
  providers: [ImageProxyService],
  exports: [ImageProxyService],
})
export class ImagesModule {}
