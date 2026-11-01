import { SearchWarmupService } from '../src/modules/providers/search.warmup';

/**
 * The warmer is the only thing that spends provider budget without a user
 * asking, so its batching and its request shape are pinned here.
 */
describe('SearchWarmupService', () => {
  const originalBatch = process.env.SEARCH_WARM_BATCH;
  const originalMarkets = process.env.SEARCH_WARM_MARKETS;
  const originalWeeks = process.env.SEARCH_WARM_WEEKS;

  beforeEach(() => {
    process.env.SEARCH_WARM_BATCH = '2';
    process.env.SEARCH_WARM_MARKETS = 'EG';
    process.env.SEARCH_WARM_WEEKS = '1';
  });

  afterAll(() => {
    if (originalBatch === undefined) delete process.env.SEARCH_WARM_BATCH;
    else process.env.SEARCH_WARM_BATCH = originalBatch;
    if (originalMarkets === undefined) delete process.env.SEARCH_WARM_MARKETS;
    else process.env.SEARCH_WARM_MARKETS = originalMarkets;
    if (originalWeeks === undefined) delete process.env.SEARCH_WARM_WEEKS;
    else process.env.SEARCH_WARM_WEEKS = originalWeeks;
  });

  it('warms at most SEARCH_WARM_BATCH cities per pass, rotating', async () => {
    const calls: any[] = [];
    const fake = {
      searchHotels: async (params: any) => {
        calls.push(params);
        return { successes: [{ data: [{}] }], failures: [] };
      },
    };
    const service = new SearchWarmupService(fake as any);

    await service.tick();
    expect(calls).toHaveLength(2);
    // Two different cities: the slice rotates, it does not repeat one.
    expect(calls[0].city).not.toBe(calls[1].city);

    await service.tick();
    expect(calls).toHaveLength(4);
    const firstPass = new Set(calls.slice(0, 2).map((c) => c.city));
    expect(calls.slice(2, 4).some((c) => !firstPass.has(c.city))).toBe(true);
  });

  it('sends the same body shape the app sends', async () => {
    const calls: any[] = [];
    const fake = {
      searchHotels: async (params: any) => {
        calls.push(params);
        return { successes: [{ data: [] }], failures: [] };
      },
    };

    await new SearchWarmupService(fake as any).tick();

    const body = calls[0];
    expect(body).toMatchObject({
      city: expect.any(String),
      country: 'EG',
      guests: 2,
      rooms: 1,
      market: 'EG',
    });
    expect(body.checkIn).toMatch(/^\d{4}-\d{2}-\d{2}$/);
    expect(body.checkOut).toMatch(/^\d{4}-\d{2}-\d{2}$/);
  });

  it('never runs two passes at once', async () => {
    let calls = 0;
    let signalFirstStarted: (() => void) | undefined;
    const firstStarted = new Promise<void>((resolve) => {
      signalFirstStarted = resolve;
    });
    let unblockFirst: (() => void) | undefined;
    const gate = new Promise<void>((resolve) => {
      unblockFirst = resolve;
    });

    const fake = {
      searchHotels: async () => {
        calls += 1;
        if (calls === 1) {
          signalFirstStarted?.();
          await gate;
        }
        return { successes: [{ data: [] }], failures: [] };
      },
    };
    const service = new SearchWarmupService(fake as any);

    const first = service.tick();
    await firstStarted;
    // A second tick while the first is mid-flight must be a no-op.
    const second = service.tick();
    unblockFirst?.();
    await Promise.all([first, second]);

    expect(calls).toBe(2); // only the first pass's two cities
  });
});
