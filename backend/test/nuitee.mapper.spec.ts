import {
  dateStr,
  extractRateResults,
  firstAmount,
  hotelMetaIndex,
  mapHotelOffers,
  mapRateToOffer,
  numberOrUndefined,
} from '../src/modules/nuitee/nuitee.mapper';

/**
 * Pure-mapper contracts for the Nuitee rates response.
 *
 * The booking identity is the ROOM TYPE's `offerId`; its `rates[]` are the
 * per-room components of that one offer. These tests pin:
 * - live vs fixture payload shapes;
 * - one entry per room type with ALL its rates preserved;
 * - the offer total is `offerRetailRate` (all rooms), never one rate;
 * - no offerId / no quoted amount / mixed currencies → NO offer;
 * - tri-state refundability (missing tag is `null`, never `false`);
 * - provider fields are carried verbatim (absent stays absent);
 * - one hotel row carrying every valid offer, cheapest first.
 */

const IDENTITY = { providerId: 'nuitee', providerName: 'Nuitee Connect' };

const PARAMS = {
  city: 'Cairo',
  checkIn: new Date('2026-10-14'),
  checkOut: new Date('2026-10-17'),
};

function rate(
  rateId: string,
  amount?: number,
  currency = 'USD',
  extra: Record<string, any> = {},
) {
  return {
    rateId,
    retailRate: { total: amount === undefined ? [] : [{ amount, currency }] },
    ...extra,
  };
}

function entry(
  hotelId: string,
  offerId: string | undefined,
  roomType: string,
  rates: any[],
  offerRetailRate?: any[],
) {
  return { hotelId, offerId, roomType, rates, offerRetailRate };
}

function map(
  e: any,
  hotels: any[] = [],
  params: any = PARAMS,
): any {
  return mapRateToOffer(
    e,
    hotelMetaIndex({ hotels }),
    params,
    '2026-10-14',
    '2026-10-17',
    IDENTITY,
  );
}

describe('nuitee mapper — primitives', () => {
  it('dateStr always answers YYYY-MM-DD', () => {
    expect(dateStr(new Date('2026-09-10T22:15:00Z'))).toBe('2026-09-10');
    expect(dateStr('2026-09-11T00:00:00Z')).toBe('2026-09-11');
  });

  it('firstAmount / numberOrUndefined keep "not quoted" as undefined', () => {
    expect(firstAmount([{ amount: 120 }])).toBe(120);
    expect(firstAmount([])).toBeUndefined();
    expect(firstAmount(undefined)).toBeUndefined();
    expect(numberOrUndefined(0)).toBe(0);
    expect(numberOrUndefined('12')).toBeUndefined();
  });
});

describe('nuitee mapper — extraction', () => {
  it('keeps one entry per room type and preserves ALL of its rates', () => {
    const entries = extractRateResults({
      data: [
        {
          hotelId: 'H1',
          roomTypes: [
            {
              offerId: 'offer-exp',
              roomTypeName: 'Standard',
              rates: [rate('r-exp', 200), rate('r-cheap', 100)],
            },
            {
              offerId: 'offer-dlx',
              roomTypeName: 'Deluxe',
              rates: [rate('r-dlx', 180)],
            },
          ],
        },
      ],
    });

    expect(entries).toHaveLength(2);
    expect(entries[0].offerId).toBe('offer-exp');
    expect(entries[0].roomType).toBe('Standard');
    // Both rates of the offer survive — nothing is collapsed to the cheapest.
    expect(entries[0].rates.map((r) => r.rateId)).toEqual(['r-exp', 'r-cheap']);
    expect(entries[1].offerId).toBe('offer-dlx');
  });

  it('reads the nested fixture shape and skips room types with no rates', () => {
    const entries = extractRateResults({
      data: {
        data: [
          {
            hotelId: 'H2',
            roomTypes: [
              { offerId: 'offer-empty', roomTypeName: 'Suite', rates: [] },
              {
                offerId: 'offer-twin',
                roomTypeName: 'Twin',
                rates: [rate('r-twin', 150)],
              },
            ],
          },
        ],
      },
    });

    expect(entries).toHaveLength(1);
    expect(entries[0].offerId).toBe('offer-twin');
    expect(entries[0].roomType).toBe('Twin');
  });

  it('answers [] for a payload with no rates at all', () => {
    expect(extractRateResults({ data: [] })).toEqual([]);
    expect(extractRateResults({})).toEqual([]);
    expect(extractRateResults(null)).toEqual([]);
  });

  it('indexes hotels from both the live and the fixture location', () => {
    expect([...hotelMetaIndex({ hotels: [{ id: 'H1' }] }).keys()]).toEqual([
      'H1',
    ]);
    expect(
      [...hotelMetaIndex({ data: { hotels: [{ hotelId: 'H2' }] } }).keys()],
    ).toEqual(['H2']);
  });
});

describe('nuitee mapper — room-type offer shape', () => {
  it('uses the room-type offerId as identity and the offerRetailRate as total', () => {
    const offer = map(
      entry(
        'H1',
        'offer-1',
        'Twin',
        [
          rate('r-1', 245, 'USD', { adultCount: 2, occupancyNumber: 1 }),
          rate('r-2', 245, 'USD', { adultCount: 2, occupancyNumber: 2 }),
        ],
        [{ amount: 490, currency: 'USD' }],
      ),
      [
        {
          id: 'H1',
          name: 'Cairo Grand',
          stars: 5,
          rating: 9.6,
          city_name: 'Cairo',
          main_photo: 'https://x/h1.jpg',
          review_count: 1200,
          latitude: 30.0444,
          longitude: 31.2357,
          address: { addressLine1: '12 Nile Street' },
        },
      ],
    );

    expect(offer).not.toBeNull();
    expect(offer.id).toBe('offer-1');
    expect(offer.price).toBe(490);
    expect(offer.currency).toBe('USD');
    // 9.6 / 10 → 4.8 on the 5-star display scale.
    expect(offer.rating).toBe(4.8);
    expect(offer.title).toBe('Cairo Grand');
    expect(offer.checkIn).toBe('2026-10-14');
    expect(offer.checkOut).toBe('2026-10-17');
    expect(offer.metadata.providerOfferId).toBe('offer-1');
    expect(offer.metadata.providerRateId).toBe('r-1');
    expect(offer.metadata.providerRateIds).toEqual(['r-1', 'r-2']);
    expect(offer.metadata.providerHotelId).toBe('H1');
    expect(offer.metadata.occupancy).toMatchObject({
      rooms: 2,
      adults: 4,
      children: 0,
      occupancyNumbers: [1, 2],
    });
    // Position travels verbatim; object-shaped address is read.
    expect(offer.metadata.latitude).toBe(30.0444);
    expect(offer.metadata.longitude).toBe(31.2357);
    expect(offer.metadata.address).toBe('12 Nile Street');
    expect(offer.metadata.distanceToCenter).toBeUndefined();
  });

  it('falls back to the sum of rate totals only when every rate is priced', () => {
    const offer = map(
      entry('H1', 'offer-1', 'Twin', [
        rate('r-1', 100),
        rate('r-2', 120),
      ]),
    );

    expect(offer.price).toBe(220);
    expect(offer.currency).toBe('USD');
  });

  it('refuses to invent a price when a rate is unquoted', () => {
    const offer = map(
      entry('H1', 'offer-1', 'Twin', [rate('r-1', 100), rate('r-none')]),
    );
    expect(offer).toBeNull();
  });

  it('refuses a mixed-currency offer with no offerRetailRate', () => {
    const offer = map(
      entry('H1', 'offer-1', 'Twin', [
        rate('r-1', 100, 'USD'),
        rate('r-2', 120, 'EUR'),
      ]),
    );
    expect(offer).toBeNull();
  });

  it('refuses a room type without a booking offerId', () => {
    expect(map(entry('H1', undefined, 'Twin', [rate('r-1', 100)]))).toBeNull();
    expect(map(entry('H1', '   ', 'Twin', [rate('r-1', 100)]))).toBeNull();
  });

  it('is tri-state on refundability: missing tag is null, never false', () => {
    const refundable = map(
      entry('H1', 'offer-1', 'Twin', [
        rate('r-1', 100, 'USD', {
          cancellationPolicies: { refundableTag: 'RFN' },
        }),
      ]),
    );
    const nonRefundable = map(
      entry('H1', 'offer-1', 'Twin', [
        rate('r-1', 100, 'USD', {
          cancellationPolicies: { refundableTag: 'NRFN' },
        }),
      ]),
    );
    const unknown = map(entry('H1', 'offer-1', 'Twin', [rate('r-1', 100)]));

    expect(refundable.metadata.refundable).toBe(true);
    expect(nonRefundable.metadata.refundable).toBe(false);
    expect(unknown.metadata.refundable).toBeNull();
    expect(unknown.metadata.refundableTag).toBeUndefined();
  });

  it('keeps the last cancellation window of the first rate verbatim', () => {
    const offer = map(
      entry('H1', 'offer-1', 'Twin', [
        rate('r-1', 490, 'USD', {
          boardName: 'Room Only',
          boardType: 'RO',
          cancellationPolicies: {
            refundableTag: 'RFN',
            cancelPolicyInfos: [
              {
                cancelTime: '2026-10-12 07:00:00',
                amount: 100,
                currency: 'USD',
                timezone: 'GMT',
              },
              {
                cancelTime: '2026-10-13 07:00:00',
                amount: 623.2,
                currency: 'USD',
                timezone: 'GMT',
              },
            ],
          },
        }),
      ]),
    );

    expect(offer.metadata.boardName).toBe('Room Only');
    expect(offer.metadata.boardType).toBe('RO');
    expect(offer.metadata.cancellationPolicy.refundableUntil).toBe(
      '2026-10-13 07:00:00',
    );
    expect(offer.metadata.cancellationPolicy.feeAmount).toBe(623.2);
    // The per-room rate snapshot is preserved too.
    expect(offer.metadata.rates).toHaveLength(1);
    expect(offer.metadata.rates[0].rateId).toBe('r-1');
  });

  it('reads a string-shaped address and never fabricates missing details', () => {
    const offer = map(entry('H9', 'offer-9', '', [rate('r-9', 100)]), [
      { id: 'H9', address: '5 Tahrir Square' },
    ]);

    expect(offer).not.toBeNull();
    expect(offer.roomType).toBe('');
    expect(offer.title).toBe('');
    expect(offer.rating).toBeUndefined();
    expect(offer.metadata.stars).toBeUndefined();
    expect(offer.metadata.boardName).toBeUndefined();
    expect(offer.metadata.taxesAndFees).toBeUndefined();
    expect(offer.metadata.cancellationPolicy).toBeUndefined();
    expect(offer.metadata.address).toBe('5 Tahrir Square');
    expect(offer.metadata.latitude).toBeUndefined();
    expect(offer.metadata.longitude).toBeUndefined();
    expect(offer.metadata.distanceToCenter).toBeUndefined();
    expect(offer.metadata.refundable).toBeNull();
  });
});

describe('nuitee mapper — one hotel row, all valid offers', () => {
  it('groups by hotel, keeps every offer and puts the cheapest on top', () => {
    const hotels = mapHotelOffers(
      [
        entry('H1', 'offer-dlx', 'Deluxe', [rate('r-dlx', 180)]),
        entry('H1', 'offer-std', 'Standard', [rate('r-std', 120)]),
        entry('H2', 'offer-suite', 'Suite', [rate('r-ste', 90)]),
      ],
      hotelMetaIndex({
        hotels: [
          { id: 'H1', name: 'Cairo Grand' },
          { id: 'H2', name: 'Nile View' },
        ],
      }),
      PARAMS,
      '2026-10-14',
      '2026-10-17',
      IDENTITY,
    );

    expect(hotels).toHaveLength(2);
    const h1 = hotels.find((h) => h.metadata.providerHotelId === 'H1')!;
    expect(h1.id).toBe('offer-std');
    expect(h1.price).toBe(120);
    expect(h1.offers!.map((o) => o.id)).toEqual(['offer-std', 'offer-dlx']);
    expect(h1.offers!.map((o) => o.price)).toEqual([120, 180]);

    const h2 = hotels.find((h) => h.metadata.providerHotelId === 'H2')!;
    expect(h2.id).toBe('offer-suite');
    expect(h2.offers!).toHaveLength(1);
  });

  it('does not multiply the same offerId when a page repeats it', () => {
    const hotels = mapHotelOffers(
      [
        entry('H1', 'offer-std', 'Standard', [rate('r-1', 120)]),
        entry('H1', 'offer-std', 'Standard', [rate('r-1', 120)]),
      ],
      hotelMetaIndex({ hotels: [{ id: 'H1', name: 'Cairo Grand' }] }),
      PARAMS,
      '2026-10-14',
      '2026-10-17',
      IDENTITY,
    );

    expect(hotels).toHaveLength(1);
    expect(hotels[0].offers).toHaveLength(1);
  });

  it('drops invalid offers without dropping the hotel', () => {
    const hotels = mapHotelOffers(
      [
        entry('H1', undefined, 'Broken', [rate('r-1', 50)]),
        entry('H1', 'offer-ok', 'Standard', [rate('r-2', 120)]),
      ],
      hotelMetaIndex({ hotels: [{ id: 'H1', name: 'Cairo Grand' }] }),
      PARAMS,
      '2026-10-14',
      '2026-10-17',
      IDENTITY,
    );

    expect(hotels).toHaveLength(1);
    expect(hotels[0].id).toBe('offer-ok');
    expect(hotels[0].offers).toHaveLength(1);
  });
});
