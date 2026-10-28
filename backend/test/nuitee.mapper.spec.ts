import {
  cheapestPerHotel,
  dateStr,
  extractRateResults,
  firstAmount,
  hotelMetaIndex,
  mapRateToOffer,
  numberOrUndefined,
} from '../src/modules/nuitee/nuitee.mapper';

/**
 * Pure-mapper contracts (Stage-1 refactor of the Nuitee adapter).
 *
 * Before the split these rules were only reachable through searchHotels, so a
 * mapping bug could only be caught end-to-end. They are pinned here directly:
 * - live vs fixture payload shapes;
 * - one entry per room type, at that room type's cheapest rate;
 * - one offer per hotel, at the hotel's cheapest room;
 * - no quoted amount / no rateId → NO offer (a 0 price would be invented money);
 * - provider fields are carried verbatim (absent stays absent).
 */

const IDENTITY = { providerId: 'nuitee', providerName: 'Nuitee Connect' };

function rate(rateId: string, amount?: number, currency = 'USD') {
  return {
    rateId,
    retailRate: { total: amount === undefined ? [] : [{ amount, currency }] },
  };
}

function entry(hotelId: string, roomType: string, r: any) {
  return { hotelId, offerId: `offer-${hotelId}`, roomType, rate: r };
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
  it('reads the live shape (data[] + roomTypes) and keeps the cheapest rate per room type', () => {
    const entries = extractRateResults({
      data: [
        {
          hotelId: 'H1',
          roomTypes: [
            {
              offerId: 'offer-H1',
              roomTypeName: 'Standard',
              rates: [rate('r-exp', 200), rate('r-cheap', 100)],
            },
          ],
        },
      ],
    });

    expect(entries).toHaveLength(1);
    expect(entries[0].rate.rateId).toBe('r-cheap');
    expect(entries[0].roomType).toBe('Standard');
    expect(entries[0].offerId).toBe('offer-H1');
  });

  it('reads the nested fixture shape and skips room types without a rateId', () => {
    const entries = extractRateResults({
      data: {
        data: [
          {
            hotelId: 'H2',
            roomTypes: [
              { roomTypeName: 'Suite', rates: [{ retailRate: { total: [{ amount: 90 }] } }] },
              { roomTypeName: 'Twin', rates: [rate('r-twin', 150)] },
            ],
          },
        ],
      },
    });

    expect(entries).toHaveLength(1);
    expect(entries[0].roomType).toBe('Twin');
  });

  it('answers [] for a payload with no rates at all', () => {
    expect(extractRateResults({ data: [] })).toEqual([]);
    expect(extractRateResults({})).toEqual([]);
    expect(extractRateResults(null)).toEqual([]);
  });

  it('indexes hotels from both the live and the fixture location', () => {
    expect([...hotelMetaIndex({ hotels: [{ id: 'H1' }] }).keys()]).toEqual(['H1']);
    expect(
      [...hotelMetaIndex({ data: { hotels: [{ hotelId: 'H2' }] } }).keys()],
    ).toEqual(['H2']);
  });
});

describe('nuitee mapper — one offer per hotel', () => {
  it('keeps the cheapest room and drops the pricier duplicate', () => {
    const cheapest = cheapestPerHotel([
      entry('H1', 'Deluxe', rate('r-dlx', 180)),
      entry('H1', 'Standard', rate('r-std', 120)),
      entry('H2', 'Suite', rate('r-ste', 90)),
    ]);

    expect(cheapest.size).toBe(2);
    expect(cheapest.get('H1')!.entry.rate.rateId).toBe('r-std');
    expect(cheapest.get('H2')!.entry.rate.rateId).toBe('r-ste');
  });

  it('prices a rate with no quoted amount as "unknown" (never 0)', () => {
    const cheapest = cheapestPerHotel([
      entry('H1', 'Standard', rate('r-none')),
      entry('H1', 'Deluxe', rate('r-paid', 150)),
    ]);

    // The quoted room wins over the unpriced one.
    expect(cheapest.get('H1')!.entry.rate.rateId).toBe('r-paid');
  });
});

describe('nuitee mapper — offer shape', () => {
  const params = {
    city: 'Cairo',
    checkIn: new Date('2026-10-14'),
    checkOut: new Date('2026-10-17'),
  };

  it('maps a full rate verbatim, with provenance metadata', () => {
    const meta = hotelMetaIndex({
      hotels: [
        {
          id: 'H1',
          name: 'Cairo Grand',
          stars: 5,
          rating: 9.6,
          city_name: 'Cairo',
          main_photo: 'https://x/h1.jpg',
          review_count: 1200,
        },
      ],
    });
    const offer = mapRateToOffer(
      entry('H1', 'Twin', {
        ...rate('r-1', 490),
        boardName: 'Room Only',
        boardType: 'RO',
        cancellationPolicies: {
          refundableTag: 'RFN',
          cancelPolicyInfos: [
            { cancelTime: '2026-10-12 07:00:00', amount: 100, currency: 'USD', timezone: 'GMT' },
            { cancelTime: '2026-10-13 07:00:00', amount: 623.2, currency: 'USD', timezone: 'GMT' },
          ],
        },
      }),
      meta,
      params,
      '2026-10-14',
      '2026-10-17',
      IDENTITY,
    );

    expect(offer).not.toBeNull();
    expect(offer!.id).toBe('r-1');
    expect(offer!.price).toBe(490);
    expect(offer!.currency).toBe('USD');
    // 9.6 / 10 → 4.8 on the 5-star display scale.
    expect(offer!.rating).toBe(4.8);
    expect(offer!.title).toBe('Cairo Grand');
    expect(offer!.checkIn).toBe('2026-10-14');
    expect(offer!.metadata.providerRateId).toBe('r-1');
    expect(offer!.metadata.providerHotelId).toBe('H1');
    expect(offer!.metadata.refundable).toBe(true);
    // LAST cancellation window, verbatim.
    expect(offer!.metadata.cancellationPolicy.refundableUntil).toBe(
      '2026-10-13 07:00:00',
    );
  });

  it('refuses to invent a price when the rate carries no quoted amount', () => {
    const offer = mapRateToOffer(
      entry('H1', 'Standard', rate('r-none')),
      hotelMetaIndex({}),
      params,
      '2026-10-14',
      '2026-10-17',
      IDENTITY,
    );
    expect(offer).toBeNull();
  });

  it('does not invent detail fields the provider omitted', () => {
    const offer = mapRateToOffer(
      entry('H9', '', rate('r-9', 100)),
      hotelMetaIndex({ hotels: [{ id: 'H9' }] }),
      params,
      '2026-10-14',
      '2026-10-17',
      IDENTITY,
    );

    expect(offer).not.toBeNull();
    expect(offer!.roomType).toBe('');
    expect(offer!.rating).toBeUndefined();
    expect(offer!.metadata.stars).toBeUndefined();
    expect(offer!.metadata.boardName).toBeUndefined();
    expect(offer!.metadata.taxesAndFees).toBeUndefined();
    expect(offer!.metadata.cancellationPolicy).toBeUndefined();
    expect(offer!.metadata.refundable).toBe(false);
  });
});
