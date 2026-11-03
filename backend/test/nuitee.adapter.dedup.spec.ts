import { NuiteeService } from '../src/modules/nuitee/nuitee.service';

/**
 * BUGFIX regression (user report 2026-09-08) — "the same hotel appears twice
 * with different prices" on the Home rail and search:
 *
 * Root cause: extractRateResults emits one {hotel, roomType, rate} entry per
 * ROOM TYPE, and searchHotels mapped every entry → the same hotel surfaced
 * 2–3 times (Standard vs Deluxe at different prices). The original comment
 * said "cheapest rate per hotel" but no dedup ever ran.
 *
 * Fix under test: searchHotels keeps exactly ONE offer per hotel — the
 * cheapest available room — with the cheapest room's rateId preserved for
 * the prebook path. Verified here with a fully mocked fetch (no network).
 */

/** Live-shape fixture: rates array wrapped in `data`, hotels under `hotels`. */
function nuiteeResponse(hotelsPayload: any) {
  return {
    ok: true,
    status: 200,
    text: async () => JSON.stringify(hotelsPayload),
  };
}

function rate(rateId: string, amount: number) {
  return {
    rateId,
    retailRate: { total: [{ amount, currency: 'USD' }] },
    cancellationPolicies: { refundableTag: 'RFN' },
  };
}

function makeService(contentCache?: any) {
  const config = { get: () => 'sand_test-key' }; // sandbox-style key
  return new NuiteeService(config as any, contentCache);
}

/** Non-null accessor for the provider payload (success paths only). */
function offersOf(result: any): any[] {
  return result.data ?? [];
}

describe('NuiteeService.searchHotels — one offer per hotel (cheapest room)', () => {
  const realFetch = global.fetch;

  beforeEach(() => {
    (global as any).fetch = jest.fn();
  });

  afterAll(() => {
    (global as any).fetch = realFetch;
  });

  it('same hotel with 2 room types → exactly ONE offer at the CHEAPEST price', async () => {
    (global as any).fetch = jest.fn().mockResolvedValue(
      nuiteeResponse({
        data: [
          {
            hotelId: 'H1',
            roomTypes: [
              { roomTypeName: 'Standard Room', rates: [rate('rate-std', 120)] },
              { roomTypeName: 'Deluxe Room', rates: [rate('rate-dlx', 180)] },
            ],
          },
        ],
        hotels: [{ id: 'H1', name: 'Cairo Grand', city_name: 'Cairo' }],
      }),
    );

    const result = await makeService().searchHotels({
      city: 'Cairo',
      country: 'EG',
      checkIn: new Date('2026-09-10'),
      checkOut: new Date('2026-09-13'),
      guests: 2,
      rooms: 1,
    });

    expect(result.success).toBe(true);
    expect(offersOf(result)).toHaveLength(1); // NOT 2 — the duplicate is gone
    const offer = offersOf(result)[0];
    expect(offer.price).toBe(120); // cheapest room wins
    expect(offer.title).toBe('Cairo Grand');
    // Cheapest room's rateId survives for the prebook path.
    expect(offer.metadata.providerRateId).toBe('rate-std');
    expect(offer.metadata.providerHotelId).toBe('H1');
  });

  it('different hotels each keep their own (cheapest) offer', async () => {
    (global as any).fetch = jest.fn().mockResolvedValue(
      nuiteeResponse({
        data: [
          {
            hotelId: 'H1',
            roomTypes: [
              { roomTypeName: 'Standard', rates: [rate('r-h1', 120)] },
              { roomTypeName: 'Deluxe', rates: [rate('r-h1b', 180)] },
            ],
          },
          {
            hotelId: 'H2',
            roomTypes: [
              { roomTypeName: 'Suite', rates: [rate('r-h2', 90)] },
            ],
          },
        ],
        hotels: [
          { id: 'H1', name: 'Cairo Grand', city_name: 'Cairo' },
          { id: 'H2', name: 'Nile View', city_name: 'Cairo' },
        ],
      }),
    );

    const result = await makeService().searchHotels({
      city: 'Cairo',
      checkIn: new Date('2026-09-10'),
      checkOut: new Date('2026-09-13'),
    });

    expect(result.success).toBe(true);
    expect(offersOf(result)).toHaveLength(2);
    // Cheapest-first ordering across hotels.
    expect(offersOf(result).map((o: any) => o.metadata.providerHotelId)).toEqual([
      'H2',
      'H1',
    ]);
    expect(offersOf(result)[0].price).toBe(90);
    expect(offersOf(result)[1].price).toBe(120);
  });

  it('multiple rates within ONE room type still resolve to the cheapest rate', async () => {
    (global as any).fetch = jest.fn().mockResolvedValue(
      nuiteeResponse({
        data: [
          {
            hotelId: 'H1',
            roomTypes: [
              {
                roomTypeName: 'Standard Room',
                rates: [rate('r-expensive', 200), rate('r-cheap', 100)],
              },
            ],
          },
        ],
        hotels: [{ id: 'H1', name: 'Cairo Grand' }],
      }),
    );

    const result = await makeService().searchHotels({
      city: 'Cairo',
      checkIn: new Date('2026-09-10'),
      checkOut: new Date('2026-09-13'),
    });

    expect(offersOf(result)).toHaveLength(1);
    expect(offersOf(result)[0].price).toBe(100);
    expect(offersOf(result)[0].metadata.providerRateId).toBe('r-cheap');
  });

  it('uses Nuitee Arabic content for Arabic search results and preserves English metadata', async () => {
    const fetch = jest
      .fn()
      .mockResolvedValueOnce(
        nuiteeResponse({
          data: [
            {
              hotelId: 'H1',
              roomTypes: [
                { roomTypeName: 'Standard', rates: [rate('r-ar', 120)] },
              ],
            },
          ],
          hotels: [{ id: 'H1', name: 'Cairo Grand', city_name: 'Cairo' }],
        }),
      )
      .mockResolvedValueOnce(
        nuiteeResponse({
          data: [{ id: 'H1', name: 'فندق القاهرة الكبير' }],
        }),
      );
    (global as any).fetch = fetch;

    const result = await makeService().searchHotels({
      city: 'Cairo',
      country: 'EG',
      checkIn: new Date('2027-01-10'),
      checkOut: new Date('2027-01-12'),
      language: 'ar',
    });

    expect(result.success).toBe(true);
    expect(offersOf(result)[0].title).toBe('فندق القاهرة الكبير');
    expect(offersOf(result)[0].metadata).toMatchObject({
      hotelNameEn: 'Cairo Grand',
      hotelNameAr: 'فندق القاهرة الكبير',
    });
    expect(fetch).toHaveBeenCalledTimes(2);
    const contentUrl = String(fetch.mock.calls[1][0]);
    expect(contentUrl).toContain('/v3.0/data/hotels?');
    expect(contentUrl).toContain('hotelIds=H1');
    expect(contentUrl).toContain('language=ar');
  });

  it('falls back to the original hotel name when Nuitee has no Arabic name', async () => {
    (global as any).fetch = jest
      .fn()
      .mockResolvedValueOnce(
        nuiteeResponse({
          data: [
            {
              hotelId: 'H1',
              roomTypes: [
                { roomTypeName: 'Standard', rates: [rate('r-en', 120)] },
              ],
            },
          ],
          hotels: [{ id: 'H1', name: 'Cairo Grand' }],
        }),
      )
      .mockResolvedValueOnce(
        nuiteeResponse({ data: [{ id: 'H1', name: 'Cairo Grand' }] }),
      );

    const result = await makeService().searchHotels({
      city: 'Cairo',
      checkIn: new Date('2027-01-10'),
      checkOut: new Date('2027-01-12'),
      language: 'ar',
    });

    expect(offersOf(result)[0].title).toBe('Cairo Grand');
    expect(offersOf(result)[0].metadata.hotelNameAr).toBeUndefined();
  });

  it('caches Arabic names by language and reuses them on later searches', async () => {
    const stored = new Map<string, any>();
    const contentCache = {
      get: jest.fn(async (key: string) => stored.get(key) ?? null),
      set: jest.fn(async (key: string, value: any) => stored.set(key, value)),
    };
    const fetch = jest
      .fn()
      .mockResolvedValueOnce(
        nuiteeResponse({
          data: [
            {
              hotelId: 'H1',
              roomTypes: [
                { roomTypeName: 'Standard', rates: [rate('r-first', 120)] },
              ],
            },
          ],
          hotels: [{ id: 'H1', name: 'Cairo Grand' }],
        }),
      )
      .mockResolvedValueOnce(
        nuiteeResponse({
          data: [{ id: 'H1', name: 'فندق القاهرة الكبير' }],
        }),
      )
      .mockResolvedValueOnce(
        nuiteeResponse({
          data: [
            {
              hotelId: 'H1',
              roomTypes: [
                { roomTypeName: 'Standard', rates: [rate('r-second', 125)] },
              ],
            },
          ],
          hotels: [{ id: 'H1', name: 'Cairo Grand' }],
        }),
      );
    (global as any).fetch = fetch;

    const service = makeService(contentCache);
    const params = {
      city: 'Cairo',
      checkIn: new Date('2027-01-10'),
      checkOut: new Date('2027-01-12'),
      language: 'ar' as const,
    };
    await service.searchHotels(params);
    const repeated = await service.searchHotels(params);

    expect(offersOf(repeated)[0].title).toBe('فندق القاهرة الكبير');
    expect(fetch).toHaveBeenCalledTimes(3);
    expect(contentCache.set).toHaveBeenCalledWith(
      'nuitee:hotel-content:ar:H1',
      expect.objectContaining({ name: 'فندق القاهرة الكبير' }),
      7 * 24 * 60 * 60,
    );
    expect(contentCache.get).toHaveBeenCalledWith(
      'nuitee:hotel-content:ar:H1',
    );
    expect([...stored.keys()]).toEqual(['nuitee:hotel-content:ar:H1']);
  });
});
