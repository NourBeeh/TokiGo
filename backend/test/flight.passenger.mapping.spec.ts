// The DTO decorators need the reflect metadata polyfill (the app loads it in
// main.ts; a bare Jest process has to load it itself).
import 'reflect-metadata';
import { validate } from 'class-validator';
import { plainToInstance } from 'class-transformer';

import { FlightSearchDto } from '../src/common/dto/flight.search.dto';
import {
  buildDuffelPassengerEntries,
  DuffelService,
} from '../src/modules/duffel/duffel.service';
import { DuffelBookingProvider } from '../src/modules/bookings/adapters/duffel-booking.provider';

/**
 * P3 — flight passenger flow.
 *
 * The offer request must carry the real passenger TYPES (adult / child /
 * infant_without_seat) with exact ages. An adult-only array silently drops
 * child/infant pricing; an invented age would be fake data. Revalidation uses
 * the stored offer id, so the composition is preserved by construction.
 */
describe('FlightSearchDto — passenger party', () => {
  const base = {
    origin: 'CAI',
    destination: 'DXB',
    departure: '2026-11-12',
  };

  it('accepts adults, children, infants and their ages', async () => {
    const dto = plainToInstance(FlightSearchDto, {
      ...base,
      passengers: 2,
      children: 1,
      infants: 1,
      childAges: [7],
      infantAges: [1],
    });
    const errors = await validate(dto);
    expect(errors).toHaveLength(0);
    expect(dto.passengers).toBe(2);
    expect(dto.children).toBe(1);
    expect(dto.infants).toBe(1);
    expect(dto.childAges).toEqual([7]);
    expect(dto.infantAges).toEqual([1]);
  });

  it('rejects a non-integer child age', async () => {
    const dto = plainToInstance(FlightSearchDto, {
      ...base,
      children: 1,
      childAges: [7.5],
    });
    const errors = await validate(dto);
    expect(errors.length).toBeGreaterThan(0);
  });

  it('rejects a non-integer infant age', async () => {
    const dto = plainToInstance(FlightSearchDto, {
      ...base,
      infants: 1,
      infantAges: ['1'],
    });
    const errors = await validate(dto);
    expect(errors.length).toBeGreaterThan(0);
  });

  it('rejects a negative child count', async () => {
    const dto = plainToInstance(FlightSearchDto, { ...base, children: -1 });
    const errors = await validate(dto);
    expect(errors.length).toBeGreaterThan(0);
  });

  it('keeps the passenger fields out of the provider payload when absent', async () => {
    const dto = plainToInstance(FlightSearchDto, { ...base, passengers: 1 });
    const errors = await validate(dto);
    expect(errors).toHaveLength(0);
    expect(dto.children).toBeUndefined();
    expect(dto.childAges).toBeUndefined();
  });
});

describe('Duffel offer-request passenger mapping', () => {
  it('maps 2 adults, 1 child (7) and 1 infant (1) to typed entries', () => {
    expect(
      buildDuffelPassengerEntries({
        adults: 2,
        children: 1,
        infants: 1,
        childAges: [7],
        infantAges: [1],
      }),
    ).toEqual([
      { type: 'adult' },
      { type: 'adult' },
      { type: 'child', age: 7 },
      { type: 'infant_without_seat', age: 1 },
    ]);
  });

  it('keeps the type when an age is missing rather than inventing one', () => {
    expect(
      buildDuffelPassengerEntries({ adults: 1, children: 1, infants: 1 }),
    ).toEqual([
      { type: 'adult' },
      { type: 'child' },
      { type: 'infant_without_seat' },
    ]);
  });

  it('uses passengers as the adult-count fallback', () => {
    expect(buildDuffelPassengerEntries({ passengers: 3 })).toEqual([
      { type: 'adult' },
      { type: 'adult' },
      { type: 'adult' },
    ]);
  });

  it('never converts a child or infant into an adult', () => {
    const entries = buildDuffelPassengerEntries({
      adults: 1,
      children: 2,
      infants: 1,
      childAges: [5, 8],
      infantAges: [0],
    });
    expect(entries.filter((entry) => entry.type === 'adult')).toHaveLength(1);
    expect(entries.filter((entry) => entry.type === 'child')).toHaveLength(2);
    expect(
      entries.filter((entry) => entry.type === 'infant_without_seat'),
    ).toHaveLength(1);
  });

  it('preserves ordering: adults, then children, then infants', () => {
    const entries = buildDuffelPassengerEntries({
      adults: 2,
      children: 2,
      infants: 1,
      childAges: [5, 8],
      infantAges: [0],
    });
    expect(entries.map((entry) => entry.type)).toEqual([
      'adult',
      'adult',
      'child',
      'child',
      'infant_without_seat',
    ]);
    expect(entries.map((entry) => entry.age)).toEqual([
      undefined,
      undefined,
      5,
      8,
      0,
    ]);
  });
});

describe('Duffel revalidation contract', () => {
  it('revalidates by stored offer id and does not re-send passengers', async () => {
    const calls: string[] = [];
    const fakeDuffel = {
      providerName: 'Duffel Flight Provider',
      revalidateOffer: async (offerId: string) => {
        calls.push(offerId);
        return {
          success: true,
          providerId: 'duffel-flight',
          providerName: 'Duffel Flight Provider',
          data: { price: 800, currency: 'USD', available: true },
          timestamp: new Date(),
        };
      },
    } as unknown as DuffelService;

    const provider = new DuffelBookingProvider(fakeDuffel);
    const result = await provider.revalidateBooking('off_123');

    expect(calls).toEqual(['off_123']);
    expect(result.success).toBe(true);
    expect(result.data?.price).toBe(800);
    expect(result.data?.currency).toBe('USD');
  });
});
