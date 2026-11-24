import { PromotionalPriceService } from '../src/modules/nearby/promotional-price.service';
import { sevenOneNightWindows } from '../src/modules/nearby/geo';

function provider(
  handler: (input: { hotelIds: string[]; checkIn: string; checkOut: string }) => any[],
) {
  const calls: Array<{ hotelIds: string[]; checkIn: string; checkOut: string }> = [];
  return {
    calls,
    minRates: jest.fn(async (input: { hotelIds: string[]; checkIn: string; checkOut: string }) => {
      calls.push({ hotelIds: [...input.hotelIds], checkIn: input.checkIn, checkOut: input.checkOut });
      const data = handler(input);
      return { success: true, data, error: undefined };
    }),
  };
}

const windows = sevenOneNightWindows('2026-11-21');

describe('PromotionalPriceService', () => {
  afterEach(() => {
    delete process.env.NEARBY_MIN_RATES_CHUNK;
    delete process.env.NEARBY_PROMO_CONCURRENCY;
  });

  it('searches exactly seven consecutive one-night windows and keeps the minimum', async () => {
    const p = provider(({ checkIn }) => [
      { hotelId: 'h1', price: checkIn.endsWith('-21') ? 500 : 100 },
    ]);
    const service = new PromotionalPriceService(p as any);
    const result = await service.discoverMinimumOneNightRates({
      hotelIds: ['h1'],
      windows,
      currency: 'USD',
      nationality: 'EG',
      occupancy: 2,
      rooms: 1,
    });

    expect(p.calls).toHaveLength(7);
    expect(p.calls.map((call) => call.checkIn)).toEqual(windows.map((window) => window.checkIn));
    expect(result.prices.get('h1')).toBe(100);
    expect(result.windowsSucceeded).toBe(7);
    expect(result.windowsFailed).toBe(0);
    expect(result.partialFailure).toBe(false);
    expect(result.searchedFromDate).toBe('2026-11-21');
    expect(result.searchedToDate).toBe('2026-11-28');
  });

  it('sends consistent occupancy and rooms on every call', async () => {
    const p = provider(() => []);
    const service = new PromotionalPriceService(p as any);
    await service.discoverMinimumOneNightRates({
      hotelIds: ['h1', 'h2'],
      windows,
      currency: 'USD',
      nationality: 'EG',
      occupancy: 3,
      rooms: 2,
    });
    expect(p.calls).toHaveLength(7);
    // The service passes occupancies through the provider; capture them.
    // (minRates mock ignores extra fields, so assert via the mock's calls.)
    const occupancyCalls = (p.minRates as jest.Mock).mock.calls;
    expect(occupancyCalls).toHaveLength(7);
    for (const call of occupancyCalls) {
      expect(call[0].occupancies).toEqual([
        { adults: 3, children: [] },
        { adults: 3, children: [] },
      ]);
      expect(call[0].currency).toBe('USD');
      expect(call[0].guestNationality).toBe('EG');
    }
  });

  it('deduplicates repeated hotel ids before calling the provider', async () => {
    const p = provider(({ hotelIds }) => hotelIds.map((id) => ({ hotelId: id, price: 10 })));
    const service = new PromotionalPriceService(p as any);
    const result = await service.discoverMinimumOneNightRates({
      hotelIds: ['h1', 'h1', 'h2', 'h1'],
      windows,
      currency: 'USD',
      nationality: 'EG',
      occupancy: 2,
      rooms: 1,
    });
    const seenByWindow = new Map<string, Set<string>>();
    for (const call of p.calls) {
      const seen = seenByWindow.get(call.checkIn) ?? new Set<string>();
      for (const id of call.hotelIds) {
        expect(seen.has(id)).toBe(false);
        seen.add(id);
      }
      seenByWindow.set(call.checkIn, seen);
    }
    expect(seenByWindow.size).toBe(7);
    expect(result.prices.get('h1')).toBe(10);
    expect(result.prices.get('h2')).toBe(10);
  });

  it('chunks large hotel lists within one window', async () => {
    process.env.NEARBY_MIN_RATES_CHUNK = '20';
    const p = provider(({ hotelIds }) => hotelIds.map((id) => ({ hotelId: id, price: 10 })));
    const service = new PromotionalPriceService(p as any);
    const ids = Array.from({ length: 25 }, (_, index) => `h${index}`);
    const result = await service.discoverMinimumOneNightRates({
      hotelIds: ids,
      windows,
      currency: 'USD',
      nationality: 'EG',
      occupancy: 2,
      rooms: 1,
    });
    // 25 hotels / 20 per chunk = 2 chunks × 7 windows.
    expect(p.calls).toHaveLength(14);
    expect(result.prices.size).toBe(25);
  });

  it('keeps prices from successful windows when one window fails', async () => {
    const p = provider(({ checkIn }) => {
      if (checkIn === '2026-11-23') {
        throw new Error('provider down');
      }
      return [{ hotelId: 'h1', price: checkIn === '2026-11-22' ? 90 : 200 }];
    });
    const service = new PromotionalPriceService(p as any);
    const result = await service.discoverMinimumOneNightRates({
      hotelIds: ['h1'],
      windows,
      currency: 'USD',
      nationality: 'EG',
      occupancy: 2,
      rooms: 1,
    });
    expect(result.windowsSucceeded).toBe(6);
    expect(result.windowsFailed).toBe(1);
    expect(result.partialFailure).toBe(true);
    expect(result.prices.get('h1')).toBe(90);
  });

  it('drops invalid provider prices instead of fabricating one', async () => {
    const p = provider(({ checkIn }) => {
      if (checkIn === '2026-11-21') return [{ hotelId: 'h1', price: Number.NaN }];
      if (checkIn === '2026-11-22') return [{ hotelId: 'h1', price: 0 }];
      if (checkIn === '2026-11-23') return [{ hotelId: 'h1', price: -10 }];
      return [{ hotelId: 'h1', price: 120 }];
    });
    const service = new PromotionalPriceService(p as any);
    const result = await service.discoverMinimumOneNightRates({
      hotelIds: ['h1'],
      windows,
      currency: 'USD',
      nationality: 'EG',
      occupancy: 2,
      rooms: 1,
    });
    expect(result.prices.get('h1')).toBe(120);
    expect(result.partialFailure).toBe(false);
  });

  it('treats a success:false provider answer as a failed window', async () => {
    const p = {
      minRates: jest.fn(async () => ({ success: false, data: [], error: 'no rates' })),
    };
    const service = new PromotionalPriceService(p as any);
    const result = await service.discoverMinimumOneNightRates({
      hotelIds: ['h1'],
      windows,
      currency: 'USD',
      nationality: 'EG',
      occupancy: 2,
      rooms: 1,
    });
    expect(result.prices.size).toBe(0);
    expect(result.windowsSucceeded).toBe(0);
    expect(result.windowsFailed).toBe(7);
    expect(result.partialFailure).toBe(true);
  });

  it('times out a hung provider call', async () => {
    const p = {
      minRates: jest.fn(async () => {
        await new Promise((resolve) => setTimeout(resolve, 200));
        return { success: true, data: [{ hotelId: 'h1', price: 10 }] };
      }),
    };
    const service = new PromotionalPriceService(p as any);
    const result = await service.discoverMinimumOneNightRates({
      hotelIds: ['h1'],
      windows,
      currency: 'USD',
      nationality: 'EG',
      occupancy: 2,
      rooms: 1,
      timeoutMs: 20,
    });
    expect(result.prices.size).toBe(0);
    expect(result.windowsFailed).toBe(7);
    expect(result.partialFailure).toBe(true);
  });
});
