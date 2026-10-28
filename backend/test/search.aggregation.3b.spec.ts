import { RegistrySyncService } from '../src/modules/providers/registry.sync.service';
import { ProviderRegistryImpl } from '../src/common/providers/provider.registry.impl';
import { SearchService } from '../src/modules/providers/search.service';
import { PricingService } from '../src/common/market/pricing.service';
import { FxService } from '../src/common/market/fx.service';
import { CacheService } from '../src/modules/cache/cache.service';
import { NuiteeFlightService } from '../src/modules/nuitee/nuitee.flight.service';

/**
 * Phase 3B — Search provider aggregation contracts (spec points 12, 13, 7):
 * per-provider timeout, partial-failure isolation (resolved success:false is
 * a FAILURE), deterministic dedup with provider identity preserved, currency
 * enrichment without inventing prices, and short-TTL caching that is never
 * booking truth.
 */

function nullCache(): CacheService {
  return new CacheService({
    get: async () => null,
    set: async () => undefined,
    delete: async () => undefined,
    invalidate: async () => undefined,
  } as any);
}

function recordingCache(): { cache: CacheService; sets: Array<{ key: string; ttl?: number }> } {
  const sets: Array<{ key: string; ttl?: number }> = [];
  const cache = new CacheService({
    get: async () => null,
    set: async (_k: string, _v: any, ttl?: number) => {
      sets.push({ key: _k, ttl });
    },
    delete: async () => undefined,
    invalidate: async () => undefined,
  } as any);
  return { cache, sets };
}

function makePricing(): PricingService {
  return new PricingService(new FxService(nullCache()));
}

/** Deterministic FX for every test: USD->EGP 48.5. */
function fixedFxPricing(): { pricing: PricingService; spy: jest.SpyInstance } {
  const fx = new FxService(nullCache());
  const spy = jest
    .spyOn(globalThis, 'fetch')
    .mockResolvedValue({ ok: true, json: async () => ({ rates: { EGP: 48.5 } }) } as any);
  return { pricing: new PricingService(fx), spy };
}

function makeService(cache: CacheService, pricing: PricingService, providerTimeoutMs = 20) {
  const registry = new ProviderRegistryImpl();
  // providerTimeoutMs is a FIELD (not a constructor param) — Nest's DI
  // would otherwise try to resolve `Number` at boot (live incident
  // 2026-09-09). Tests set it directly after construction.
  const service = new SearchService(registry, cache, pricing);
  service.providerTimeoutMs = providerTimeoutMs;
  return { service, registry };
}

function provider(
  id: string,
  result: () => any,
  method: 'searchFlights' | 'searchHotels' | 'searchCars' = 'searchFlights',
) {
  return { providerId: id, [method]: result } as any;
}

describe('SearchService — 3B aggregation contracts', () => {
  afterEach(() => jest.restoreAllMocks());

  it('keeps mood as search context without forwarding it to providers', async () => {
    const { service, registry } = makeService(nullCache(), makePricing());
    let providerParams: any;
    registry.registerFlight(
      provider('context-probe', (params: any) => {
        providerParams = params;
        return { success: true, providerId: 'context-probe', data: [] };
      }),
    );

    await service.searchFlights({
      origin: 'CAI',
      destination: 'DXB',
      market: 'EG',
      mood: 'snow',
    });

    expect(providerParams).toEqual({
      origin: 'CAI',
      destination: 'DXB',
      market: 'EG',
    });
  });

  it('success: aggregates two providers, enriches prices, preserves provider identity', async () => {
    const { pricing, spy } = fixedFxPricing();
    const { service, registry } = makeService(nullCache(), pricing);
    registry.registerFlight(
      provider('a', () => ({
        success: true,
        providerId: 'a',
        data: [
          {
            id: 'off-a1',
            type: 'flight',
            providerId: 'a',
            providerName: 'A',
            title: 'CAI → DXB',
            price: 100,
            currency: 'USD',
            airline: 'MS',
            flightNumber: '985',
            departureTime: '2026-10-01T08:00:00',
            origin: 'CAI',
            destination: 'DXB',
            metadata: { providerOfferId: 'off-a1' },
          },
        ],
      })),
    );
    registry.registerFlight(
      provider('b', () => ({
        success: true,
        providerId: 'b',
        data: [
          {
            id: 'off-b1',
            type: 'flight',
            providerId: 'b',
            providerName: 'B',
            title: 'CAI → PAR',
            price: 80,
            currency: 'USD',
            airline: 'MS',
            flightNumber: '986',
            departureTime: '2026-10-01T09:00:00',
            origin: 'CAI',
            destination: 'PAR',
            metadata: { providerOfferId: 'off-b1' },
          },
        ],
      })),
    );

    const res: any = await service.searchFlights({});
    expect(res.successes).toHaveLength(2);
    const a = res.successes[0].data[0];
    const b = res.successes[1].data[0];
    expect(a.providerId).toBe('a');
    expect(b.providerId).toBe('b');
    // Display enrichment attached, provider amount untouched (no invented prices).
    expect(a.customerPrice.customerAmount).toBe(4850);
    expect(a.price).toBe(100);
    expect(a.currency).toBe('USD');
    spy.mockRestore();
  });

  it('deterministic dedup: same flight from two providers collapses by canonical key, FIRST provider wins', async () => {
    const { service, registry } = makeService(nullCache(), makePricing());
    const mk = (id: string, price: number) => (type: 'flight', providerId: string) => ({
      success: true,
      providerId,
      data: [
        {
          id,
          type: 'flight',
          providerId,
          title: 'CAI → DXB',
          price,
          currency: 'USD',
          airline: 'MS',
          flightNumber: '985',
          departureTime: '2026-10-01T08:00:00',
          origin: 'CAI',
          destination: 'DXB',
        },
      ],
    });
    registry.registerFlight(provider('primary', () => mk('f1', 100)('flight', 'primary')));
    registry.registerFlight(provider('secondary', () => mk('f2', 90)('flight', 'secondary')));

    const res: any = await service.searchFlights({});
    expect(res.duplicatesDropped).toBe(1);
    const kept = res.successes[0].data;
    expect(kept).toHaveLength(1);
    expect(kept[0].providerId).toBe('primary');
    // The duplicate survived as a provider-distinct offer identity-wise: the
    // SECOND provider's group is now empty, not merged into the first.
    expect(res.successes[1].data).toHaveLength(0);
    // Determinism: same call again → same result.
    const again: any = await service.searchFlights({});
    expect(again.successes[0].data[0].id).toBe('f1');
  });

  it('partial failure: resolved success:false is classified as a FAILURE, not a success', async () => {
    const { service, registry } = makeService(nullCache(), makePricing());
    registry.registerFlight(
      provider('nuitee', () => ({
        success: true,
        providerId: 'nuitee',
        data: [
          {
            id: 'n1',
            type: 'flight',
            providerId: 'nuitee',
            title: 'CAI → DXB',
            price: 100,
            currency: 'USD',
            airline: 'MS',
            flightNumber: '985',
            departureTime: '2026-10-01T08:00:00',
            origin: 'CAI',
            destination: 'DXB',
          },
        ],
      })),
    );
    // Keyless/disabled adapters RESOLVE with success:false (they never throw).
    registry.registerFlight(
      provider('duffel', () => ({
        success: false,
        providerId: 'duffel',
        error: 'DUffel access token missing',
        data: [],
      })),
    );

    const res: any = await service.searchFlights({});
    expect(res.successes.map((s: any) => s.providerId)).toEqual(['nuitee']);
    expect(res.failures).toHaveLength(1);
    expect(res.failures[0].providerId).toBe('duffel');
    expect(res.failures[0].error).toContain('DUffel');
  });

  it('partial failure: a throwing provider never fails the whole search', async () => {
    const { service, registry } = makeService(nullCache(), makePricing());
    registry.registerFlight(provider('bad', () => Promise.reject(new Error('boom'))));
    registry.registerFlight(
      provider('good', () => ({
        success: true,
        providerId: 'good',
        data: [
          {
            id: 'g1',
            type: 'flight',
            providerId: 'good',
            title: 'X',
            price: 10,
            currency: 'USD',
          },
        ],
      })),
    );

    const res: any = await service.searchFlights({});
    expect(res.successes).toHaveLength(1);
    expect(res.failures[0].error).toBe('boom');
  });

  it('per-provider timeout: a hung provider resolves as a failure after the budget', async () => {
    const { service, registry } = makeService(nullCache(), makePricing());
    registry.registerFlight(
      provider('hung', () => new Promise(() => { /* never resolves */ })),
    );
    registry.registerFlight(
      provider('fast', () => ({
        success: true,
        providerId: 'fast',
        data: [],
      })),
    );

    const started = Date.now();
    const res: any = await service.searchFlights({});
    expect(Date.now() - started).toBeLessThan(2_000); // budget is 20ms in this suite; the race proves the hung provider never blocks
    expect(res.failures[0].providerId).toBe('hung');
    expect(res.failures[0].error).toContain('timed out');
    expect(res.successes.map((s: any) => s.providerId)).toEqual(['fast']);
  });

  it('empty: all providers succeed with no offers → successes with empty data, no failures', async () => {
    const { service, registry } = makeService(nullCache(), makePricing());
    registry.registerFlight(provider('x', () => ({ success: true, providerId: 'x', data: [] })));

    const res: any = await service.searchFlights({});
    expect(res.successes).toHaveLength(1);
    expect(res.successes[0].data).toEqual([]);
    expect(res.failures).toEqual([]);
  });

  it('malformed provider response: non-array data never crashes aggregation', async () => {
    const { service, registry } = makeService(nullCache(), makePricing());
    registry.registerFlight(provider('weird', () => ({ success: true, providerId: 'weird', data: 'not-an-array' })));

    const res: any = await service.searchFlights({});
    expect(res.successes[0].data).toEqual([]);
  });

  it('hotel dedup: same provider hotel id across providers collapses; different hotels survive', async () => {
    const { service, registry } = makeService(nullCache(), makePricing());
    const hotel = (id: string, providerId: string, hotelId: string) => ({
      success: true,
      providerId,
      data: [
        {
          id,
          type: 'hotel',
          providerId,
          title: 'Grand Hotel',
          price: 100,
          currency: 'USD',
          city: 'Dubai',
          metadata: { providerHotelId: hotelId },
        },
      ],
    });
    registry.registerHotel(provider('nuitee', () => hotel('r1', 'nuitee', 'H1'), 'searchHotels'));
    registry.registerHotel(provider('other', () => hotel('r2', 'other', 'H1'), 'searchHotels'));
    registry.registerHotel(provider('third', () => hotel('r3', 'third', 'H2'), 'searchHotels'));

    const res: any = await service.searchHotels({});
    expect(res.duplicatesDropped).toBe(1);
    const total = res.successes.reduce((n: number, s: any) => n + s.data.length, 0);
    expect(total).toBe(2); // H1 (first provider) + H2
  });

  it('cache: fully-successful searches cached with SHORT ttl; partial failures are NOT cached', async () => {
    const { cache, sets } = recordingCache();
    const { service, registry } = makeService(cache, makePricing());

    // Fully successful → cached with the short live-search TTL.
    registry.registerFlight(provider('ok', () => ({ success: true, providerId: 'ok', data: [] })));
    await service.searchFlights({ q: 1 });
    expect(sets).toHaveLength(1);
    expect(sets[0].ttl).toBe(120);
    expect(sets[0].key).toContain('search:flight:');

    // Partial failure → nothing more written to the cache.
    sets.length = 0;
    registry.registerFlight(provider('bad', () => ({ success: false, providerId: 'bad', error: 'x' })));
    await service.searchFlights({ q: 2 });
    expect(sets).toHaveLength(0);
  });

  it('cached result is returned as-is (search is never blocked by providers)', async () => {
    const seen: string[] = [];
    const cache = new CacheService({
      get: async () => ({ successes: [{ providerId: 'cached' }], failures: [], duplicatesDropped: 0 }),
      set: async () => undefined,
      delete: async () => undefined,
      invalidate: async () => undefined,
    } as any);
    const { service, registry } = makeService(cache, makePricing());
    registry.registerFlight(
      provider('live', () => {
        seen.push('live');
        return { success: true, providerId: 'live', data: [] };
      }),
    );

    const res: any = await service.searchFlights({ q: 3 });
    expect(res.successes[0].providerId).toBe('cached');
    expect(seen).toEqual([]); // providers never ran — cache short-circuits.
  });
});

describe('NuiteeFlightService — 3B adapter (fixture contract, no network)', () => {
  const config = { get: (n: string) => (n === 'NUITEE_API_KEY' ? 'sand_test_key' : undefined) };
  const service = new NuiteeFlightService(config as any);

  it('maps the documented journeys>offers shape into the shared flight offer format', () => {
    const response = {
      data: [
        {
          journeys: [
            {
              journeyKey: 'jkey1',
              totalDuration: { iso8601: 'PT7H45M', minutes: 465 },
              segments: [
                {
                  originCode: 'JFK',
                  destinationCode: 'CDG',
                  departureTime: '2026-07-01T16:10:00',
                  arrivalTime: '2026-07-02T05:55:00',
                  carrier: { marketingName: 'Condor Flugdienst', marketingCode: 'DE' },
                  flight: { marketingNumber: '2017' },
                },
              ],
              offers: [
                {
                  offerId: 'offer-abc-123',
                  expiration: '2026-03-19T12:52:59.494Z',
                  pricing: { display: { total: 753.87, currency: 'USD', base: 403.63, taxes: 350.24 } },
                  fare: { family: 'Economy' },
                  terms: { refundable: false },
                },
              ],
            },
          ],
        },
      ],
    };

    const offers = service.mapResponse(response, { origin: 'JFK', destination: 'CDG' });
    expect(offers).toHaveLength(1);
    const o = offers[0];
    expect(o.id).toBe('offer-abc-123');
    expect(o.providerId).toBe('nuitee-flight');
    expect(o.type).toBe('flight');
    expect(o.title).toBe('JFK → CDG');
    expect(o.airline).toBe('Condor Flugdienst');
    expect(o.flightNumber).toBe('DE2017');
    expect(o.price).toBe(753.87);
    expect(o.currency).toBe('USD');
    expect(o.stops).toBe(0);
    expect(o.metadata.providerOfferId).toBe('offer-abc-123');
    expect(o.metadata.journeyKey).toBe('jkey1');
    expect(o.metadata.expiresAt).toBe('2026-03-19T12:52:59.494Z');
  });

  it('drops malformed offers (no price / no offerId) — nothing invented', () => {
    const response = {
      data: [
        {
          journeys: [
            {
              segments: [],
              offers: [
                { offerId: 'x', pricing: { display: { total: 'NaN-string', currency: 'USD' } } },
                { pricing: { display: { total: 100, currency: 'USD' } } }, // no offerId
                { offerId: 'y', pricing: {} }, // no display price
              ],
            },
          ],
        },
      ],
    };
    const offers = service.mapResponse(response, { origin: 'A', destination: 'B' });
    expect(offers).toEqual([]);
  });

  it('without an API key the adapter resolves success:false (never throws)', async () => {
    const keyless = new NuiteeFlightService({ get: () => undefined } as any);
    const result = await keyless.searchFlights({
      origin: 'CAI',
      destination: 'DXB',
      departure: new Date('2026-10-01'),
      passengers: 1,
    });
    expect(result.success).toBe(false);
    expect(result.error).toContain('NUITEE_API_KEY missing');
    expect(result.data).toEqual([]);
  });

  it('sends the legs-based body the endpoint documents (round-trip = 2 legs)', async () => {
    const calls: any[] = [];
    const spy = jest.spyOn(globalThis, 'fetch').mockImplementation(async (url: any, init: any) => {
      calls.push({ url: String(url), body: JSON.parse(init.body) });
      throw new Error('offline');
    });
    await service.searchFlights({
      origin: 'cairo',
      destination: 'dubai',
      departure: new Date('2026-10-01T00:00:00Z'),
      returnDate: new Date('2026-10-07T00:00:00Z'),
      passengers: 2,
    });
    expect(calls).toHaveLength(1);
    expect(calls[0].url).toContain('/flights/rates');
    expect(calls[0].body.legs).toEqual([
      { origin: 'CAI', destination: 'DXB', date: '2026-10-01', direction: 'OUTBOUND' },
      { origin: 'DXB', destination: 'CAI', date: '2026-10-07', direction: 'INBOUND' },
    ]);
    expect(calls[0].body.adults).toBe(2);
    expect(calls[0].body.currency).toBe('USD');
    spy.mockRestore();
  });
});

describe('Registry defaults — 3B decisions encoded (hotels Nuitee-only, Nuitee flight alternative)', () => {
  it('DEFAULTS declare nuitee-flight as the flight fallback (priority 2, inactive until admin enables)', () => {
    const nuiteeFlight = RegistrySyncService.DEFAULTS.find((d) => d.key === 'nuitee-flight');
    expect(nuiteeFlight).toBeDefined();
    expect(nuiteeFlight!.vertical).toBe('flight');
    expect(nuiteeFlight!.priority).toBe(2);
    expect(nuiteeFlight!.isFallback).toBe(true);
  });

  it('DEFAULTS keep the fabricated hotel catalogues OFF by default', () => {
    const nuitee = RegistrySyncService.DEFAULTS.find((d) => d.key === 'nuitee');
    expect(nuitee?.isActive).not.toBe(false);

    for (const key of ['duffel-hotel', 'mock-hotel']) {
      const provider = RegistrySyncService.DEFAULTS.find((d) => d.key === key);
      expect(provider).toBeDefined();
      // A provider whose adapter serves a curated fake catalogue must never
      // be seeded as active: its hotels would display as live inventory.
      expect(provider?.isActive).toBe(false);
    }
  });
});
