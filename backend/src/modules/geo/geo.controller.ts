import { Controller, Get, Header, Query, Req } from '@nestjs/common';
import { Request } from 'express';
import { GeoService } from './geo.service';

@Controller('geo')
export class GeoController {
  constructor(private readonly geoService: GeoService) {}

  /**
   * The canonical city catalog used by the customer-facing City Selection
   * picker. Public and cacheable: it changes only with a deployment.
   */
  @Get('cities')
  @Header('Cache-Control', 'public, max-age=3600')
  cities() {
    return this.geoService.catalog();
  }

  /**
   * Best-effort country detection. Kept for existing clients. New clients
   * should use `GET /geo/locate`, which also resolves the city and currency.
   */
  @Get('country')
  async country(
    @Req() req: Request,
    @Query('lat') lat?: string,
    @Query('lng') lng?: string,
  ) {
    const ip = this.trustedIp(req);
    const result = await this.geoService.resolve({
      ip,
      latitude: this.numberParam(lat),
      longitude: this.numberParam(lng),
    });
    if (!result) {
      return { found: false, countryCode: null, source: null, confidence: null };
    }
    return { found: true, ...result };
  }

  /**
   * City-level detection. Accepts optional GPS coordinates; when they are
   * absent or cannot resolve a supported city the service falls back to the
   * caller's IP. Never throws — `found:false` is the graceful answer.
   */
  @Get('locate')
  async locate(
    @Req() req: Request,
    @Query('lat') lat?: string,
    @Query('lng') lng?: string,
  ) {
    return this.geoService.locate({
      ip: this.trustedIp(req),
      latitude: this.numberParam(lat),
      longitude: this.numberParam(lng),
    });
  }

  private numberParam(value?: string): number | undefined {
    if (value === undefined || value === '') return undefined;
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : undefined;
  }

  private trustedIp(req: Request): string | undefined {
    const rawIp = this.clientIp(req);
    return rawIp && !this.isLoopback(rawIp) ? rawIp : undefined;
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
