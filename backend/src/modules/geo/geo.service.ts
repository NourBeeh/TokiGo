import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { CacheService } from '../cache/cache.service';

export interface GeoCountryResult {
  countryCode: string;
  country: string;
  source: 'ip' | 'gps' | 'both';
  ipCountry?: string;
  gpsCountry?: string;
  confidence: 'high' | 'medium' | 'low';
  ip?: string;
}

const GEO_TTL_SECONDS = 24 * 60 * 60; // a user's country rarely changes daily
const REQUEST_TIMEOUT_MS = 4_000;

/**
 * Detects the user's country from, in priority order:
 *  1. GPS coordinates (when supplied) — most accurate, needs device permission.
 *  2. IP geolocation (always available, no permission needed).
 *
 * The two results are cross-checked to build a confidence level, and every
 * lookup is cached for 24h. Failures are silent (return null) so no user flow
 * ever breaks because geolocation is down.
 *
 * Provider: ip-api.com (free, regional rate-limit ~45/min) — configurable via
 * GEO_API_URL. Uses the platform `fetch` (Node 18+), no new dependency.
 *
 * @private note: ip-api.com free tier is HTTP-only; keep it as the dev/cache
 * default and point GEO_API_URL at a paid/production endpoint when needed.
 */
@Injectable()
export class GeoService {
  private readonly logger = new Logger(GeoService.name);
  private readonly apiUrl: string;

  constructor(
    private readonly config: ConfigService,
    private readonly cache: CacheService,
  ) {
    this.apiUrl = this.config.get<string>('GEO_API_URL') ?? 'http://ip-api.com/json';
  }

  /** Primary entry: resolves the best country from whatever is available. */
  async resolve(opts: {
    ip?: string;
    latitude?: number;
    longitude?: number;
  }): Promise<GeoCountryResult | null> {
    const ipResult = opts.ip ? await this.countryFromIp(opts.ip) : null;
    const gpsResult =
      opts.latitude !== undefined && opts.longitude !== undefined
        ? await this.countryFromCoords(opts.latitude, opts.longitude)
        : null;

    if (ipResult && gpsResult) {
      const agree = ipResult.countryCode === gpsResult.countryCode;
      return {
        countryCode: gpsResult.countryCode,
        country: gpsResult.country,
        source: 'both',
        ipCountry: ipResult.countryCode,
        gpsCountry: gpsResult.countryCode,
        confidence: agree ? 'high' : 'medium',
        ip: opts.ip,
      };
    }
    if (gpsResult) {
      return { ...gpsResult, source: 'gps', confidence: 'high' };
    }
    if (ipResult) {
      return { ...ipResult, source: 'ip', confidence: 'low' };
    }
    return null;
  }

  private async countryFromIp(ip: string): Promise<Omit<GeoCountryResult, 'source' | 'confidence'> | null> {
    const key = `geo:ip:${ip}`;
    const cached = await this.cache.get<{ countryCode: string; country: string }>(key);
    if (cached) return cached;
    const result = await this.lookup(ip);
    if (result) await this.cache.set(key, result, GEO_TTL_SECONDS);
    return result;
  }

  private async countryFromCoords(
    latitude: number,
    longitude: number,
  ): Promise<Omit<GeoCountryResult, 'source' | 'confidence'> | null> {
    const key = `geo:gps:${latitude.toFixed(2)},${longitude.toFixed(2)}`;
    const cached = await this.cache.get<{ countryCode: string; country: string }>(key);
    if (cached) return cached;
    const result = await this.lookup(`${latitude},${longitude}`);
    if (result) await this.cache.set(key, result, GEO_TTL_SECONDS);
    return result;
  }

  /** One bounded HTTP call; any failure returns null (never throws). */
  private async lookup(query: string): Promise<{
    countryCode: string;
    country: string;
  } | null> {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
    try {
      const response = await fetch(
        `${this.apiUrl}/${encodeURIComponent(query)}?fields=status,country,countryCode,query`,
        { signal: controller.signal },
      );
      if (!response.ok) return null;
      const data = (await response.json()) as {
        status?: string;
        country?: string;
        countryCode?: string;
      };
      if (data?.status !== 'success' || !data.countryCode || !data.country) {
        return null;
      }
      return { countryCode: data.countryCode, country: data.country };
    } catch (error) {
      this.logger.warn(`Geo lookup failed for "${query}": ${(error as Error).message}`);
      return null;
    } finally {
      clearTimeout(timer);
    }
  }
}
