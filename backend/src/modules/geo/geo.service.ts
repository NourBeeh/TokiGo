import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { CacheService } from '../cache/cache.service';
import { currencyForCountry } from '../../common/market/currency-by-country';
import {
  CITY_CATALOG_VERSION,
  CityRecord,
  cityCatalogWire,
  matchCity,
  nearestCityWithin,
} from '../../common/market/city-coordinates';

export interface GeoCountryResult {
  countryCode: string;
  country: string;
  source: 'ip' | 'gps' | 'both';
  ipCountry?: string;
  gpsCountry?: string;
  confidence: 'high' | 'medium' | 'low';
  ip?: string;
}

/** Where a city-level result came from. Never exposed as a customer control. */
export type GeoCitySource = 'gps' | 'ip';

export interface GeoLocateResult {
  found: boolean;
  cityId: string | null;
  city: string | null;
  countryCode: string | null;
  country: string | null;
  currency: string | null;
  /** Canonical city-centre coordinates; null when only a country resolved. */
  latitude: number | null;
  longitude: number | null;
  source: GeoCitySource | null;
  confidence: 'high' | 'medium' | 'low' | null;
}

interface IpInfo {
  countryCode: string;
  country: string;
  city?: string;
  latitude?: number;
  longitude?: number;
}

interface ReverseInfo {
  city?: string;
  countryCode?: string;
  country?: string;
}

const GEO_TTL_SECONDS = 24 * 60 * 60; // a user's city rarely changes daily
const REQUEST_TIMEOUT_MS = 4_000;
const REVERSE_TIMEOUT_MS = 3_500;
/** A precise GPS fix may be snapped to a supported city within this radius. */
const GPS_SNAP_KM = 50;
/** IP coordinates are city-level, so the same generous snap applies. */
const IP_SNAP_KM = 50;

const EMPTY_RESULT: GeoLocateResult = {
  found: false,
  cityId: null,
  city: null,
  countryCode: null,
  country: null,
  currency: null,
  latitude: null,
  longitude: null,
  source: null,
  confidence: null,
};

/**
 * Detects the user's city/country from, in priority order:
 *  1. GPS coordinates + reverse geocoding (needs device permission).
 *  2. IP geolocation (no permission needed).
 *  3. Nothing — an honest `found:false`.
 *
 * Every lookup is cached for 24h and every failure is silent, so no customer
 * flow ever breaks because a geolocation provider is down. The client is
 * responsible for keeping its last valid city when this returns no city.
 *
 * Providers:
 *  - IP:      ip-api.com (configurable via `GEO_API_URL`)
 *  - Reverse: Nominatim (configurable via `GEO_REVERSE_URL`)
 * Both use the platform `fetch` (Node 18+), no new dependency.
 */
@Injectable()
export class GeoService {
  private readonly logger = new Logger(GeoService.name);
  private readonly apiUrl: string;
  private readonly reverseUrl: string;

  constructor(
    private readonly config: ConfigService,
    private readonly cache: CacheService,
  ) {
    this.apiUrl = this.config.get<string>('GEO_API_URL') ?? 'http://ip-api.com/json';
    this.reverseUrl =
      this.config.get<string>('GEO_REVERSE_URL') ??
      'https://nominatim.openstreetmap.org/reverse';
  }

  /** The selectable city catalog (`GET /geo/cities`). */
  catalog(): { version: number; cities: ReturnType<typeof cityCatalogWire> } {
    return { version: CITY_CATALOG_VERSION, cities: cityCatalogWire() };
  }

  /** Primary country entry (kept for `GET /geo/country` compatibility). */
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

  /**
   * City-level detection (`GET /geo/locate`).
   *
   * GPS is preferred; when it cannot resolve a supported city the IP lookup is
   * attempted before giving up. A result with `cityId: null` means "country
   * known, city unknown" — the client keeps its last valid city.
   */
  async locate(opts: {
    ip?: string;
    latitude?: number;
    longitude?: number;
  }): Promise<GeoLocateResult> {
    let gpsCountry: string | null = null;
    let gpsCountryName: string | null = null;
    let gpsCity: CityRecord | null = null;
    let gpsConfidence: 'high' | 'medium' = 'high';

    if (this.isValidCoordinate(opts.latitude, opts.longitude)) {
      const reverse = await this.reverseGeocode(opts.latitude!, opts.longitude!);
      if (reverse?.countryCode) {
        gpsCountry = reverse.countryCode;
        gpsCountryName = reverse.country ?? null;
      }
      if (reverse?.city) {
        gpsCity = matchCity(reverse.city, reverse.countryCode ?? gpsCountry);
      }
      if (!gpsCity) {
        // A GPS fix in a suburb still belongs to its nearest supported city.
        const nearest = nearestCityWithin(opts.latitude!, opts.longitude!, GPS_SNAP_KM);
        if (nearest) {
          gpsCity = nearest.city;
          gpsConfidence = 'medium';
          gpsCountry = gpsCountry ?? nearest.city.countryCode;
        }
      }
      if (!gpsCountry && gpsCity) gpsCountry = gpsCity.countryCode;
    }

    if (gpsCity) {
      return this.cityResult(gpsCity, 'gps', gpsConfidence, gpsCountryName);
    }

    // GPS produced no supported city (denied, unavailable, timeout, invalid
    // coordinates or an unsupported place) → IP fallback for the city.
    if (opts.ip) {
      const ipInfo = await this.ipInfo(opts.ip);
      if (ipInfo) {
        let city = ipInfo.city
          ? matchCity(ipInfo.city, ipInfo.countryCode)
          : null;
        if (
          !city &&
          this.isValidCoordinate(ipInfo.latitude, ipInfo.longitude)
        ) {
          const nearest = nearestCityWithin(
            ipInfo.latitude!,
            ipInfo.longitude!,
            IP_SNAP_KM,
          );
          if (nearest) city = nearest.city;
        }
        if (city) {
          return this.cityResult(city, 'ip', 'low', ipInfo.country);
        }
        // IP knows the country but not a supported city: report the country
        // only. The client keeps its last valid city.
        return {
          ...EMPTY_RESULT,
          found: true,
          countryCode: ipInfo.countryCode,
          country: ipInfo.country,
          currency: currencyForCountry(ipInfo.countryCode),
          source: 'ip',
          confidence: 'low',
        };
      }
    }

    if (gpsCountry) {
      return {
        ...EMPTY_RESULT,
        found: true,
        countryCode: gpsCountry,
        country: gpsCountryName,
        currency: currencyForCountry(gpsCountry),
        source: 'gps',
        confidence: 'medium',
      };
    }

    return { ...EMPTY_RESULT };
  }

  private cityResult(
    city: CityRecord,
    source: GeoCitySource,
    confidence: 'high' | 'medium' | 'low',
    countryName: string | null,
  ): GeoLocateResult {
    return {
      found: true,
      cityId: city.id,
      city: city.name,
      countryCode: city.countryCode,
      country: countryName,
      currency: city.currency,
      latitude: city.latitude,
      longitude: city.longitude,
      source,
      confidence,
    };
  }

  private isValidCoordinate(
    latitude?: number,
    longitude?: number,
  ): boolean {
    return (
      typeof latitude === 'number' &&
      typeof longitude === 'number' &&
      Number.isFinite(latitude) &&
      Number.isFinite(longitude) &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180
    );
  }

  private async countryFromIp(
    ip: string,
  ): Promise<{ countryCode: string; country: string } | null> {
    const info = await this.ipInfo(ip);
    if (!info) return null;
    return { countryCode: info.countryCode, country: info.country };
  }

  private async countryFromCoords(
    latitude: number,
    longitude: number,
  ): Promise<{ countryCode: string; country: string } | null> {
    const reverse = await this.reverseGeocode(latitude, longitude);
    if (reverse?.countryCode) {
      return {
        countryCode: reverse.countryCode,
        country: reverse.country ?? reverse.countryCode,
      };
    }
    const nearest = nearestCityWithin(latitude, longitude, GPS_SNAP_KM);
    if (nearest) {
      return {
        countryCode: nearest.city.countryCode,
        country: nearest.city.countryCode,
      };
    }
    return null;
  }

  private async ipInfo(ip: string): Promise<IpInfo | null> {
    const key = `geo:ip:${ip}`;
    const cached = await this.cache.get<IpInfo>(key);
    if (cached) return cached;
    const result = await this.lookupIp(ip);
    if (result) await this.cache.set(key, result, GEO_TTL_SECONDS);
    return result;
  }

  /** One bounded IP call; any failure returns null (never throws). */
  private async lookupIp(ip: string): Promise<IpInfo | null> {
    const url =
      `${this.apiUrl}/${encodeURIComponent(ip)}` +
      '?fields=status,country,countryCode,city,lat,lon,query';
    const data = await this.requestJson(url, REQUEST_TIMEOUT_MS);
    if (!data || data.status !== 'success' || !data.countryCode || !data.country) {
      return null;
    }
    const latitude = Number(data.lat);
    const longitude = Number(data.lon);
    return {
      countryCode: String(data.countryCode).toUpperCase(),
      country: String(data.country),
      city: typeof data.city === 'string' ? data.city : undefined,
      latitude: Number.isFinite(latitude) ? latitude : undefined,
      longitude: Number.isFinite(longitude) ? longitude : undefined,
    };
  }

  private async reverseGeocode(
    latitude: number,
    longitude: number,
  ): Promise<ReverseInfo | null> {
    const key = `geo:rev:${latitude.toFixed(2)},${longitude.toFixed(2)}`;
    const cached = await this.cache.get<ReverseInfo>(key);
    if (cached) return cached;

    const url =
      `${this.reverseUrl}?format=jsonv2&zoom=10&addressdetails=1` +
      `&accept-language=en&lat=${latitude}&lon=${longitude}`;
    const data = await this.requestJson(url, REVERSE_TIMEOUT_MS, {
      // Nominatim's usage policy requires an identifying User-Agent.
      'User-Agent': 'TokiGo/1.0 (+https://tokigo.app)',
      Accept: 'application/json',
    });
    if (!data || data.error) return null;

    const address = data.address ?? {};
    const city =
      this.firstString(
        address.city,
        address.town,
        address.village,
        address.municipality,
        address.city_district,
        address.county,
      ) ?? undefined;
    const countryCode =
      typeof address.country_code === 'string'
        ? address.country_code.toUpperCase()
        : undefined;
    const country =
      typeof address.country === 'string' ? address.country : undefined;

    if (!city && !countryCode) return null;
    const result: ReverseInfo = { city, countryCode, country };
    await this.cache.set(key, result, GEO_TTL_SECONDS);
    return result;
  }

  private firstString(...values: unknown[]): string | null {
    for (const value of values) {
      if (typeof value === 'string' && value.trim()) return value.trim();
    }
    return null;
  }

  /**
   * One bounded HTTP call returning decoded JSON, or null. Protected so tests
   * can substitute a deterministic transport without touching the network.
   */
  protected async requestJson(
    url: string,
    timeoutMs: number,
    headers?: Record<string, string>,
  ): Promise<any | null> {
    try {
      const response = await fetch(url, {
        signal: AbortSignal.timeout(timeoutMs),
        headers,
      });
      if (!response.ok) return null;
      return await response.json();
    } catch (error) {
      this.logger.warn(`Geo lookup failed for "${url}": ${(error as Error).message}`);
      return null;
    }
  }
}
