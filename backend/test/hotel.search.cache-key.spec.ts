import { ProviderRegistryImpl } from '../src/common/providers/provider.registry.impl';
import { SearchService } from '../src/modules/providers/search.service';
import { PricingService } from '../src/common/market/pricing.service';
import { FxService } from '../src/common/market/fx.service';
import { CacheService } from '../src/modules/cache/cache.service';
import {
  HOTEL_SEARCH_CACHE_TTL_SECONDS,
  hotelSearchCacheKey,
  normalizeHotelSearchForCacheKey,
} from '../src/modules/providers/hotel-search-key';

/**
 * Live hotel-search cache identity + stampede protection (high-load Phase 1).
 *
 * The cache is a 45-second presentation accelerator only: it must key on every
 * price-affecting parameter (occupancy, dates, currency, nationality), never
 * cache a partial/failed provider response, and must not be the booking price
 * authority (enforced by the revalidate-before-charge flow elsewhere).
 */

const base = {
  city: 'Cairo',
  checkIn: '2026-11-10',
  checkOut: '2026-11-13',
  guests: 2,
  rooms: 1,
};

function nullCache(): CacheService {
  return new CacheService({
    get: async () => null,
    set: async () => undefined,
    delete: async () => undefined,
    invalidate: async () => undefined,
  } as any);
}

function recordingCache(): {
  cache: CacheService;
  sets: Array<{ key: string; ttl?: number }>;
} {
  const sets: Array<{ key: string; ttl?: number }> = [];
  const cache = new CacheService({
    get: async () => null,
    set: async (k: string, _v: any, ttl?: number) => {
      sets.push({ key: k, ttl });
    },
    delete: async () => undefined,
    invalidate: async () => undefined,
  } as any);
  return { cache, sets };
}

function makePricing(): PricingService {
  return new PricingService(new FxService(nullCache()));
}

function makeService(cache: CacheService, providerTimeoutMs = 20) {
  const registry = new ProviderRegistryImpl();
  const service = new SearchService(registry, cache, makePricing());
  service.providerTimeoutMs = providerTimeoutMs;
  return { service, registry };
}

describe('hotel search cache key', () => {
  it('uses the mandated hotels:{city}:{checkin} base format', () => {
    const key = hotelSearchCacheKey(base, 'EG', 'USD');
    expect(key).toMatch(/^hotels:cairo:2026-11-10:[0-9a-f]{64}$/);
  });

  it('is exactly 45 seconds — no more, no less', () => {
    expect(HOTEL_SEARCH_CACHE_TTL_SECONDS).toBe(45);
  });

  it('normalizes city casing/whitespace and date-time spellings', () => {
    const a = hotelSearchCacheKey(base, 'EG', 'USD');
    const b = hotelSearchCacheKey(
      {
        ...base,
        city: '  cAIro ',
        checkIn: '2026-11-10T00:00:00.000Z',
        checkOut: '2026-11-13T23:00:00.000Z',
      },
      'EG',
      'USD',
    );
    expect(a).toBe(b);
  });

  it('treats rooms:null as rooms:1 and guests omitted as 2 (provider defaults)', () => {
    const explicit = hotelSearchCacheKey(base, 'EG', 'USD');
    const sparse = hotelSearchCacheKey(
      { city: 'Cairo', checkIn: '2026-11-10', checkOut: '2026-11-13', rooms: null },
      'EG',
      'USD',
    );
    expect(sparse).toBe(explicit);
  });

  it('produces DIFFERENT keys for different occupancy / children ages', () => {
    const oneAdult = hotelSearchCacheKey(base, 'EG', 'USD');
    const family = hotelSearchCacheKey(
      {
        ...base,
        occupancies: [
          { adults: 2, children: [5, 9] },
          { adults: 1 },
        ],
      },
      'EG',
      'USD',
    );
    expect(family).not.toBe(oneAdult);

    // Children ages are a set for pricing purposes: order does not matter.
    const reordered = hotelSearchCacheKey(
      {
        ...base,
        occupancies: [
          { adults: 2, children: [9, 5] },
          { adults: 1 },
        ],
      },
      'EG',
      'USD',
    );
    expect(reordered).toBe(family);
  });

  it('keys on display currency, market and guest nationality', () => {
    const usd = hotelSearchCacheKey(base, 'EG', 'USD');
    expect(hotelSearchCacheKey(base, 'EG', 'EGP')).not.toBe(usd);
    expect(hotelSearchCacheKey(base, 'AE', 'USD')).not.toBe(usd);
    expect(
      hotelSearchCacheKey({ ...base, nationality: 'AE' }, 'EG', 'USD'),
    ).not.toBe(usd);
  });

  it('keys on checkout date and stay length', () => {
    const a = hotelSearchCacheKey(base, 'EG', 'USD');
    expect(hotelSearchCacheKey({ ...base, checkOut: '2026-11-20' }, 'EG', 'USD')).not.toBe(a);
  });

  it('canonical form exposes normalized adults/children for assertions', () => {
    const canonical = normalizeHotelSearchForCacheKey(
      { ...base, occupancies: [{ adults: 2, children: [3] }] },
      'EG',
      'USD',
    );
    expect(canonical.adults).toBe(2);
    expect(canonical.children).toEqual([3]);
    expect(canonical.rooms).toBe(1);
    expect(canonical.nationality).toBe('EG');
  });
});

describe('SearchService hotel cache behaviour', () => {
  afterEach(() => jest.restoreAllMocks());

  it('caches a successful hotel search under the hotels: key with a 45s TTL', async () => {
    const { cache, sets } = recordingCache();
    const { service, registry } = makeService(cache);
    registry.registerHotel({
      providerId: 'p',
      searchHotels: async () => ({ success: true, providerId: 'p', data: [] }),
    } as any);

    await service.searchHotels(base, 'EG', 'USD');
    expect(sets).toHaveLength(1);
    expect(sets[0].key).toMatch(/^hotels:cairo:2026-11-10:/);
    expect(sets[0].ttl).toBe(45);
  });

  it('cache hit short-circuits the providers', async () => {
    const cached = {
      successes: [{ providerId: 'cached', data: [] }],
      failures: [],
      duplicatesDropped: 0,
    };
    const cache = new CacheService({
      get: async () => cached,
      set: async () => undefined,
      delete: async () => undefined,
      invalidate: async () => undefined,
    } as any);
    const { service, registry } = makeService(cache);
    let calls = 0;
    registry.registerHotel({
      providerId: 'live',
      searchHotels: async () => {
        calls += 1;
        return { success: true, providerId: 'live', data: [] };
      },
    } as any);

    const res: any = await service.searchHotels(base, 'EG', 'USD');
    expect(res.successes[0].providerId).toBe('cached');
    expect(calls).toBe(0);
  });

  it('does NOT cache a partial-failure hotel response', async () => {
    const { cache, sets } = recordingCache();
    const { service, registry } = makeService(cache);
    registry.registerHotel({
      providerId: 'ok',
      searchHotels: async () => ({ success: true, providerId: 'ok', data: [] }),
    } as any);
    registry.registerHotel({
      providerId: 'bad',
      searchHotels: async () => ({ success: false, providerId: 'bad', error: 'x' }),
    } as any);

    await service.searchHotels(base, 'EG', 'USD');
    expect(sets).toHaveLength(0);
  });

  it('falls back to the provider when the cache layer throws (Redis outage)', async () => {
    const cache = new CacheService({
      get: async () => {
        throw new Error('redis down');
      },
      set: async () => {
        throw new Error('redis down');
      },
      delete: async () => undefined,
      invalidate: async () => undefined,
    } as any);
    const { service, registry } = makeService(cache);
    let calls = 0;
    registry.registerHotel({
      providerId: 'live',
      searchHotels: async () => {
        calls += 1;
        return { success: true, providerId: 'live', data: [] };
      },
    } as any);

    const res: any = await service.searchHotels(base, 'EG', 'USD');
    expect(res.successes[0].providerId).toBe('live');
    expect(calls).toBe(1);
  });

  it('single-flight: identical concurrent searches run the provider once', async () => {
    const { cache } = recordingCache();
    const { service, registry } = makeService(cache, 1000);
    let calls = 0;
    registry.registerHotel({
      providerId: 'slow',
      searchHotels: async () => {
        calls += 1;
        await new Promise((r) => setTimeout(r, 80));
        return { success: true, providerId: 'slow', data: [] };
      },
    } as any);

    const [a, b, c] = await Promise.all([
      service.searchHotels(base, 'EG', 'USD'),
      service.searchHotels({ ...base, city: '  cAIro ' }, 'EG', 'USD'),
      service.searchHotels(base, 'EG', 'USD'),
    ]);
    expect(calls).toBe(1);
    expect(a.successes).toHaveLength(1);
    expect(b.successes).toHaveLength(1);
    expect(c.successes).toHaveLength(1);
  });

  it('different occupancy produces a distinct cache entry (provider runs again)', async () => {
    const { cache } = recordingCache();
    const { service, registry } = makeService(cache, 1000);
    let calls = 0;
    registry.registerHotel({
      providerId: 'p',
      searchHotels: async () => {
        calls += 1;
        return { success: true, providerId: 'p', data: [] };
      },
    } as any);

    await service.searchHotels(base, 'EG', 'USD');
    await service.searchHotels({ ...base, guests: 4 }, 'EG', 'USD');
    expect(calls).toBe(2);
  });
});
