import { Injectable, Logger } from '@nestjs/common';
import { createHash } from 'crypto';
import { CacheService } from '../cache/cache.service';
import { CacheLockService } from '../../common/cache/cache-lock.service';
import { NearbyHotelRepository, NearbyHotelRecord } from './nearby-hotel.repository';
import { PromotionalPriceService } from './promotional-price.service';
import { rankStays, rankingConfigFromEnv } from './nearby-ranking.service';
import {
  NEARBY_RANKING_VERSION,
  NearbyLocationConfidence,
  NearbyLocationSource,
  NearbyStaysResponse,
  PromotionalStay,
} from './promotional-stay.model';
import {
  centerKey,
  GeoPoint,
  haversineKm,
  initialRadiusKm,
  isValidCoordinate,
  radiusStagesKm,
  sevenOneNightWindows,
} from './geo';
import { cityById, matchCity, nearestCity } from '../../common/market/city-coordinates';
import { MARKET_CONFIGS } from '../../common/market/market-context';
import { HotelDiscoveryService } from '../discovery/hotel-discovery.service';

const DEFAULT_LIMIT = 12;
const MAX_LIMIT = 24;
const DEFAULT_ADULTS = 2;
const DEFAULT_ROOMS = 1;
const DEFAULT_NATIONALITY = 'EG';
const DEFAULT_CURRENCY = 'USD';
const PROVIDER_ID = 'nuitee';
const PROVIDER_NAME = 'Nuitee Connect';
const MAX_CANDIDATE_POOL = 120;
const INVENTORY_SYNC_TTL_SECONDS = 24 * 60 * 60;

function intFromEnv(name: string, fallback: number, min: number, max: number): number {
  const value = Number(process.env[name]);
  if (!Number.isFinite(value)) return fallback;
  return Math.min(Math.max(Math.floor(value), min), max);
}

function normalizeCode(value: string | undefined, fallback: string): string {
  const code = value?.trim().toUpperCase();
  return /^[A-Z]{2}$/.test(code ?? '') ? code! : fallback;
}

function normalizeCurrency(value: string | undefined): string {
  const code = value?.trim().toUpperCase();
  return /^[A-Z]{3}$/.test(code ?? '') ? code! : DEFAULT_CURRENCY;
}

function timezoneForCountry(countryCode: string | undefined): string {
  return MARKET_CONFIGS[countryCode?.toUpperCase() ?? '']?.timezone ?? 'UTC';
}

interface ResolvedCenter {
  center: GeoPoint;
  source: NearbyLocationSource;
  confidence: NearbyLocationConfidence;
  cityName?: string;
  countryCode?: string;
  timezone: string;
}

interface LocationRequired {
  locationRequired: true;
  reason: 'no_location' | 'unknown_city';
}

type LocationResolution = ResolvedCenter | LocationRequired;

/**
 * Nearby Stays orchestration (R1/R4).
 *
 * Genuine geographic discovery: the search center is a real GPS fix or a
 * city the user explicitly selected. There is NO country-wide fallback —
 * without a center the endpoint says so. Radius expansion walks the
 * configured stages, deduplicates by hotel id, and only then prices the
 * shortlisted hotels' promotional one-night minimum.
 */
@Injectable()
export class NearbyStaysService {
  private readonly logger = new Logger(NearbyStaysService.name);
  private readonly locks = new CacheLockService();

  constructor(
    private readonly hotels: NearbyHotelRepository,
    private readonly prices: PromotionalPriceService,
    private readonly discovery: HotelDiscoveryService,
    private readonly cache: CacheService,
  ) {}

  async getNearbyStays(input: {
    latitude?: number;
    longitude?: number;
    accuracy?: number;
    city?: string;
    /** Canonical city id; an explicit selection that outranks GPS. */
    cityId?: string;
    country?: string;
    language?: string;
    currency?: string;
    nationality?: string;
    adults?: number;
    rooms?: number;
    limit?: number;
    timezone?: string;
    fromDate?: string;
  }): Promise<NearbyStaysResponse> {
    const limit = Math.min(Math.max(Math.floor(input.limit ?? DEFAULT_LIMIT) || DEFAULT_LIMIT, 1), MAX_LIMIT);
    const currency = normalizeCurrency(input.currency);
    const nationality = normalizeCode(input.nationality, DEFAULT_NATIONALITY);
    const adults = Math.min(Math.max(Math.floor(input.adults ?? DEFAULT_ADULTS) || DEFAULT_ADULTS, 1), 8);
    const rooms = Math.min(Math.max(Math.floor(input.rooms ?? DEFAULT_ROOMS) || DEFAULT_ROOMS, 1), 4);
    const language = input.language === 'ar' ? 'ar' : 'en';
    const fetchedAt = new Date().toISOString();

    const resolution = this.resolveCenter(input);
    if ('locationRequired' in resolution) {
      return {
        stays: [],
        radiusKm: initialRadiusKm(),
        locationConfidence: null,
        locationSource: null,
        locationRequired: true,
        reason: resolution.reason,
        searchedFromDate: null,
        searchedToDate: null,
        currency,
        occupancy: adults,
        nationality,
        provider: PROVIDER_ID,
        rankingVersion: NEARBY_RANKING_VERSION,
        partialFailure: false,
        fetchedAt,
      };
    }

    const timezone = input.timezone?.trim() || resolution.timezone;
    const fromDate = input.fromDate ? input.fromDate.slice(0, 10) : new Date();
    const windows = sevenOneNightWindows(fromDate, timezone);

    const cacheKey = this.cacheKey({
      center: resolution.center,
      fromDate: windows[0].checkIn,
      toDate: windows[windows.length - 1].checkOut,
      currency,
      nationality,
      adults,
      rooms,
      language,
      limit,
      // Confidence is derived from the fix's accuracy, so a coarse fix must
      // not be served a cached "high" verdict (and vice versa).
      accuracyBucket: Math.round((input.accuracy ?? 0) / 100),
    });

    const cached = await this.readCache(cacheKey);
    if (cached) return cached;

    const args = {
      resolution,
      windows,
      currency,
      nationality,
      adults,
      rooms,
      limit,
      fetchedAt,
    };

    return this.locks.singleFlight(cacheKey, async () => {
      const locked = await this.locks.withLock(`lock:nearby:${cacheKey}`, 30_000, async () => {
        const value = await this.compute(args);
        if (value.stays.length > 0 && !value.partialFailure) {
          await this.writeCache(cacheKey, value);
        }
        return value;
      });
      if (locked.acquired) return locked.value;

      // Another process owns the fetch: wait briefly for its cache entry
      // instead of starting a duplicate provider burst.
      const waited = await this.waitForCache(cacheKey, 2_000);
      return waited ?? (await this.compute(args));
    });
  }

  /** Polls the cache until [timeoutMs] for another process to publish [key]. */
  private async waitForCache(key: string, timeoutMs: number): Promise<NearbyStaysResponse | null> {
    const deadline = Date.now() + timeoutMs;
    while (Date.now() < deadline) {
      await new Promise((resolve) => setTimeout(resolve, 50));
      const value = await this.readCache(key);
      if (value) return value;
    }
    return null;
  }

  private async compute(input: {
    resolution: ResolvedCenter;
    windows: ReturnType<typeof sevenOneNightWindows>;
    currency: string;
    nationality: string;
    adults: number;
    rooms: number;
    limit: number;
    fetchedAt: string;
  }): Promise<NearbyStaysResponse> {
    const { resolution, windows, currency, nationality, adults, rooms, limit, fetchedAt } = input;
    const stages = radiusStagesKm();
    const target = limit;
    const maxPool = Math.min(Math.max(limit * 4, 40), MAX_CANDIDATE_POOL);

    let candidates = await this.expand(stages, resolution.center, target, maxPool);
    if (candidates.length === 0 && resolution.cityName && resolution.countryCode) {
      // The catalog has no geotagged inventory for the selected area yet.
      // Sync that ONE city from the provider (guarded by a 24h flag), then
      // retry once. No distant city is ever searched to fill the list.
      await this.ensureInventory(resolution.cityName, resolution.countryCode);
      candidates = await this.expand(stages, resolution.center, target, maxPool);
    }

    const activeRadius = candidates.length > 0
      ? this.radiusForDistance(resolution.center, candidates)
      : stages[stages.length - 1];

    if (candidates.length === 0) {
      return this.emptyResponse(resolution, stages[0], currency, adults, nationality, fetchedAt, 'no_geotagged_inventory');
    }

    const priceResult = await this.prices.discoverMinimumOneNightRates({
      hotelIds: candidates.map((hotel) => hotel.providerHotelId),
      windows,
      currency,
      nationality,
      occupancy: adults,
      rooms,
    });

    const stays: PromotionalStay[] = [];
    for (const hotel of candidates) {
      const price = priceResult.prices.get(hotel.providerHotelId);
      if (price === undefined) continue;
      const distanceKm = haversineKm(
        resolution.center.latitude,
        resolution.center.longitude,
        hotel.latitude,
        hotel.longitude,
      );
      stays.push({
        hotelId: hotel.providerHotelId,
        hotelName: hotel.name,
        city: hotel.city,
        country: hotel.countryCode,
        image: hotel.imageUrl ?? null,
        latitude: hotel.latitude,
        longitude: hotel.longitude,
        distanceKm: Math.round(distanceKm * 100) / 100,
        rating: hotel.rating,
        reviewCount: hotel.reviewCount,
        promotionalMinimumPrice: price,
        currency,
        searchedFromDate: priceResult.searchedFromDate,
        searchedToDate: priceResult.searchedToDate,
        occupancy: adults,
        nationality,
        provider: PROVIDER_ID,
        fetchedAt,
        locationConfidence: resolution.confidence,
      });
    }

    if (stays.length === 0) {
      return this.emptyResponse(
        resolution,
        activeRadius,
        currency,
        adults,
        nationality,
        fetchedAt,
        'no_valid_promotional_price',
        priceResult.partialFailure,
        windows,
      );
    }

    const ranked = rankStays(stays, rankingConfigFromEnv());
    return {
      stays: ranked.ranked.slice(0, limit),
      radiusKm: activeRadius,
      locationConfidence: resolution.confidence,
      locationSource: resolution.source,
      locationRequired: false,
      searchedFromDate: windows[0].checkIn,
      searchedToDate: windows[windows.length - 1].checkOut,
      currency,
      occupancy: adults,
      nationality,
      provider: PROVIDER_ID,
      rankingVersion: ranked.rankingVersion,
      partialFailure: priceResult.partialFailure,
      fetchedAt,
    };
  }

  /**
   * Walks the radius stages, deduplicating by hotel id. A hotel found at a
   * smaller radius is never re-added at a larger one.
   */
  private async expand(
    stages: number[],
    center: GeoPoint,
    target: number,
    maxPool: number,
  ): Promise<NearbyHotelRecord[]> {
    const seen = new Set<string>();
    const candidates: NearbyHotelRecord[] = [];
    for (const radius of stages) {
      const rows = await this.hotels.findWithinRadius(center, radius, maxPool);
      for (const row of rows) {
        if (seen.has(row.id)) continue;
        seen.add(row.id);
        candidates.push(row);
      }
      if (candidates.length >= target) break;
    }
    return candidates;
  }

  /** The largest stage whose radius covers the farthest selected hotel. */
  private radiusForDistance(center: GeoPoint, candidates: NearbyHotelRecord[]): number {
    let farthest = 0;
    for (const hotel of candidates) {
      const distance = haversineKm(center.latitude, center.longitude, hotel.latitude, hotel.longitude);
      if (distance > farthest) farthest = distance;
    }
    const stages = radiusStagesKm();
    for (const radius of stages) {
      if (farthest <= radius) return radius;
    }
    return stages[stages.length - 1];
  }

  private resolveCenter(input: {
    latitude?: number;
    longitude?: number;
    accuracy?: number;
    city?: string;
    cityId?: string;
    country?: string;
  }): LocationResolution {
    // An explicit city selection (canonical id) always wins over GPS. This is
    // how the client enforces "manual city beats background detection".
    if (input.cityId && input.cityId.trim()) {
      const selected = cityById(input.cityId);
      if (!selected) {
        return { locationRequired: true, reason: 'unknown_city' };
      }
      return {
        center: { latitude: selected.latitude, longitude: selected.longitude },
        source: 'city',
        confidence: 'medium',
        cityName: selected.name,
        countryCode: selected.countryCode,
        timezone: timezoneForCountry(selected.countryCode),
      };
    }

    if (isValidCoordinate(input.latitude, input.longitude)) {
      const nearest = nearestCity(
        input.latitude!,
        input.longitude!,
        radiusStagesKm()[radiusStagesKm().length - 1],
      );
      const accuracy = input.accuracy ?? 0;
      return {
        center: { latitude: input.latitude!, longitude: input.longitude! },
        source: 'gps',
        confidence: accuracy > 500 ? 'medium' : 'high',
        cityName: nearest?.name,
        countryCode: nearest?.countryCode,
        timezone: timezoneForCountry(nearest?.countryCode),
      };
    }

    if (input.city && input.city.trim()) {
      const selected =
        matchCity(input.city, input.country) ?? matchCity(input.city);
      if (!selected) {
        return { locationRequired: true, reason: 'unknown_city' };
      }
      return {
        center: { latitude: selected.latitude, longitude: selected.longitude },
        source: 'city',
        confidence: 'medium',
        cityName: selected.name,
        countryCode: selected.countryCode,
        timezone: timezoneForCountry(selected.countryCode),
      };
    }

    return { locationRequired: true, reason: 'no_location' };
  }

  /** Syncs ONE city's metadata when the local catalog has none (24h guard). */
  private async ensureInventory(city: string, country: string): Promise<void> {
    if (process.env.NEARBY_AUTO_SYNC === 'false') return;
    const flagKey = `nearby:inventory-synced:${city.trim().toLowerCase()}:${country.trim().toUpperCase()}`;
    try {
      if (await this.cache.get(flagKey)) return;
    } catch {
      // Cache outage must not block the sync attempt.
    }
    try {
      const result = await this.discovery.syncCity({ city, country });
      if (result.synced > 0) {
        // Fresh inventory invalidates any Nearby snapshot cached before it.
        await this.cache.invalidate('home:nearby-stays:*');
        // Only a complete walk earns the 24h guard. A partial one must be
        // retried on the next request instead of being suppressed for a day.
        if (result.complete !== false) {
          await this.cache.set(
            flagKey,
            { syncedAt: new Date().toISOString() },
            INVENTORY_SYNC_TTL_SECONDS,
          );
        }
      }
    } catch (error) {
      this.logger.warn(
        `Nearby inventory sync failed for ${city}/${country}: ${(error as Error).message}`,
      );
    }
  }

  private cacheKey(parts: {
    center: GeoPoint;
    fromDate: string;
    toDate: string;
    currency: string;
    nationality: string;
    adults: number;
    rooms: number;
    language: string;
    limit: number;
    accuracyBucket: number;
  }): string {
    const canonical = {
      center: centerKey(parts.center.latitude, parts.center.longitude),
      accuracyBucket: parts.accuracyBucket,
      fromDate: parts.fromDate,
      toDate: parts.toDate,
      currency: parts.currency,
      nationality: parts.nationality,
      adults: parts.adults,
      rooms: parts.rooms,
      language: parts.language,
      limit: parts.limit,
      rankingVersion: NEARBY_RANKING_VERSION,
      radiusStages: radiusStagesKm(),
      provider: PROVIDER_ID,
    };
    const digest = createHash('sha256').update(JSON.stringify(canonical)).digest('hex');
    return `home:nearby-stays:${NEARBY_RANKING_VERSION}:${digest}`;
  }

  private async readCache(key: string): Promise<NearbyStaysResponse | null> {
    try {
      return await this.cache.get<NearbyStaysResponse>(key);
    } catch {
      return null;
    }
  }

  private async writeCache(key: string, value: NearbyStaysResponse): Promise<void> {
    try {
      const ttl = intFromEnv('NEARBY_STAYS_CACHE_TTL_SECONDS', 300, 30, 3600);
      await this.cache.set(key, value, ttl);
    } catch (error) {
      this.logger.debug(`Nearby Stays cache write failed: ${(error as Error).message}`);
    }
  }

  private emptyResponse(
    resolution: ResolvedCenter,
    radiusKm: number,
    currency: string,
    occupancy: number,
    nationality: string,
    fetchedAt: string,
    reason: 'no_geotagged_inventory' | 'no_valid_promotional_price',
    partialFailure = false,
    windows: ReturnType<typeof sevenOneNightWindows> = [],
  ): NearbyStaysResponse {
    return {
      stays: [],
      radiusKm,
      locationConfidence: resolution.confidence,
      locationSource: resolution.source,
      locationRequired: false,
      reason,
      searchedFromDate: windows[0]?.checkIn ?? null,
      searchedToDate: windows[windows.length - 1]?.checkOut ?? null,
      currency,
      occupancy,
      nationality,
      provider: PROVIDER_ID,
      rankingVersion: NEARBY_RANKING_VERSION,
      partialFailure,
      fetchedAt,
    };
  }
}

export { PROVIDER_NAME };
