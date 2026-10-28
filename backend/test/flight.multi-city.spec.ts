// The DTO decorators need the reflect metadata polyfill (the app loads it in
// main.ts; a bare Jest process has to load it itself).
import 'reflect-metadata';
import { validate } from 'class-validator';
import { plainToInstance } from 'class-transformer';
import { FlightSearchDto } from '../src/common/dto/flight.search.dto';

/**
 * Multi-city flight search (owner decision, 2026-10-20).
 *
 * A multi-city itinerary travels as an explicit list of legs; the legacy
 * origin/destination/departure triple stays for one-way and round-trip.
 */
describe('FlightSearchDto — multi-city legs', () => {
  const base = {
    origin: 'CAI',
    destination: 'DXB',
    departure: '2026-11-12',
  };

  it('accepts a one-way search without legs', async () => {
    const dto = plainToInstance(FlightSearchDto, base);
    const errors = await validate(dto);
    expect(errors).toHaveLength(0);
  });

  it('accepts a multi-city itinerary of two or more legs', async () => {
    const dto = plainToInstance(FlightSearchDto, {
      ...base,
      legs: [
        { origin: 'CAI', destination: 'DXB', date: '2026-11-12' },
        { origin: 'DXB', destination: 'FCO', date: '2026-11-19' },
      ],
    });
    const errors = await validate(dto);
    expect(errors).toHaveLength(0);
    expect(dto.legs).toHaveLength(2);
    expect(dto.legs![1].destination).toBe('FCO');
  });

  it('rejects a single leg — a multi-city trip is at least two hops', async () => {
    const dto = plainToInstance(FlightSearchDto, {
      ...base,
      legs: [{ origin: 'CAI', destination: 'DXB', date: '2026-11-12' }],
    });
    const errors = await validate(dto);
    expect(errors.length).toBeGreaterThan(0);
  });

  it('rejects more than six legs (the provider limit)', async () => {
    const dto = plainToInstance(FlightSearchDto, {
      ...base,
      legs: Array.from({ length: 7 }, (_, i) => ({
        origin: 'CAI',
        destination: 'DXB',
        date: '2026-11-12',
      })),
    });
    const errors = await validate(dto);
    expect(errors.length).toBeGreaterThan(0);
  });

  it('rejects a leg with a missing endpoint', async () => {
    const dto = plainToInstance(FlightSearchDto, {
      ...base,
      legs: [
        { origin: 'CAI', destination: 'DXB', date: '2026-11-12' },
        { origin: 'DXB', date: '2026-11-19' },
      ],
    });
    const errors = await validate(dto);
    expect(errors.length).toBeGreaterThan(0);
  });
});
