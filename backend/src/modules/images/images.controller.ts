import { Controller, Get, Query, Req, Res } from '@nestjs/common';
import type { Request, Response } from 'express';
import {
  ImageProxyService,
  IMAGE_CDN_CACHE_CONTROL,
} from './image-proxy.service';

/**
 * `GET /images/hotel?src=<original>&w=480&f=webp`
 *
 * Serves a resized, cached version of a hotel photo. When the source cannot be
 * proxied (host not allowed, upstream down, unsupported format) it redirects to
 * the original URL, so a client that always routes through this endpoint still
 * renders every image.
 */
@Controller('images')
export class ImagesController {
  constructor(private readonly proxy: ImageProxyService) {}

  @Get('hotel')
  async hotel(
    @Query('src') src: string | undefined,
    @Query('w') width: string | undefined,
    @Query('f') format: string | undefined,
    @Req() req: Request,
    @Res() res: Response,
  ): Promise<void> {
    if (src === undefined || src.trim() === '') {
      res.status(400).json({ error: 'src is required' });
      return;
    }

    const image = await this.proxy.proxy(
      src,
      width,
      format === 'jpeg' ? 'jpeg' : 'webp',
    );

    if (image === null) {
      // Graceful degradation: hand the client the original photo.
      if (this.proxy.isAllowed(src)) {
        res.redirect(302, src);
      } else {
        res.status(400).json({ error: 'Unsupported image source' });
      }
      return;
    }

    res.setHeader('Content-Type', image.contentType);
    res.setHeader('Cache-Control', image.cacheControl);
    // Edge-specific TTLs (Cloudflare / Fastly). Without these a CDN falls back
    // to a conservative default and revalidates on every image.
    res.setHeader('CDN-Cache-Control', IMAGE_CDN_CACHE_CONTROL);
    res.setHeader('Surrogate-Control', IMAGE_CDN_CACHE_CONTROL);
    res.setHeader('ETag', image.etag);
    res.setHeader('X-Image-Cache', image.cacheHit ? 'HIT' : 'MISS');

    if (req.headers['if-none-match'] === image.etag) {
      res.status(304).end();
      return;
    }

    res.status(200).send(image.bytes);
  }
}
