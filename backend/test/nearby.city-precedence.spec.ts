import { NearbyStaysService } from '../src/modules/nearby/nearby-stays.service';
import { NearbyHotelRecord } from '../src/modules/nearby/nearby-hotel.repository';
import { MAX_NEARBY_RADIUS_KM, haversineKm } from '../src/modules/nearby/geo';

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

function fakeRepo(rows: NearbyHotelRecord[]) {
  const calls: Array<{
    center: { latitude: number; longitude: number };
    radiusKm: number;
  }> = [];
  return {
    calls,
    rows,
    findWithinRadius: jest.fn(
      async (
        center: { latitude: number; longitude: number },
        radiusKm: number,
        limit: number,
      ) => {
        calls.push({ center, radiusKm });
        return rows
          .filter(
            (row) =>
              haversineKm(
                center.latitude,
                center.longitude,
                row.latitude,
                row.longitude,
              ) <= radiusKm,
          )
          .sort(
            (a, b) =>
              haversineKm(center.latitude, center.longitude, a.latitude, a.longitude) -
              haversineKm(center.latitude, center.longitude, b.latitude, b.longitude),
          )
          .slice(0, limit);
      },
    ),
  };
}

function fakePrices(map: Record<string, number> = {}) {
  return {
    discoverMinimumOneNightRates: jest.fn(
      async ({ hotelIds }: { hotelIds: string[] }) => {
        const prices = new Map<string, number>();
        for (const id of hotelIds) {
          if (map[id] !== undefined) prices.set(id, map[id]);
        }
        return {
          prices,
          searchedFromDate: '2026-11-21',
          searchedToDate: '2026-11-28',
          windowsSucceeded: 7,
          windowsFailed: 0,
          partialFailure: false,
        };
      },
    ),
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
  };
}

function makeService(repo: ReturnType<typeof fakeRepo>, prices = fakePrices()) {
  const discovery = {
    syncCity: jest.fn(async () => ({
      synced: 0,
      indexed: 0,
      fetched: 0,
      skipped: 0,
      complete: true,
    })),
  };
  const service = new NearbyStaysService(
    repo as any,
    prices as any,
    discovery as any,
    fakeCache() as any,
  );
  return { service, discovery };
}

describe('NearbyStaysService — explicit city precedence', () => {
  afterEach(() => {
    delete process.env.NEARBY_AUTO_SYNC;
    delete process.env.NEARBY_RADIUS_STAGES;
  });

  it('a canonical cityId outranks GPS coordinates', async () => {
    const repo = fakeRepo([hotel({ providerHotelId: 'h1' })]);
    const { service } = makeService(repo, fakePrices({ h1: 100 }));
    const result = await service.getNearbyStays({
      cityId: 'london',
      latitude: 30.0444,
      longitude: 31.2357,
      limit: 6,
    });
    expect(result.locationRequired).toBe(false);
    expect(result.locationSource).toBe('city');
    expect(result.locationConfidence).toBe('medium');
    expect(repo.calls[0].center).toEqual({
      latitude: 51.5072,
      longitude: -0.1276,
    });
  });

  it('a canonical cityId outranks a conflicting city name', async () => {
    const repo = fakeRepo([hotel({ providerHotelId: 'h1' })]);
    const { service } = makeService(repo, fakePrices({ h1: 100 }));
    await service.getNearbyStays({
      cityId: 'london',
      city: 'Cairo',
      country: 'EG',
      limit: 6,
    });
    expect(repo.calls[0].center).toEqual({
      latitude: 51.5072,
      longitude: -0.1276,
    });
  });

  it('an unknown cityId is refused, never silently swapped', async () => {
    const repo = fakeRepo([hotel({ providerHotelId: 'h1' })]);
    const { service } = makeService(repo);
    const result = await service.getNearbyStays({
      cityId: 'not-a-city',
      latitude: 30.0444,
      longitude: 31.2357,
      limit: 6,
    });
    expect(result.locationRequired).toBe(true);
    expect(result.reason).toBe('unknown_city');
    expect(repo.findWithinRadius).not.toHaveBeenCalled();
  });

  it('never returns or searches beyond the 75 km ceiling', async () => {
    // ~111 km north of Cairo: outside the product ceiling.
    const distant = hotel({
      providerHotelId: 'far',
      latitude: 31.0444,
      longitude: 31.2357,
    });
    const repo = fakeRepo([distant]);
    const { service } = makeService(repo, fakePrices({ far: 100 }));
    const result = await service.getNearbyStays({
      cityId: 'cairo',
      limit: 6,
    });

    expect(repo.calls.length).toBeGreaterThan(0);
    for (const call of repo.calls) {
      expect(call.radiusKm).toBeLessThanOrEqual(MAX_NEARBY_RADIUS_KM);
    }
    expect(result.stays).toEqual([]);
  });
});
