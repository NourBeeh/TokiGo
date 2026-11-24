import 'reflect-metadata';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { NearbyStaysQueryDto } from '../src/common/dto/nearby-stays.dto';
import { NearbyStaysController } from '../src/modules/nearby/nearby-stays.controller';
import { NEARBY_RANKING_VERSION } from '../src/modules/nearby/promotional-stay.model';

/**
 * GET /home/nearby-stays contract (R4).
 *
 * The endpoint is public and read-only, validates its geographic parameters,
 * and never falls back to a nationwide list when the center is missing.
 */
describe('Nearby Stays API contract', () => {
  async function validateDto(raw: Record<string, unknown>) {
    const dto = plainToInstance(NearbyStaysQueryDto, raw);
    return validate(dto);
  }

  it('registers the dedicated path home/nearby-stays', () => {
    const path = Reflect.getMetadata('path', NearbyStaysController);
    expect(path).toBe('home/nearby-stays');
  });

  it('accepts a GPS center with optional accuracy', async () => {
    const errors = await validateDto({ lat: '30.0444', lng: '31.2357', accuracy: '2500' });
    expect(errors).toEqual([]);
  });

  it('accepts a user-selected city and country', async () => {
    const errors = await validateDto({ city: 'Cairo', country: 'eg', limit: '12' });
    expect(errors).toEqual([]);
  });

  it('rejects coordinates outside the real range', async () => {
    expect(await validateDto({ lat: '200', lng: '31' })).not.toEqual([]);
    expect(await validateDto({ lat: '30', lng: '400' })).not.toEqual([]);
  });

  it('rejects an invalid currency, occupancy, limit and date', async () => {
    expect(await validateDto({ currency: 'US' })).not.toEqual([]);
    expect(await validateDto({ adults: '0' })).not.toEqual([]);
    expect(await validateDto({ rooms: '9' })).not.toEqual([]);
    expect(await validateDto({ limit: '0' })).not.toEqual([]);
    expect(await validateDto({ fromDate: 'not-a-date' })).not.toEqual([]);
  });

  it('carries a ranking version for the cache identity', () => {
    expect(NEARBY_RANKING_VERSION).toMatch(/^nearby-ranking-v/);
  });
});
