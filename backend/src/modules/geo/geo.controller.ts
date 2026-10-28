import { Controller, Get, Query, Req } from '@nestjs/common';
import { Request } from 'express';
import { GeoService } from './geo.service';

@Controller('geo')
export class GeoController {
  constructor(private readonly geoService: GeoService) {}

  /**
   * Best-effort country detection. Accepts optional GPS coordinates as query
   * params (lat/lng from the Flutter location service with user permission)
   * and combines them with the caller IP. Never throws — returns found:false
   * when nothing could be determined so clients can degrade gracefully.
   */
  @Get('country')
  async country(
    @Req() req: Request,
    @Query('lat') lat?: string,
    @Query('lng') lng?: string,
  ) {
    const rawIp = this.clientIp(req);
    const ip = rawIp && !this.isLoopback(rawIp) ? rawIp : undefined;
    const latitude =
      lat !== undefined && lat !== '' && !Number.isNaN(Number(lat))
        ? Number(lat)
        : undefined;
    const longitude =
      lng !== undefined && lng !== '' && !Number.isNaN(Number(lng))
        ? Number(lng)
        : undefined;

    const result = await this.geoService.resolve({ ip, latitude, longitude });
    if (!result) {
      return { found: false, countryCode: null, source: null, confidence: null };
    }
    return { found: true, ...result };
  }

  private clientIp(req: Request): string | undefined {
    // Trust X-Forwarded-For only when explicitly behind a trusted proxy.
    // Otherwise an attacker can spoof their IP/country by setting the header.
    if (process.env.TRUST_PROXY === 'true') {
      const forwarded = req.headers['x-forwarded-for']?.toString();
      if (forwarded) return forwarded.split(',')[0].trim();
    }
    return req.ip ?? req.socket?.remoteAddress;
  }

  private isLoopback(ip: string): boolean {
    return ip === '::1' || ip === '127.0.0.1' || ip.startsWith('::ffff:127.');
  }
}
