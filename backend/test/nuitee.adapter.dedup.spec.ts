import { NuiteeService } from '../src/modules/nuitee/nuitee.service';

/**
 * Nuitee rates adapter contracts (Phase 2C).
 *
 * One hotel row per hotel, carrying EVERY valid room-type offer in `offers`;
 * the row's own fields are the cheapest offer. Pagination is sequential and
 * bounded, and an incomplete walk is reported (never cached or presented as
 * the whole market). Prebook/book follow the documented LiteAPI contracts.
 */

/** Live-shape fixture: rates array wrapped in `data`, hotels under `hotels`. */
function nuiteeResponse(hotelsPayload: any) {
  return {
    ok: true,
    status: 200,
    text: async () => JSON.stringify(hotelsPayload),
  };
}

function rate(rateId: string, amount: number, currency = 'USD') {
  return {
    rateId,
    retailRate: { total: [{ amount, currency }] },
    cancellationPolicies: { refundableTag: 'RFN' },
  };
}

function roomType(
  offerId: string,
  roomTypeName: string,
  rates: any[],
  total: number,
  currency = 'USD',
) {
  return {
    offerId,
    roomTypeName,
    rates,
    offerRetailRate: [{ amount: total, currency }],
  };
}

function makeService(contentCache?: any) {
  const config = { get: () => 'sand_test-key' }; // sandbox-style key
  return new NuiteeService(config as any, contentCache);
}

function offersOf(result: any): any[] {
  return result.data ?? [];
}

const SEARCH = {
  city: 'Cairo',
  country: 'EG',
  checkIn: new Date('2026-09-10'),
  checkOut: new Date('2026-09-13'),
  guests: 2,
  rooms: 1,
};

describe('NuiteeService.searchHotels — one hotel row, all valid offers', () => {
  const realFetch = global.fetch;

  beforeEach(() => {
    (global as any).fetch = jest.fn();
  });

  afterEach(() => {
    delete process.env.NUITEE_RATES_PAGE_SIZE;
    delete process.env.NUITEE_RATES_MAX_PAGES;
  });

  afterAll(() => {
    (global as any).fetch = realFetch;
  });

  it('same hotel with 2 room types → ONE row carrying BOTH offers, cheapest on top', async () => {
    (global as any).fetch = jest.fn().mockResolvedValue(
      nuiteeResponse({
        data: [
          {
            hotelId: 'H1',
            roomTypes: [
              roomType('offer-std', 'Standard Room', [rate('rate-std', 120)], 120),
              roomType('offer-dlx', 'Deluxe Room', [rate('rate-dlx', 180)], 180),
            ],
          },
        ],
        hotels: [{ id: 'H1', name: 'Cairo Grand', city_name: 'Cairo' }],
      }),
    );

    const result = await makeService().searchHotels(SEARCH);

    expect(result.success).toBe(true);
    const offers = offersOf(result);
    expect(offers).toHaveLength(1);
    expect(offers[0].id).toBe('offer-std');
    expect(offers[0].price).toBe(120);
    expect(offers[0].offers.map((o: any) => o.id)).toEqual([
      'offer-std',
      'offer-dlx',
    ]);
    expect(offers[0].offers.map((o: any) => o.price)).toEqual([120, 180]);
    // The booking identity is the room-type offerId, not a per-room rate id.
    expect(offers[0].metadata.providerOfferId).toBe('offer-std');
  });

  it('different hotels each keep their own row, cheapest first', async () => {
    (global as any).fetch = jest.fn().mockResolvedValue(
      nuiteeResponse({
        data: [
          {
            hotelId: 'H1',
            roomTypes: [
              roomType('offer-h1', 'Standard', [rate('r-h1', 120)], 120),
            ],
          },
          {
            hotelId: 'H2',
            roomTypes: [
              roomType('offer-h2', 'Suite', [rate('r-h2', 90)], 90),
            ],
          },
        ],
        hotels: [
          { id: 'H1', name: 'Cairo Grand', city_name: 'Cairo' },
          { id: 'H2', name: 'Nile View', city_name: 'Cairo' },
        ],
      }),
    );

    const result = await makeService().searchHotels(SEARCH);

    expect(result.success).toBe(true);
    expect(offersOf(result).map((o: any) => o.id)).toEqual([
      'offer-h2',
      'offer-h1',
    ]);
  });

  it('multiple rates within ONE room type stay ONE offer priced at the all-room total', async () => {
    (global as any).fetch = jest.fn().mockResolvedValue(
      nuiteeResponse({
        data: [
          {
            hotelId: 'H1',
            roomTypes: [
              roomType(
                'offer-multi',
                'Family Room',
                [rate('r-room-1', 100), rate('r-room-2', 100)],
                200,
              ),
            ],
          },
        ],
        hotels: [{ id: 'H1', name: 'Cairo Grand' }],
      }),
    );

    const result = await makeService().searchHotels({
      ...SEARCH,
      rooms: 2,
      guests: 4,
      occupancies: [
        { adults: 2 },
        { adults: 2 },
      ],
    });

    expect(offersOf(result)).toHaveLength(1);
    expect(offersOf(result)[0].id).toBe('offer-multi');
    expect(offersOf(result)[0].price).toBe(200);
    expect(offersOf(result)[0].metadata.providerRateIds).toEqual([
      'r-room-1',
      'r-room-2',
    ]);
    expect(offersOf(result)[0].offers).toHaveLength(1);
  });

  it('walks pages until a short page and reports the set complete', async () => {
    process.env.NUITEE_RATES_PAGE_SIZE = '2';
    const fetch = jest
      .fn()
      .mockResolvedValueOnce(
        nuiteeResponse({
          data: [
            { hotelId: 'H1', roomTypes: [roomType('o1', 'A', [rate('r1', 100)], 100)] },
            { hotelId: 'H2', roomTypes: [roomType('o2', 'A', [rate('r2', 110)], 110)] },
          ],
          hotels: [{ id: 'H1' }, { id: 'H2' }],
        }),
      )
      .mockResolvedValueOnce(
        nuiteeResponse({
          data: [
            { hotelId: 'H3', roomTypes: [roomType('o3', 'A', [rate('r3', 90)], 90)] },
          ],
          hotels: [{ id: 'H3' }],
        }),
      );
    (global as any).fetch = fetch;

    const result = await makeService().searchHotels(SEARCH);

    expect(fetch).toHaveBeenCalledTimes(2);
    expect(JSON.parse(fetch.mock.calls[1][1].body)).toMatchObject({
      limit: 2,
      offset: 2,
    });
    expect(offersOf(result)).toHaveLength(3);
    expect(result.metadata).toMatchObject({
      complete: true,
      capReached: false,
      pagesFetched: 2,
      failedOffsets: [],
    });
  });

  it('keeps earlier pages but marks the set incomplete when a page fails', async () => {
    process.env.NUITEE_RATES_PAGE_SIZE = '2';
    const fetch = jest
      .fn()
      .mockResolvedValueOnce(
        nuiteeResponse({
          data: [
            { hotelId: 'H1', roomTypes: [roomType('o1', 'A', [rate('r1', 100)], 100)] },
            { hotelId: 'H2', roomTypes: [roomType('o2', 'A', [rate('r2', 110)], 110)] },
          ],
          hotels: [{ id: 'H1' }, { id: 'H2' }],
        }),
      )
      .mockRejectedValueOnce(new Error('vendor 500'));
    (global as any).fetch = fetch;

    const result = await makeService().searchHotels(SEARCH);

    expect(result.success).toBe(true);
    expect(offersOf(result)).toHaveLength(2);
    expect(result.metadata).toMatchObject({
      complete: false,
      capReached: false,
      pagesFetched: 1,
      failedOffsets: [2],
    });
  });

  it('marks the page cap as incomplete instead of calling it the whole market', async () => {
    process.env.NUITEE_RATES_PAGE_SIZE = '1';
    process.env.NUITEE_RATES_MAX_PAGES = '1';
    (global as any).fetch = jest.fn().mockResolvedValue(
      nuiteeResponse({
        data: [
          { hotelId: 'H1', roomTypes: [roomType('o1', 'A', [rate('r1', 100)], 100)] },
        ],
        hotels: [{ id: 'H1' }],
      }),
    );

    const result = await makeService().searchHotels(SEARCH);

    expect(offersOf(result)).toHaveLength(1);
    expect(result.metadata).toMatchObject({
      complete: false,
      capReached: true,
      pagesFetched: 1,
    });
  });

  it('rejects a multi-room request with no per-room occupancy', async () => {
    const fetch = jest.fn();
    (global as any).fetch = fetch;

    const result = await makeService().searchHotels({
      ...SEARCH,
      rooms: 2,
      guests: 4,
    });

    expect(result.success).toBe(false);
    expect(result.error).toMatch(/occupancy/i);
    expect(fetch).not.toHaveBeenCalled();
  });

  it('sends the configured settlement currency and the explicit nationality', async () => {
    const fetch = jest.fn().mockResolvedValue(
      nuiteeResponse({
        data: [
          { hotelId: 'H1', roomTypes: [roomType('o1', 'A', [rate('r1', 100)], 100)] },
        ],
        hotels: [{ id: 'H1' }],
      }),
    );
    (global as any).fetch = fetch;

    await makeService().searchHotels({
      ...SEARCH,
      nationality: 'ae',
      occupancies: [{ adults: 2, children: [7] }],
    });

    const body = JSON.parse(fetch.mock.calls[0][1].body);
    expect(body).toMatchObject({
      currency: 'USD',
      guestNationality: 'AE',
      occupancies: [{ adults: 2, children: [7] }],
    });
  });
});

describe('NuiteeService.prebookHotel — documented contract', () => {
  const realFetch = global.fetch;

  beforeEach(() => {
    (global as any).fetch = jest.fn();
  });

  afterAll(() => {
    (global as any).fetch = realFetch;
  });

  it('posts { offerId, usePaymentSdk:false } and maps the root data quote', async () => {
    const fetch = jest.fn().mockResolvedValue(
      nuiteeResponse({
        data: {
          prebookId: 'pb-1',
          hotelId: 'H1',
          checkin: '2026-09-10',
          checkout: '2026-09-13',
          currency: 'USD',
          price: 120,
          priceDifferencePercent: 2,
          cancellationChanged: true,
          boardChanged: true,
          roomTypes: [{}, {}],
        },
      }),
    );
    (global as any).fetch = fetch;

    const result = await makeService().prebookHotel({ offerId: 'offer-1' });

    expect(JSON.parse(fetch.mock.calls[0][1].body)).toEqual({
      offerId: 'offer-1',
      usePaymentSdk: false,
    });
    expect(result).toMatchObject({
      success: true,
      prebookId: 'pb-1',
      newPrice: 120,
      currency: 'USD',
      priceChanged: true,
      cancellationChanged: true,
      boardChanged: true,
      roomCount: 2,
    });
    // No Payment SDK → no transactionId is required or invented.
    expect(result.transactionId).toBeUndefined();
  });

  it('rejects a prebook response without a price or currency', async () => {
    (global as any).fetch = jest.fn().mockResolvedValue(
      nuiteeResponse({ data: { prebookId: 'pb-1', currency: 'USD' } }),
    );

    const result = await makeService().prebookHotel({ offerId: 'offer-1' });

    expect(result.success).toBe(false);
    expect(result.prebookId).toBeUndefined();
  });

  it('rejects an empty offerId before any HTTP call', async () => {
    const fetch = jest.fn();
    (global as any).fetch = fetch;

    const result = await makeService().prebookHotel({ offerId: '  ' });

    expect(result.success).toBe(false);
    expect(fetch).not.toHaveBeenCalled();
  });
});

describe('NuiteeService.bookHotel — documented contract', () => {
  const realFetch = global.fetch;

  beforeEach(() => {
    (global as any).fetch = jest.fn();
  });

  afterAll(() => {
    (global as any).fetch = realFetch;
  });

  const holder = {
    firstName: 'Steve',
    lastName: 'Doe',
    email: 'steve@example.com',
    phone: '+201000000000',
  };
  const guests = [
    {
      occupancyNumber: 1,
      firstName: 'Sunny',
      lastName: 'Mars',
      email: 'sunny@example.com',
    },
  ];

  it('posts holder/guests/ACC_CREDIT_CARD with NO transactionId and maps the booking', async () => {
    const fetch = jest.fn().mockResolvedValue(
      nuiteeResponse({
        data: {
          bookingId: 'bk-1',
          status: 'CONFIRMED',
          currency: 'USD',
          price: 120,
          hotelConfirmationCode: 'HTL-123',
        },
      }),
    );
    (global as any).fetch = fetch;

    const result = await makeService().bookHotel({
      prebookId: 'pb-1',
      holder,
      guests,
    });

    const body = JSON.parse(fetch.mock.calls[0][1].body);
    expect(body).toEqual({
      prebookId: 'pb-1',
      holder,
      guests,
      payment: { method: 'ACC_CREDIT_CARD' },
    });
    expect(body.transactionId).toBeUndefined();
    expect(result.success).toBe(true);
    expect(result.data).toMatchObject({
      bookingId: 'bk-1',
      reference: 'HTL-123',
      hotelConfirmationCode: 'HTL-123',
      status: 'CONFIRMED',
      total: 120,
      currency: 'USD',
    });
  });

  it('leaves an absent hotel confirmation code absent (no invented reference)', async () => {
    (global as any).fetch = jest.fn().mockResolvedValue(
      nuiteeResponse({
        data: { bookingId: 'bk-2', status: 'CONFIRMED', price: 90, currency: 'USD' },
      }),
    );

    const result = await makeService().bookHotel({
      prebookId: 'pb-2',
      holder,
      guests,
    });

    expect(result.success).toBe(true);
    expect(result.data.hotelConfirmationCode).toBeUndefined();
    expect(result.data.reference).toBe('bk-2');
  });

  it('forwards the documented clientReference idempotency key and customTags', async () => {
    const fetch = jest.fn().mockResolvedValue(
      nuiteeResponse({
        data: {
          bookingId: 'bk-3',
          status: 'CONFIRMED',
          price: 120,
          currency: 'USD',
        },
      }),
    );
    (global as any).fetch = fetch;

    const result = await makeService().bookHotel({
      prebookId: 'pb-3',
      holder,
      guests,
      clientReference: 'booking-1',
      customTags: {
        BOOKING_ID: 'booking-1',
        PRICE_VERSION: 'pv-1',
        AMOUNT: '120',
        CURRENCY: 'USD',
      },
    });

    const body = JSON.parse(fetch.mock.calls[0][1].body);
    expect(body).toMatchObject({
      prebookId: 'pb-3',
      clientReference: 'booking-1',
      customTags: {
        BOOKING_ID: 'booking-1',
        PRICE_VERSION: 'pv-1',
        AMOUNT: '120',
        CURRENCY: 'USD',
      },
      payment: { method: 'ACC_CREDIT_CARD' },
    });
    expect(result.success).toBe(true);
    expect(result.data.status).toBe('CONFIRMED');
  });

  it('refuses to book without a complete holder (no placeholder email/phone)', async () => {
    const fetch = jest.fn();
    (global as any).fetch = fetch;

    const result = await makeService().bookHotel({
      prebookId: 'pb-1',
      holder: { ...holder, phone: '' },
      guests,
    });

    expect(result.success).toBe(false);
    expect(fetch).not.toHaveBeenCalled();
  });

  it('refuses to book without at least one guest with an email', async () => {
    const fetch = jest.fn();
    (global as any).fetch = fetch;

    const result = await makeService().bookHotel({
      prebookId: 'pb-1',
      holder,
      guests: [{ occupancyNumber: 1, firstName: 'A', lastName: 'B', email: '' } as any],
    });

    expect(result.success).toBe(false);
    expect(fetch).not.toHaveBeenCalled();
  });
});
