import { canonicalSearchCacheKey } from '../src/modules/providers/search.service';
import {
  allTargets,
  weekendWindow,
} from '../src/modules/providers/search.warmup';

/**
 * Cache-key stability (2026-10-28).
 *
 * The key used to be `JSON.stringify(params)`, so the same search produced
 * different entries depending on field order, city casing or whether the
 * client sent a date or a date-time. That made every pre-warmed entry useless
 * for real traffic — the warmer paid for a provider call nobody ever hit.
 */
describe('canonicalSearchCacheKey', () => {
  const base = {
    city: 'Cairo',
    country: 'EG',
    checkIn: '2026-11-10',
    checkOut: '2026-11-13',
    guests: 2,
    rooms: 1,
    market: 'EG',
  };

  it('keeps the `search:<vertical>:` prefix invalidation relies on', () => {
    expect(canonicalSearchCacheKey('hotel', base, 'EG')).toMatch(
      /^search:hotel:/,
    );
  });

  it('ignores the order of the params object', () => {
    const reordered = {
      market: 'EG',
      rooms: 1,
      guests: 2,
      checkOut: '2026-11-13',
      checkIn: '2026-11-10',
      country: 'EG',
      city: 'Cairo',
    };
    expect(canonicalSearchCacheKey('hotel', reordered, 'EG')).toBe(
      canonicalSearchCacheKey('hotel', base, 'EG'),
    );
  });

  it('treats city casing and stray whitespace as the same search', () => {
    const messy = { ...base, city: '  cAIro  ' };
    expect(canonicalSearchCacheKey('hotel', messy, 'EG')).toBe(
      canonicalSearchCacheKey('hotel', base, 'EG'),
    );
  });

  it('collapses a date-time onto its day', () => {
    const isoDateTime = {
      ...base,
      checkIn: '2026-11-10T00:00:00.000Z',
      checkOut: '2026-11-13T00:00:00.000Z',
    };
    expect(canonicalSearchCacheKey('hotel', isoDateTime, 'EG')).toBe(
      canonicalSearchCacheKey('hotel', base, 'EG'),
    );
  });

  it('ignores null and undefined optional fields', () => {
    const sparse = {
      ...base,
      minPrice: null,
      maxPrice: undefined,
      amenities: null,
    };
    expect(canonicalSearchCacheKey('hotel', sparse, 'EG')).toBe(
      canonicalSearchCacheKey('hotel', base, 'EG'),
    );
  });

  it('treats filter arrays as sets', () => {
    const a = { ...base, amenities: ['Pool', 'Spa'] };
    const b = { ...base, amenities: ['spa ', 'POOL'] };
    expect(canonicalSearchCacheKey('hotel', a, 'EG')).toBe(
      canonicalSearchCacheKey('hotel', b, 'EG'),
    );
  });

  it('matches the app body against the warmer body', () => {
    // What HotelRepositoryImpl actually sends: nulls included, no country and
    // no market when the caller did not set them.
    const appBody = {
      city: 'Cairo',
      checkIn: '2026-11-10T00:00:00.000',
      checkOut: '2026-11-13T00:00:00.000',
      guests: 2,
      rooms: null,
      minRating: null,
      maxPrice: null,
      minPrice: null,
    };
    // What SearchWarmupService sends.
    const warmerBody = {
      city: 'Cairo',
      country: 'EG',
      checkIn: '2026-11-10',
      checkOut: '2026-11-13',
      guests: 2,
      rooms: 1,
      market: 'EG',
    };
    expect(canonicalSearchCacheKey('hotel', appBody, 'EG')).toBe(
      canonicalSearchCacheKey('hotel', warmerBody, 'EG'),
    );
  });

  it('defaults guests/rooms/country to what the provider would use', () => {
    const minimal = { city: 'Cairo', checkIn: '2026-11-10', checkOut: '2026-11-13' };
    const explicit = {
      city: 'Cairo',
      country: 'EG',
      checkIn: '2026-11-10',
      checkOut: '2026-11-13',
      guests: 2,
      rooms: 1,
    };
    expect(canonicalSearchCacheKey('hotel', minimal, 'EG')).toBe(
      canonicalSearchCacheKey('hotel', explicit, 'EG'),
    );
  });

  it('still separates genuinely different searches', () => {
    const otherDates = { ...base, checkIn: '2026-12-10', checkOut: '2026-12-13' };
    expect(canonicalSearchCacheKey('hotel', otherDates, 'EG')).not.toBe(
      canonicalSearchCacheKey('hotel', base, 'EG'),
    );
    expect(canonicalSearchCacheKey('hotel', base, 'AE')).not.toBe(
      canonicalSearchCacheKey('hotel', base, 'EG'),
    );
    expect(canonicalSearchCacheKey('flight', base, 'EG')).not.toBe(
      canonicalSearchCacheKey('hotel', base, 'EG'),
    );
  });
});

describe('search warmup windows', () => {
  it('targets the upcoming Friday → Sunday', () => {
    // Wednesday 2026-10-28 → Friday 2026-10-30, Sunday 2026-11-01.
    expect(weekendWindow(0, new Date('2026-10-28T12:00:00Z'))).toEqual({
      checkIn: '2026-10-30',
      checkOut: '2026-11-01',
    });
  });

  it('never warms today when today is already Friday', () => {
    // Friday 2026-10-30 → the FOLLOWING Friday.
    expect(weekendWindow(0, new Date('2026-10-30T09:00:00Z'))).toEqual({
      checkIn: '2026-11-06',
      checkOut: '2026-11-08',
    });
  });

  it('advances a whole week per step', () => {
    expect(weekendWindow(1, new Date('2026-10-28T12:00:00Z'))).toEqual({
      checkIn: '2026-11-06',
      checkOut: '2026-11-08',
    });
  });

  it('only targets cities in known markets, with a country each', () => {
    const previous = process.env.SEARCH_WARM_MARKETS;
    process.env.SEARCH_WARM_MARKETS = 'EG,GB';
    try {
      const targets = allTargets(new Date('2026-10-28T12:00:00Z'));
      expect(targets.length).toBeGreaterThan(0);
      expect(targets.every((t) => ['EG', 'GB'].includes(t.country))).toBe(true);
      expect(targets.every((t) => t.city.length > 0)).toBe(true);
      expect(targets.some((t) => t.city === 'Cairo')).toBe(true);
      expect(targets.some((t) => t.city === 'London')).toBe(true);
    } finally {
      if (previous === undefined) delete process.env.SEARCH_WARM_MARKETS;
      else process.env.SEARCH_WARM_MARKETS = previous;
    }
  });
});
