import { RecommendedHotelService } from '../src/modules/recommend/recommended-hotel.service';
import { ProfileService } from '../src/modules/profile/profile.service';

function fakeNuitee() {
  return {
    searchHotels: jest.fn().mockResolvedValue({
      success: true,
      data: [
        {
          id: 'offer-paris-1',
          providerId: 'nuitee',
          providerName: 'Nuitee Connect',
          title: 'Grand Paris',
          city: 'Paris',
          price: 220,
          currency: 'USD',
          rating: 4.6,
          reviewCount: 320,
          imageUrl: 'https://x/paris.jpg',
          subtitle: 'Paris · 4.6★',
          metadata: {
            providerRateId: 'rate-paris-1',
            providerOfferId: 'offer-paris-1',
            providerHotelId: 'hotel-paris-1',
            refundable: true,
          },
        },
        {
          id: 'offer-paris-2',
          providerId: 'nuitee',
          providerName: 'Nuitee Connect',
          title: 'Boutique Louvre',
          city: 'Paris',
          price: 410,
          currency: 'USD',
          rating: 4.9,
          reviewCount: 90,
          imageUrl: 'https://x/louvre.jpg',
          subtitle: 'Paris · 4.9★',
          metadata: {
            providerRateId: 'rate-paris-2',
            providerOfferId: 'offer-paris-2',
            providerHotelId: 'hotel-paris-2',
            refundable: false,
          },
        },
      ],
    }),
  } as any;
}

function emptyNuitee() {
  return {
    searchHotels: jest.fn().mockResolvedValue({ success: false, data: [] }),
  } as any;
}

function fakeAi(ordered: string[] | null) {
  if (ordered === null) return null;
  return {
    providerId: 'test-ai',
    providerName: 'Test AI',
    generate: jest.fn().mockResolvedValue({
      text: JSON.stringify({ ordered, reason: 'test' }),
      sections: [],
      metadata: {},
    }),
  } as any;
}

function fakeProfiles(
  prefs: Record<string, any> = {},
  derived: Record<string, any> = {},
  countryCode?: string,
) {
  const profile = {
    preferences: prefs,
    derived,
    countryCode,
    personalizationEnabled: true,
  };
  return {
    getView: jest.fn().mockResolvedValue(profile),
    getOrCreate: jest.fn().mockResolvedValue(profile),
  } as any;
}

interface Harness {
  cache: any;
  sets: Array<{ key: string; ttl?: number }>;
  store: Map<string, any>;
}

/** Shared recording cache — proves the cache identity and the TTL. */
function recordingCache(store = new Map<string, any>()): Harness {
  const sets: Array<{ key: string; ttl?: number }> = [];
  const cache = {
    get: jest.fn(async (key: string) => store.get(key) ?? null),
    set: jest.fn(async (key: string, value: any, ttl?: number) => {
      sets.push({ key, ttl });
      store.set(key, value);
    }),
    delete: jest.fn(async () => undefined),
    invalidate: jest.fn(async () => undefined),
  } as any;
  return { cache, sets, store };
}

function nullCache(): any {
  return {
    get: async () => null,
    set: async () => undefined,
    delete: async () => undefined,
    invalidate: async () => undefined,
  };
}

function config(values: Record<string, string> = {}) {
  return { get: (key: string) => values[key] } as any;
}

function makeService(
  nuitee: any,
  ai: any,
  profiles: any,
  opts: { cache?: any; config?: any } = {},
) {
  return new RecommendedHotelService(
    nuitee,
    profiles,
    ai,
    opts.config ?? config(),
    opts.cache ?? nullCache(),
  );
}

describe('RecommendedHotelService — real provider only', () => {
  it('returns empty fallback when Nuitee returns no candidates (no fake content)', async () => {
    const service = makeService(emptyNuitee(), fakeAi(['hotel-paris-1']), fakeProfiles());
    const result = await service.recommend({ countryCode: 'FR', limit: 6 });
    expect(result.source).toBe('fallback');
    expect(result.hotels).toHaveLength(0);
  });

  it('uses the deterministic score order when the AI is unavailable', async () => {
    const service = makeService(fakeNuitee(), fakeAi(null), fakeProfiles({ budgetMax: 300 }));
    const result = await service.recommend({ countryCode: 'FR', limit: 6 });
    expect(result.source).toBe('provider');
    // hotel-paris-2 is pricier than the budget, hotel-paris-1 fits → first.
    expect(result.hotels[0].id).toBe('hotel-paris-1');
    // All returned hotels originate from the provider candidates.
    const offered = new Set(result.hotels.map((h) => h.id));
    expect(offered.has('hotel-paris-1') || offered.has('hotel-paris-2')).toBe(true);
    expect(result.hotels.length).toBeLessThanOrEqual(6);
  });

  it('respects the AI ranking order without inventing hotels (when explicitly enabled)', async () => {
    const service = makeService(
      fakeNuitee(),
      fakeAi(['hotel-paris-2', 'hotel-paris-1']),
      fakeProfiles({ preferredStars: 5 }),
      { config: config({ RECOMMEND_AI_RERANK: 'true' }) },
    );
    const result = await service.recommend({ countryCode: 'FR', limit: 6 });
    expect(result.source).toBe('provider');
    expect(result.hotels[0].id).toBe('hotel-paris-2');
    expect(result.hotels.every((h) => h.id === 'hotel-paris-1' || h.id === 'hotel-paris-2')).toBe(
      true,
    );
  });

  it('falls back to deterministic order when AI ranking throws', async () => {
    const nuitee = fakeNuitee();
    const ai = {
      providerId: 'test',
      providerName: 'AI',
      generate: jest.fn().mockRejectedValue(new Error('AI down')),
    } as any;
    const service = makeService(nuitee, ai, fakeProfiles(), {
      config: config({ RECOMMEND_AI_RERANK: 'true' }),
    });
    const result = await service.recommend({ countryCode: 'FR', limit: 6 });
    expect(result.source).toBe('provider');
    expect(result.hotels.length).toBeGreaterThan(0);
  });

  it('honours the hard limit for cards returned', async () => {
    const service = makeService(
      fakeNuitee(),
      fakeAi(['hotel-paris-1', 'hotel-paris-2']),
      fakeProfiles(),
      { config: config({ RECOMMEND_AI_RERANK: 'true' }) },
    );
    const result = await service.recommend({ countryCode: 'FR', limit: 1 });
    expect(result.hotels).toHaveLength(1);
  });
});

describe('RecommendedHotelService — ISO-2 country is always sent', () => {
  it('forwards an explicit country to every provider search, upper-cased', async () => {
    const nuitee = fakeNuitee();
    const service = makeService(nuitee, fakeAi(null), fakeProfiles());

    await service.recommend({ countryCode: 'fr', limit: 6 });

    expect(nuitee.searchHotels).toHaveBeenCalled();
    for (const call of nuitee.searchHotels.mock.calls) {
      expect(call[0].country).toBe('FR');
    }
  });

  it('falls back to the profile country when the caller sends none', async () => {
    const nuitee = fakeNuitee();
    const service = makeService(
      nuitee,
      fakeAi(null),
      fakeProfiles({}, {}, 'AE'),
    );

    const result = await service.recommend({ userId: 'u1', limit: 6 });

    expect(result.countryCode).toBe('AE');
    expect(result.confidence).toBe('profile');
    expect(nuitee.searchHotels.mock.calls[0][0].country).toBe('AE');
  });

  it('a guest with no country gets the launch market, NOT a global scan', async () => {
    const nuitee = fakeNuitee();
    const service = makeService(nuitee, fakeAi(null), fakeProfiles());

    const result = await service.recommend({ limit: 6 });

    expect(result.countryCode).toBe('EG');
    expect(result.confidence).toBe('default');
    // EG has 4 cities in the curated map — one search each, never a world scan.
    expect(nuitee.searchHotels).toHaveBeenCalledTimes(4);
    expect(nuitee.searchHotels.mock.calls.every((c: any[]) => c[0].country === 'EG')).toBe(true);
  });

  it('an unserved market degrades to the launch market instead of an empty rail', async () => {
    const nuitee = fakeNuitee();
    const service = makeService(nuitee, fakeAi(null), fakeProfiles());

    const result = await service.recommend({ countryCode: 'ZZ', limit: 6 });

    expect(result.countryCode).toBe('EG');
    expect(nuitee.searchHotels.mock.calls[0][0].country).toBe('EG');
  });

  it('a malformed code is treated as unknown (never sent to the provider)', async () => {
    const nuitee = fakeNuitee();
    const service = makeService(nuitee, fakeAi(null), fakeProfiles());

    const result = await service.recommend({ countryCode: 'e', limit: 6 });

    expect(result.countryCode).toBe('EG');
    expect(nuitee.searchHotels.mock.calls.every((c: any[]) => c[0].country === 'EG')).toBe(true);
  });
});

describe('RecommendedHotelService — snapshot cache', () => {
  it('caches a non-empty snapshot with a short TTL, keyed by country + limit + dates', async () => {
    const { cache, sets } = recordingCache();
    const service = makeService(fakeNuitee(), fakeAi(null), fakeProfiles(), { cache });

    await service.recommend({ countryCode: 'FR', limit: 6 });

    expect(sets).toHaveLength(1);
    expect(sets[0].ttl).toBe(5 * 60);
    expect(sets[0].key).toMatch(
      /^home:recommended:FR:6:\d{4}-\d{2}-\d{2}:\d{4}-\d{2}-\d{2}$/,
    );
  });

  it('a cached snapshot short-circuits the provider entirely', async () => {
    const { cache } = recordingCache();
    const nuitee = fakeNuitee();

    await makeService(nuitee, fakeAi(null), fakeProfiles(), { cache }).recommend({
      countryCode: 'FR',
      limit: 6,
    });
    const firstCount = nuitee.searchHotels.mock.calls.length;
    expect(firstCount).toBeGreaterThan(0);

    const second = await makeService(nuitee, fakeAi(null), fakeProfiles(), {
      cache,
    }).recommend({ countryCode: 'FR', limit: 6 });

    expect(nuitee.searchHotels.mock.calls.length).toBe(firstCount);
    expect(second.hotels).toHaveLength(2);
  });

  it('different countries never share a cache entry', async () => {
    const { cache, sets } = recordingCache();
    const nuitee = fakeNuitee();

    await makeService(nuitee, fakeAi(null), fakeProfiles(), { cache }).recommend({
      countryCode: 'FR',
      limit: 6,
    });
    await makeService(nuitee, fakeAi(null), fakeProfiles(), { cache }).recommend({
      countryCode: 'AE',
      limit: 6,
    });

    expect(sets.map((s) => s.key)).toEqual([
      expect.stringContaining('home:recommended:FR:'),
      expect.stringContaining('home:recommended:AE:'),
    ]);
  });

  it('failed/empty results are NOT cached (the provider may recover)', async () => {
    const { cache, sets } = recordingCache();
    const service = makeService(emptyNuitee(), fakeAi(null), fakeProfiles(), { cache });

    const result = await service.recommend({ countryCode: 'FR', limit: 6 });

    expect(result.hotels).toHaveLength(0);
    expect(sets).toHaveLength(0);
  });
});

describe('RecommendedHotelService — provenance survives ranking', () => {
  it('keeps the rate/offer ids so the card can be revalidated before booking', async () => {
    const service = makeService(fakeNuitee(), fakeAi(null), fakeProfiles());

    const result = await service.recommend({ countryCode: 'FR', limit: 6 });
    const hotel = result.hotels.find((h) => h.id === 'hotel-paris-1');

    expect(hotel).toBeDefined();
    expect(hotel!.metadata).toEqual({
      providerId: 'nuitee',
      providerName: 'Nuitee Connect',
      providerRateId: 'rate-paris-1',
      providerOfferId: 'offer-paris-1',
      providerHotelId: 'hotel-paris-1',
      refundable: true,
    });
  });
});

describe('RecommendedHotelService — no duplicate cards', () => {
  it('shows a hotel once even when several cities return it (defense in depth)', async () => {
    // Same hotel, two rates — the adapter normally dedups per hotel; the rail
    // must not depend on it.
    const nuitee = {
      searchHotels: jest.fn().mockResolvedValue({
        success: true,
        data: [
          {
            id: 'rate-low',
            title: 'Same Hotel',
            city: 'Paris',
            price: 100,
            currency: 'USD',
            rating: 4.2,
            reviewCount: 50,
            metadata: {
              providerRateId: 'rate-low',
              providerHotelId: 'dup-1',
              refundable: true,
            },
          },
          {
            id: 'rate-high',
            title: 'Same Hotel',
            city: 'Nice',
            price: 180,
            currency: 'USD',
            rating: 4.2,
            reviewCount: 50,
            metadata: {
              providerRateId: 'rate-high',
              providerHotelId: 'dup-1',
              refundable: false,
            },
          },
        ],
      }),
    } as any;
    const service = makeService(nuitee, fakeAi(null), fakeProfiles());

    const result = await service.recommend({ countryCode: 'FR', limit: 6 });

    expect(result.hotels).toHaveLength(1);
    expect(result.hotels[0].id).toBe('dup-1');
    // First (cheapest) offer wins and keeps ITS rate id.
    expect(result.hotels[0].price).toBe(100);
    expect(result.hotels[0].metadata?.providerRateId).toBe('rate-low');
  });
});

describe('RecommendedHotelService — AI re-ranking is opt-in', () => {
  it('never calls the AI when RECOMMEND_AI_RERANK is absent (Home default)', async () => {
    const ai = fakeAi(['hotel-paris-2']);
    const service = makeService(fakeNuitee(), ai, fakeProfiles());

    const result = await service.recommend({ countryCode: 'FR', limit: 6 });

    expect(ai.generate).not.toHaveBeenCalled();
    // Deterministic order stays in charge.
    expect(result.hotels[0].id).toBe('hotel-paris-1');
  });

  it('never calls the AI when RECOMMEND_AI_RERANK is "false"', async () => {
    const ai = fakeAi(['hotel-paris-2']);
    const service = makeService(fakeNuitee(), ai, fakeProfiles(), {
      config: config({ RECOMMEND_AI_RERANK: 'false' }),
    });

    await service.recommend({ countryCode: 'FR', limit: 6 });

    expect(ai.generate).not.toHaveBeenCalled();
  });
});
