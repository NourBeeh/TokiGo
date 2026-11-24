import { GeoService } from '../src/modules/geo/geo.service';
import { CacheService } from '../src/modules/cache/cache.service';
import {
  CITY_CATALOG,
  cityById,
  currencyForCity,
  matchCity,
  nearestCityWithin,
} from '../src/common/market/city-coordinates';
import { currencyForCountry } from '../src/common/market/currency-by-country';

class FakeCache {
  store = new Map<string, any>();
  async get<T>(key: string): Promise<T | null> {
    return (this.store.get(key) as T) ?? null;
  }
  async set<T>(key: string, value: T): Promise<void> {
    this.store.set(key, value);
  }
}

type Handler = (url: string) => Promise<any> | any;

function makeGeo(handler: Handler) {
  (global as any).fetch = jest.fn(async (url: string) => {
    const payload = await handler(url);
    if (payload === undefined) return { ok: false, status: 500 };
    return { ok: true, status: 200, json: async () => payload };
  });
  const config = { get: () => undefined } as any;
  const cache = new CacheService(new FakeCache() as any);
  return new GeoService(config, cache);
}

const ipPayload = (overrides: Record<string, any> = {}) => ({
  status: 'success',
  countryCode: 'EG',
  country: 'Egypt',
  city: 'Cairo',
  lat: 30.0444,
  lon: 31.2357,
  query: 'x',
  ...overrides,
});

const reversePayload = (address: Record<string, any>) => ({
  address: { country: 'Egypt', country_code: 'eg', ...address },
});

describe('city catalog (canonical source of truth)', () => {
  it('exposes stable ids, a country-derived currency and real coordinates', () => {
    expect(CITY_CATALOG.length).toBeGreaterThan(20);
    const cairo = cityById('cairo');
    expect(cairo).not.toBeNull();
    expect(cairo!.currency).toBe('EGP');
    expect(cairo!.countryCode).toBe('EG');
    expect(cairo!.latitude).toBeCloseTo(30.0444, 3);
    expect(cairo!.longitude).toBeCloseTo(31.2357, 3);

    for (const city of CITY_CATALOG) {
      expect(city.currency).toBe(currencyForCountry(city.countryCode));
      expect(city.latitude).toBeGreaterThanOrEqual(-90);
      expect(city.latitude).toBeLessThanOrEqual(90);
      expect(city.longitude).toBeGreaterThanOrEqual(-180);
      expect(city.longitude).toBeLessThanOrEqual(180);
    }
  });

  it('matches names and aliases, constrained by country when supplied', () => {
    expect(matchCity('London')?.id).toBe('london');
    expect(matchCity('لندن')?.id).toBe('london');
    expect(matchCity('London', 'GB')?.id).toBe('london');
    expect(matchCity('London', 'FR')).toBeNull();
    expect(currencyForCity('cairo')).toBe('EGP');
    expect(cityById('nowhere')).toBeNull();
  });

  it('snaps to the nearest supported city only within the radius', () => {
    const near = nearestCityWithin(51.5, -0.12, 50);
    expect(near?.city.id).toBe('london');
    // The middle of the Atlantic has no supported city within 50 km.
    expect(nearestCityWithin(0, 0, 50)).toBeNull();
  });
});

describe('GeoService.locate — city detection', () => {
  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('serves the catalog through GET /geo/cities', () => {
    const geo = makeGeo(() => undefined);
    const catalog = geo.catalog();
    expect(catalog.version).toBeGreaterThan(0);
    expect(catalog.cities.length).toBe(CITY_CATALOG.length);
    const london = catalog.cities.find((city) => city.id === 'london');
    expect(london).toMatchObject({
      name: 'London',
      countryCode: 'GB',
      currency: 'GBP',
    });
    // The picker is searchable by local names, not only the English one.
    expect(london!.aliases).toContain('لندن');
    const cairo = catalog.cities.find((city) => city.id === 'cairo');
    expect(cairo!.aliases).toContain('القاهرة');
  });

  it('prefers GPS + reverse geocoding and returns canonical city coords', async () => {
    const geo = makeGeo((url) =>
      url.includes('reverse')
        ? reversePayload({ city: 'London', country: 'United Kingdom', country_code: 'gb' })
        : ipPayload(),
    );
    const result = await geo.locate({ latitude: 51.51, longitude: -0.1 });
    expect(result).toMatchObject({
      found: true,
      cityId: 'london',
      city: 'London',
      countryCode: 'GB',
      currency: 'GBP',
      source: 'gps',
      confidence: 'high',
      latitude: 51.5072,
      longitude: -0.1276,
    });
  });

  it('falls back to IP when GPS resolves no supported city', async () => {
    const geo = makeGeo((url) =>
      url.includes('reverse')
        ? reversePayload({ city: 'Atlantis', country: 'Nowhere', country_code: 'zz' })
        : ipPayload(),
    );
    const result = await geo.locate({
      ip: '41.32.0.1',
      latitude: 0,
      longitude: 0,
    });
    expect(result).toMatchObject({
      found: true,
      cityId: 'cairo',
      source: 'ip',
      confidence: 'low',
      currency: 'EGP',
    });
  });

  it('uses IP city detection when no GPS is available', async () => {
    const geo = makeGeo(() => ipPayload());
    const result = await geo.locate({ ip: '41.32.0.1' });
    expect(result).toMatchObject({
      found: true,
      cityId: 'cairo',
      source: 'ip',
      currency: 'EGP',
    });
  });

  it('reports a country without inventing a city', async () => {
    const geo = makeGeo(() =>
      ipPayload({ city: 'Unsupported Town', lat: 0, lon: 0 }),
    );
    const result = await geo.locate({ ip: '41.32.0.1' });
    expect(result).toMatchObject({
      found: true,
      cityId: null,
      city: null,
      countryCode: 'EG',
      currency: 'EGP',
      source: 'ip',
    });
  });

  it('keeps a GPS country when no IP fallback exists', async () => {
    const geo = makeGeo((url) =>
      url.includes('reverse')
        ? reversePayload({ country: 'Egypt', country_code: 'eg' })
        : undefined,
    );
    const result = await geo.locate({ latitude: 0, longitude: 0 });
    expect(result).toMatchObject({
      found: true,
      cityId: null,
      countryCode: 'EG',
      source: 'gps',
      confidence: 'medium',
    });
  });

  it('answers found:false when every provider fails (never throws)', async () => {
    (global as any).fetch = jest.fn(async () => {
      throw new Error('network down');
    });
    const config = { get: () => undefined } as any;
    const geo = new GeoService(config, new CacheService(new FakeCache() as any));
    await expect(
      geo.locate({ ip: '1.2.3.4', latitude: 0, longitude: 0 }),
    ).resolves.toMatchObject({ found: false, cityId: null });
  });

  it('caches reverse lookups for repeated identical fixes', async () => {
    const fetchMock = jest.fn(async (url: string) => ({
      ok: true,
      json: async () =>
        url.includes('reverse')
          ? reversePayload({ city: 'London', country: 'United Kingdom', country_code: 'gb' })
          : ipPayload(),
    }));
    (global as any).fetch = fetchMock;
    const config = { get: () => undefined } as any;
    const geo = new GeoService(config, new CacheService(new FakeCache() as any));

    await geo.locate({ latitude: 51.51, longitude: -0.1 });
    await geo.locate({ latitude: 51.51, longitude: -0.1 });
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });
});
