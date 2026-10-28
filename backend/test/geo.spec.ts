import { GeoService } from '../src/modules/geo/geo.service';
import { CacheService } from '../src/modules/cache/cache.service';

class FakeCache {
  store = new Map<string, any>();
  async get<T>(key: string): Promise<T | null> {
    return (this.store.get(key) as T) ?? null;
  }
  async set<T>(key: string, value: T): Promise<void> {
    this.store.set(key, value);
  }
}

function makeGeo(fetchImpl: any, configValues: Record<string, any> = {}) {
  (global as any).fetch = jest.fn(fetchImpl);
  const config = { get: (k: string) => configValues[k] } as any;
  const cache = new CacheService(new FakeCache() as any);
  return new GeoService(config, cache);
}

function successPayload(countryCode: string, country: string) {
  return {
    status: 'success',
    countryCode,
    country,
    query: 'x',
  };
}

describe('GeoService — country detection', () => {
  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('resolves country from IP alone (low confidence, source ip)', async () => {
    const geo = makeGeo(() =>
      Promise.resolve({
        ok: true,
        json: () => Promise.resolve(successPayload('EG', 'Egypt')),
      }),
    );
    const result = await geo.resolve({ ip: '41.32.0.1' });
    expect(result).toMatchObject({
      countryCode: 'EG',
      country: 'Egypt',
      source: 'ip',
      confidence: 'low',
    });
  });

  it('resolves country from GPS coordinates alone (high confidence)', async () => {
    const geo = makeGeo(() =>
      Promise.resolve({
        ok: true,
        json: () => Promise.resolve(successPayload('TR', 'Turkey')),
      }),
    );
    const result = await geo.resolve({ latitude: 41.0082, longitude: 28.9784 });
    expect(result).toMatchObject({ countryCode: 'TR', source: 'gps', confidence: 'high' });
  });

  it('cross-checks IP and GPS: matching countries → high confidence / both', async () => {
    let call = 0;
    const geo = makeGeo(() => {
      call++;
      return Promise.resolve({
        ok: true,
        json: () =>
          Promise.resolve(call === 1 ? successPayload('EG', 'Egypt') : successPayload('EG', 'Egypt')),
      });
    });
    const result = await geo.resolve({ ip: '1.1.1.1', latitude: 30.0, longitude: 31.2 });
    expect(result).toMatchObject({
      countryCode: 'EG',
      source: 'both',
      ipCountry: 'EG',
      gpsCountry: 'EG',
      confidence: 'high',
    });
  });

  it('marks conflicting IP/GPS as medium confidence and trusts GPS', async () => {
    let call = 0;
    const geo = makeGeo(() => {
      call++;
      return Promise.resolve({
        ok: true,
        json: () =>
          Promise.resolve(call === 1 ? successPayload('US', 'USA') : successPayload('EG', 'Egypt')),
      });
    });
    const result = await geo.resolve({ ip: '1.1.1.1', latitude: 30.0, longitude: 31.2 });
    expect(result).toMatchObject({
      countryCode: 'EG',
      source: 'both',
      ipCountry: 'US',
      gpsCountry: 'EG',
      confidence: 'medium',
    });
  });

  it('returns null when the provider fails (never throws)', async () => {
    const geo = makeGeo(() => Promise.reject(new Error('network down')));
    await expect(geo.resolve({ ip: '1.1.1.1' })).resolves.toBeNull();
  });

  it('returns null when the provider reports a failed lookup', async () => {
    const geo = makeGeo(() =>
      Promise.resolve({ ok: true, json: () => Promise.resolve({ status: 'fail' }) }),
    );
    await expect(geo.resolve({ ip: '5.5.5.5' })).resolves.toBeNull();
  });

  it('caches lookups so repeated resolve does not refetch', async () => {
    const fetchMock = jest
      .fn()
      .mockResolvedValue({
        ok: true,
        json: () => Promise.resolve(successPayload('EG', 'Egypt')),
      });
    (global as any).fetch = fetchMock;
    const config = { get: () => undefined } as any;
    const cacheService = new CacheService(new FakeCache() as any);
    const geo = new GeoService(config, cacheService);

    await geo.resolve({ ip: '1.2.3.4' });
    await geo.resolve({ ip: '1.2.3.4' });
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });
});
