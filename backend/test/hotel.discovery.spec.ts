import { mapProviderHotel } from '../src/modules/discovery/hotel-metadata.service';
import { HotelDiscoveryService } from '../src/modules/discovery/hotel-discovery.service';
import {
  DEFAULT_PAGE_LIMIT,
  MAX_PAGE_LIMIT,
  clampLimit,
  clampOffset,
} from '../src/common/dto/pagination.dto';

/**
 * Hotel metadata discovery (high-load refactor, Phase 3).
 *
 * Covers the two non-negotiables: Meilisearch is metadata-only and PostgreSQL
 * stays the source of truth; when Meilisearch is unavailable the exact same
 * API answers from PostgreSQL instead of failing.
 */

describe('mapProviderHotel', () => {
  it('maps a live Nuitee content object without inventing fields', () => {
    const mapped = mapProviderHotel(
      {
        id: 'H1',
        name: 'Grand Hotel',
        nameAr: 'فندق جراند',
        city_name: 'Cairo',
        country_code: 'EG',
        address: { addressLine1: '1 Nile Corniche' },
        description: 'Riverside stay',
        facilities: [{ name: 'Pool' }, 'Spa'],
        stars: 5,
        latitude: 30.04,
        longitude: 31.23,
      },
      'nuitee',
    );
    expect(mapped).not.toBeNull();
    expect(mapped!.providerHotelId).toBe('H1');
    expect(mapped!.nameLocal).toBe('فندق جراند');
    expect(mapped!.city).toBe('Cairo');
    expect(mapped!.countryCode).toBe('EG');
    expect(mapped!.address).toBe('1 Nile Corniche');
    expect(mapped!.facilities).toEqual(['Pool', 'Spa']);
    expect(mapped!.category).toBe('5');
  });

  it('falls back to the requested city/country and ignores id-less records', () => {
    const mapped = mapProviderHotel(
      { name: 'Nameless', countryName: 'Egypt' },
      'nuitee',
      'Dubai',
      'AE',
    );
    expect(mapped).toBeNull(); // no stable provider hotel id

    const withId = mapProviderHotel(
      { hotelId: 'H2', name: 'X', countryName: 'Egypt' },
      'nuitee',
      'Cairo',
    );
    expect(withId!.providerHotelId).toBe('H2');
    expect(withId!.city).toBe('Cairo');
    expect(withId!.countryCode).toBe('EG'); // country NAME resolved to ISO code
  });
});

describe('HotelDiscoveryService source selection', () => {
  const hit = { id: 'h1', name: 'Grand', city: 'Cairo', countryCode: 'EG' } as any;

  function make(indexResult: any, pgResult: any) {
    const index = { search: jest.fn(async () => indexResult) };
    const metadata = { search: jest.fn(async () => pgResult) };
    const nuitee = { hotelContent: jest.fn() };
    const service = new HotelDiscoveryService(
      metadata as any,
      index as any,
      nuitee as any,
    );
    return { service, index, metadata };
  }

  const query = { limit: 20, offset: 0 };

  it('answers from Meilisearch when it is available', async () => {
    const { service, metadata } = make(
      { hits: [hit], total: 1 },
      { hits: [], total: 0 },
    );
    const result = await service.discover(query);
    expect(result.source).toBe('meilisearch');
    expect(result.hits).toHaveLength(1);
    expect(result.hits[0].name).toBe('Grand');
    expect(metadata.search).not.toHaveBeenCalled();
  });

  it('falls back to PostgreSQL when Meilisearch is unavailable (null)', async () => {
    const { service, index } = make(null, { hits: [hit], total: 1 });
    const result = await service.discover(query);
    expect(result.source).toBe('postgres');
    expect(result.hits).toHaveLength(1);
    expect(index.search).toHaveBeenCalled();
  });

  it('reports consistent page metadata', async () => {
    const { service } = make({ hits: [], total: 45 }, null);
    const result = await service.discover({ limit: 20, offset: 40 });
    expect(result.limit).toBe(20);
    expect(result.offset).toBe(40);
    expect(result.hasMore).toBe(false);
  });
});

describe('pagination defaults', () => {
  it('defaults to 20 and enforces the maximum page size', () => {
    expect(DEFAULT_PAGE_LIMIT).toBe(20);
    expect(clampLimit(undefined)).toBe(20);
    expect(clampLimit(1)).toBe(1);
    expect(clampLimit(10_000)).toBe(MAX_PAGE_LIMIT);
    expect(clampOffset(-5)).toBe(0);
    expect(clampOffset(40)).toBe(40);
  });
});
