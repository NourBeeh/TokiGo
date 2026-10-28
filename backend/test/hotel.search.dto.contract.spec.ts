import { ValidationPipe } from '@nestjs/common';
import { validate } from 'class-validator';
import { HotelSearchDto } from '../src/common/dto/hotel.search.dto';

/**
 * Phase 3B — Hotel search DTO contract (the P0 fix).
 *
 * 3A shipped the Flutter side sending the rich hotel fields, but the backend
 * HotelSearchDto did not declare them, so the production ValidationPipe
 * (whitelist + forbidNonWhitelisted) rejected every hotel search with a 400.
 * This spec pins the fixed contract with the REAL production pipe settings.
 */
describe('HotelSearchDto — 3A Flutter contract vs backend pipe (3B fix)', () => {
  const pipe = new ValidationPipe({
    whitelist: true,
    forbidNonWhitelisted: true,
    transform: true,
  });

  const base = {
    city: 'Dubai',
    checkIn: new Date('2026-10-01T00:00:00.000Z').toISOString(),
    checkOut: new Date('2026-10-04T00:00:00.000Z').toISOString(),
  };

  it('accepts the exact post-3A body with every extra null (plain search)', async () => {
    const value = await pipe.transform(
      { ...base, guests: 2, rooms: null, minRating: null, maxPrice: null, minPrice: null },
      { type: 'body', metatype: HotelSearchDto, data: '' },
    );
    expect(value).toBeTruthy();
  });

  it('accepts the rich body when a user sets filters (3A rich search)', async () => {
    const value = await pipe.transform(
      {
        ...base,
        guests: 3,
        rooms: 2,
        minRating: 4.0,
        maxPrice: 300,
        minPrice: 100,
        amenities: ['Pool', 'Wifi'],
      },
      { type: 'body', metatype: HotelSearchDto, data: '' },
    );
    expect(value).toBeTruthy();
  });

  it('still rejects unknown fields (whitelist integrity preserved)', async () => {
    await expect(
      pipe.transform(
        { ...base, guests: 2, totallyNewField: 1 },
        { type: 'body', metatype: HotelSearchDto, data: '' },
      ),
    ).rejects.toThrow();
  });

  it('accepts an ISO-2 city country and rejects a country name', async () => {
    const value = await pipe.transform(
      { ...base, city: 'Gudauri', country: 'GE' },
      { type: 'body', metatype: HotelSearchDto, data: '' },
    );
    expect(value.country).toBe('GE');

    await expect(
      pipe.transform(
        { ...base, city: 'Gudauri', country: 'Georgia' },
        { type: 'body', metatype: HotelSearchDto, data: '' },
      ),
    ).rejects.toThrow();
  });

  it('rejects out-of-range values (rooms=0, minRating=9)', async () => {
    const errors = await validate(
      Object.assign(new HotelSearchDto(), { ...base, rooms: 0, minRating: 9 }),
    );
    expect(errors.length).toBeGreaterThan(0);
  });
});
