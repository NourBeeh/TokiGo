import { NearbyStaysService } from '../src/modules/nearby/nearby-stays.service';
import { NearbyHotelRecord } from '../src/modules/nearby/nearby-hotel.repository';
import { haversineKm } from '../src/modules/nearby/geo';

function hotel(overrides: Partial<NearbyHotelRecord> = {}): NearbyHotelRecord {
  return {
    id: 'id-' + Math.random().toString(36).slice(2),
    providerHotelId: 'prov-1',
    name: 'Hotel',
    city: 'Cairo',
    countryCode: 'EG',
    imageObjectKey: null,
    imageUrl: 'https://example.com/hotel.jpg',
    latitude: 30.0444,
    longitude: 31.2357,
    rating: 4.5,
    reviewCount: 200,
    distanceKm: 0,
    ...overrides,
  };
}

interface FakeRepo {
  calls: Array<{ center: { latitude: number; longitude: number }; radiusKm: number; limit: number }>;
  rows: NearbyHotelRecord[];
  findWithinRadius: jest.Mock;
}

function fakeRepo(rows: NearbyHotelRecord[]): FakeRepo {
  const calls: FakeRepo['calls'] = [];
  return {
    calls,
    rows,
    findWithinRadius: jest.fn(async (center: { latitude: number; longitude: number }, radiusKm: number, limit: number) => {
      calls.push({ center, radiusKm, limit });
      return rows
        .filter((row) =>
          haversineKm(center.latitude, center.longitude, row.latitude, row.longitude) <= radiusKm,
        )
        .sort(
          (a, b) =>
            haversineKm(center.latitude, center.longitude, a.latitude, a.longitude) -
            haversineKm(center.latitude, center.longitude, b.latitude, b.longitude),
        )
        .slice(0, limit);
    }),
  };
}

function fakePrices(map: Record<string, number> = {}, partialFailure = false) {
  return {
    discoverMinimumOneNightRates: jest.fn(async ({ hotelIds }: { hotelIds: string[] }) => {
      const prices = new Map<string, number>();
      for (const id of hotelIds) {
        if (map[id] !== undefined) prices.set(id, map[id]);
      }
      return {
        prices,
        searchedFromDate: '2026-11-21',
        searchedToDate: '2026-11-28',
        windowsSucceeded: partialFailure ? 6 : 7,
        windowsFailed: partialFailure ? 1 : 0,
        partialFailure,
      };
    }),
  };
}

function fakeCache() {
  const store = new Map<string, any>();
  return {
    store,
    get: jest.fn(async (key: string) => store.get(key) ?? null),
    set: jest.fn(async (key: string, value: any) => {
      store.set(key, value);
    }),
    delete: jest.fn(async (key: string) => {
      store.delete(key);
    }),
    invalidate: jest.fn(async (pattern: string) => {
      const regex = new RegExp(pattern.split('*').map((part) =>
        part.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')).join('.*'));
      for (const key of [...store.keys()]) {
        if (regex.test(key)) store.delete(key);
      }
    }),
  };
}

function makeService(repo: FakeRepo, prices = fakePrices(), cache = fakeCache()) {
  const discovery = { syncCity: jest.fn(async () => ({ synced: 0, indexed: 0 })) };
  const service = new NearbyStaysService(repo as any, prices as any, discovery as any, cache as any);
  return { service, discovery, cache, prices };
}

describe('NearbyStaysService', () => {
  afterEach(() => {
    delete process.env.NEARBY_AUTO_SYNC;
    delete process.env.NEARBY_RADIUS_STAGES;
  });

  it('refuses to invent a center: no location means locationRequired', async () => {
    const repo = fakeRepo([]);
    const { service } = makeService(repo);
    const result = await service.getNearbyStays({ limit: 6 });
    expect(result.locationRequired).toBe(true);
    expect(result.reason).toBe('no_location');
    expect(result.stays).toEqual([]);
    expect(repo.findWithinRadius).not.toHaveBeenCalled();
  });

  it('refuses an unknown user-selected city instead of defaulting to another city', async () => {
    const repo = fakeRepo([]);
    const { service } = makeService(repo);
    const result = await service.getNearbyStays({ city: 'Nowhere', country: 'EG' });
    expect(result.locationRequired).toBe(true);
    expect(result.reason).toBe('unknown_city');
    expect(repo.findWithinRadius).not.toHaveBeenCalled();
  });

  it('uses a user-selected city as a medium-confidence center', async () => {
    const repo = fakeRepo([hotel({ providerHotelId: 'h1' })]);
    const { service } = makeService(repo, fakePrices({ h1: 100 }));
    const result = await service.getNearbyStays({ city: 'Cairo', country: 'EG', limit: 6 });
    expect(result.locationRequired).toBe(false);
    expect(result.locationSource).toBe('city');
    expect(result.locationConfidence).toBe('medium');
    expect(repo.findWithinRadius).toHaveBeenCalled();
    expect(repo.calls[0].center).toEqual({ latitude: 30.0444, longitude: 31.2357 });
  });

  it('uses GPS coordinates and lowers confidence for a coarse fix', async () => {
    const repo = fakeRepo([hotel({ providerHotelId: 'h1' })]);
    const { service } = makeService(repo, fakePrices({ h1: 100 }));
    const precise = await service.getNearbyStays({ latitude: 30.05, longitude: 31.24, limit: 6 });
    expect(precise.locationSource).toBe('gps');
    expect(precise.locationConfidence).toBe('high');

    const coarse = await service.getNearbyStays({
      latitude: 30.05,
      longitude: 31.24,
      accuracy: 2500,
      limit: 6,
    });
    expect(coarse.locationConfidence).toBe('medium');
  });

  it('expands the radius only until enough qualified results exist', async () => {
    const near = hotel({ id: 'near', providerHotelId: 'near', latitude: 30.05, longitude: 31.24 });
    const mid = hotel({ id: 'mid', providerHotelId: 'mid', latitude: 30.09, longitude: 31.28 });
    const far = hotel({ id: 'far', providerHotelId: 'far', latitude: 30.2, longitude: 31.4 });
    const repo = fakeRepo([near, mid, far]);
    const { service } = makeService(repo, fakePrices({ near: 100, mid: 120, far: 80 }));

    const result = await service.getNearbyStays({ latitude: 30.0444, longitude: 31.2357, limit: 3 });
    // The third hotel is ~23 km out, so the search must reach the 35 km stage.
    expect(repo.calls.map((call) => call.radiusKm)).toEqual([5, 10, 20, 35]);
    expect(result.radiusKm).toBe(35);
    expect(result.stays).toHaveLength(3);
  });

  it('starts at 5 km and stops as soon as the target is met', async () => {
    const rows = Array.from({ length: 6 }, (_, index) =>
      hotel({ id: `h${index}`, providerHotelId: `h${index}`, latitude: 30.05, longitude: 31.24 }),
    );
    const repo = fakeRepo(rows);
    const prices = fakePrices(Object.fromEntries(rows.map((row) => [row.providerHotelId, 100])));
    const { service } = makeService(repo, prices);
    const result = await service.getNearbyStays({ latitude: 30.0444, longitude: 31.2357, limit: 4 });
    expect(repo.calls.map((call) => call.radiusKm)).toEqual([5]);
    expect(result.stays).toHaveLength(4);
  });

  it('deduplicates hotels that appear at several radius stages', async () => {
    const row = hotel({ id: 'same', providerHotelId: 'same', latitude: 30.05, longitude: 31.24 });
    const repo = fakeRepo([row]);
    const { service } = makeService(repo, fakePrices({ same: 100 }));
    const result = await service.getNearbyStays({ latitude: 30.0444, longitude: 31.2357, limit: 6 });
    expect(repo.calls.length).toBeGreaterThan(1);
    expect(result.stays).toHaveLength(1);
    expect(result.stays[0].hotelId).toBe('same');
  });

  it('walks to the maximum radius and reports an honest empty result', async () => {
    const repo = fakeRepo([]);
    const { service } = makeService(repo);
    const result = await service.getNearbyStays({ latitude: 30.0444, longitude: 31.2357, limit: 6 });
    // Six stages, then one guarded retry after the (empty) inventory sync.
    expect(repo.calls.map((call) => call.radiusKm)).toEqual([
      5, 10, 20, 35, 50, 75, 5, 10, 20, 35, 50, 75,
    ]);
    expect(result.stays).toEqual([]);
    expect(result.reason).toBe('no_geotagged_inventory');
    expect(result.radiusKm).toBe(5);
  });

  it('syncs ONE selected city when the catalog has no inventory, then retries', async () => {
    const repo = fakeRepo([]);
    const { service, discovery } = makeService(repo, fakePrices({ h1: 100 }));
    // The sync makes one geotagged hotel available.
    (discovery.syncCity as jest.Mock).mockImplementation(async () => {
      repo.rows.push(hotel({ id: 'h1', providerHotelId: 'h1', latitude: 30.05, longitude: 31.24 }));
      return { synced: 1, indexed: 0 };
    });

    const result = await service.getNearbyStays({ city: 'Cairo', country: 'EG', limit: 6 });
    expect(discovery.syncCity).toHaveBeenCalledTimes(1);
    expect(discovery.syncCity).toHaveBeenCalledWith({ city: 'Cairo', country: 'EG' });
    expect(result.stays).toHaveLength(1);
    expect(result.stays[0].hotelId).toBe('h1');
  });

  it('does not mark a partial sync as done for 24 hours', async () => {
    const repo = fakeRepo([]);
    const cache = fakeCache();
    const { service, discovery } = makeService(repo, fakePrices(), cache);
    (discovery.syncCity as jest.Mock).mockImplementation(async () => ({
      synced: 3,
      indexed: 3,
      complete: false,
      pagesFetched: 1,
      failedPages: [200],
    }));

    await service.getNearbyStays({ city: 'Cairo', country: 'EG', limit: 6 });

    const flagWrites = cache.set.mock.calls.filter((call: any[]) =>
      String(call[0]).startsWith('nearby:inventory-synced:'),
    );
    expect(flagWrites).toHaveLength(0);
  });

  it('marks a complete sync as done and drops the stale nearby cache', async () => {
    const repo = fakeRepo([]);
    const cache = fakeCache();
    const { service, discovery } = makeService(repo, fakePrices(), cache);
    (discovery.syncCity as jest.Mock).mockImplementation(async () => ({
      synced: 2,
      indexed: 2,
      complete: true,
      pagesFetched: 1,
      failedPages: [],
    }));

    await service.getNearbyStays({ city: 'Cairo', country: 'EG', limit: 6 });

    const flagWrites = cache.set.mock.calls.filter((call: any[]) =>
      String(call[0]).startsWith('nearby:inventory-synced:'),
    );
    expect(flagWrites).toHaveLength(1);
    expect(cache.invalidate).toHaveBeenCalledWith('home:nearby-stays:*');
  });

  it('syncs only the nearest supported city, never a distant one', async () => {
    const repo = fakeRepo([]);
    const { service, discovery } = makeService(repo);
    const result = await service.getNearbyStays({ latitude: 30.0444, longitude: 31.2357, limit: 6 });
    expect(discovery.syncCity).toHaveBeenCalledTimes(1);
    expect(discovery.syncCity).toHaveBeenCalledWith({ city: 'Cairo', country: 'EG' });
    expect(result.reason).toBe('no_geotagged_inventory');
  });

  it('reports no_valid_promotional_price when no candidate has a valid price', async () => {
    const repo = fakeRepo([hotel({ providerHotelId: 'h1' })]);
    const { service } = makeService(repo, fakePrices({}));
    const result = await service.getNearbyStays({ latitude: 30.0444, longitude: 31.2357, limit: 6 });
    expect(result.stays).toEqual([]);
    expect(result.reason).toBe('no_valid_promotional_price');
  });

  it('never caches a partial-failure response', async () => {
    const repo = fakeRepo([hotel({ providerHotelId: 'h1' })]);
    const cache = fakeCache();
    const { service } = makeService(repo, fakePrices({ h1: 100 }, true), cache);
    const result = await service.getNearbyStays({ latitude: 30.0444, longitude: 31.2357, limit: 6 });
    expect(result.partialFailure).toBe(true);
    expect(cache.set).not.toHaveBeenCalled();
  });

  it('caches a successful response and serves the next call from cache', async () => {
    const repo = fakeRepo([hotel({ providerHotelId: 'h1' })]);
    const cache = fakeCache();
    const { service } = makeService(repo, fakePrices({ h1: 100 }), cache);

    const first = await service.getNearbyStays({ latitude: 30.0444, longitude: 31.2357, limit: 1 });
    expect(first.stays).toHaveLength(1);
    expect(cache.set).toHaveBeenCalledTimes(1);

    const second = await service.getNearbyStays({ latitude: 30.0444, longitude: 31.2357, limit: 1 });
    expect(second.stays).toHaveLength(1);
    expect(repo.findWithinRadius).toHaveBeenCalledTimes(1);
  });

  it('uses a different cache key for a different center, currency or window', async () => {
    const repo = fakeRepo([hotel({ providerHotelId: 'h1' })]);
    const cache = fakeCache();
    const { service } = makeService(repo, fakePrices({ h1: 100 }), cache);
    await service.getNearbyStays({ latitude: 30.0444, longitude: 31.2357, limit: 1 });
    await service.getNearbyStays({ latitude: 30.5, longitude: 31.5, limit: 1 });
    await service.getNearbyStays({ latitude: 30.0444, longitude: 31.2357, limit: 1, currency: 'EUR' });
    await service.getNearbyStays({ latitude: 30.0444, longitude: 31.2357, limit: 1, fromDate: '2026-12-01' });
    expect(cache.store.size).toBe(4);
  });

  it('computes the actual distance from the center', async () => {
    const repo = fakeRepo([hotel({ providerHotelId: 'h1', latitude: 30.05, longitude: 31.24 })]);
    const { service } = makeService(repo, fakePrices({ h1: 100 }));
    const result = await service.getNearbyStays({ latitude: 30.0444, longitude: 31.2357, limit: 6 });
    expect(result.stays[0].distanceKm).toBeCloseTo(
      haversineKm(30.0444, 31.2357, 30.05, 31.24),
      2,
    );
  });

  it('keeps promotional stays separate from booking offers', async () => {
    const repo = fakeRepo([hotel({ providerHotelId: 'h1' })]);
    const { service } = makeService(repo, fakePrices({ h1: 100 }));
    const result = await service.getNearbyStays({ latitude: 30.0444, longitude: 31.2357, limit: 6 });
    const stay = result.stays[0];
    expect(stay).not.toHaveProperty('offerId');
    expect(stay).not.toHaveProperty('rateId');
    expect(stay).not.toHaveProperty('prebookId');
    expect(stay).not.toHaveProperty('priceVerified');
    expect(stay.promotionalMinimumPrice).toBe(100);
  });
});
