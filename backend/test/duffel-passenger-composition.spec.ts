// The DTO decorators need the reflect metadata polyfill (the app loads it in
// main.ts; a bare Jest process has to load it itself).
import 'reflect-metadata';

import { DuffelService } from '../src/modules/duffel/duffel.service';
import { DuffelBookingProvider } from '../src/modules/bookings/adapters/duffel-booking.provider';

/**
 * P3-D6 — the (type, ordinal) mapping under REAL multi-party compositions.
 *
 * A single adult + single infant proves little: ordinal 0 is the only value
 * ever exercised, so an off-by-one or a cross-type mix-up is invisible. These
 * tests use repeated passenger types and a traveller order that does NOT match
 * the offer order, which is the only way to prove the mapping is positional
 * within the type rather than an accidental array alignment.
 */
class FakeDuffelService {
  providerName = 'Duffel Flight Provider';

  createOrderCalls: Array<{
    offerId: string;
    passengers: Array<Record<string, unknown>>;
    payments: Array<Record<string, unknown>>;
  }> = [];

  async createOrder(
    offerId: string,
    passengers: Array<Record<string, unknown>>,
    payments: Array<Record<string, unknown>>,
  ): Promise<Record<string, unknown>> {
    this.createOrderCalls.push({ offerId, passengers, payments });
    return {
      id: 'ord_1',
      booking_reference: 'ABC123',
      status: 'confirmed',
      total_amount: '800.00',
      total_currency: 'USD',
    };
  }
}

function traveler(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    passengerType: 'adult',
    firstName: 'Nour',
    lastName: 'Adel',
    dateOfBirth: '1990-01-01',
    gender: 'M',
    title: 'mr',
    email: 'nour@example.com',
    phone: '+201****0000',
    documentType: 'passport',
    documentNumber: 'P123456',
    documentIssueCountry: 'EG',
    documentExpiry: '2030-01-01',
    ...overrides,
  };
}

function snapshot(passengers: Array<Record<string, unknown>>): Record<string, unknown> {
  return {
    offerId: 'off_1',
    duffelPassengers: passengers,
    duffelIdentityDocumentsRequired: false,
    duffelSupportedDocumentTypes: ['passport'],
  };
}

const MIXED_OFFER = [
  { id: 'pas_a1', type: 'adult', age: null },
  { id: 'pas_c1', type: 'child', age: 8 },
  { id: 'pas_i1', type: 'infant_without_seat', age: 1 },
  { id: 'pas_a2', type: 'adult', age: null },
  { id: 'pas_c2', type: 'child', age: 5 },
  { id: 'pas_i2', type: 'infant_without_seat', age: 0 },
];

describe('Duffel createBooking — mixed multi-party composition', () => {
  it('maps every traveller to the correct offer id regardless of order', async () => {
    const fake = new FakeDuffelService();
    const provider = new DuffelBookingProvider(
      fake as unknown as DuffelService,
    );

    // Deliberately NOT in offer order: infant, adult, child, adult, child,
    // infant. Ordinal-within-type must still resolve correctly.
    const result = await provider.createBooking({
      offerId: 'off_1',
      offerSnapshot: snapshot(MIXED_OFFER),
      travelers: [
        traveler({
          firstName: 'Inf1',
          passengerType: 'infant',
          accompanyingAdultIndex: 3,
        }),
        traveler({ firstName: 'Adult1', passengerType: 'adult' }),
        traveler({ firstName: 'Child1', passengerType: 'child' }),
        traveler({ firstName: 'Adult2', passengerType: 'adult' }),
        traveler({ firstName: 'Child2', passengerType: 'child' }),
        traveler({
          firstName: 'Inf2',
          passengerType: 'infant',
          accompanyingAdultIndex: 1,
        }),
      ],
    });

    expect(result.success).toBe(true);
    expect(fake.createOrderCalls).toHaveLength(1);
    const sent = fake.createOrderCalls[0].passengers;

    const ids = sent.map((p) => p.id);
    // No id is invented: every value came from the offer's own passenger set.
    expect(new Set(ids)).toEqual(
      new Set(['pas_a1', 'pas_c1', 'pas_i1', 'pas_a2', 'pas_c2', 'pas_i2']),
    );
    expect(ids).toEqual([
      'pas_i1',
      'pas_a1',
      'pas_c1',
      'pas_a2',
      'pas_c2',
      'pas_i2',
    ]);

    // The infant links live on the ADULT, referencing the infant's own id.
    expect(sent[3].infant_passenger_id).toBe('pas_i1');
    expect(sent[1].infant_passenger_id).toBe('pas_i2');
    expect(sent[0].infant_passenger_id).toBeUndefined();
    expect(sent[5].infant_passenger_id).toBeUndefined();
  });

  it('maps three adults to three distinct ids', async () => {
    const fake = new FakeDuffelService();
    const provider = new DuffelBookingProvider(
      fake as unknown as DuffelService,
    );

    const result = await provider.createBooking({
      offerId: 'off_1',
      offerSnapshot: snapshot([
        { id: 'pas_a1', type: 'adult', age: null },
        { id: 'pas_a2', type: 'adult', age: null },
        { id: 'pas_a3', type: 'adult', age: null },
      ]),
      travelers: [
        traveler({ firstName: 'A1', passengerType: 'adult' }),
        traveler({ firstName: 'A2', passengerType: 'adult' }),
        traveler({ firstName: 'A3', passengerType: 'adult' }),
      ],
    });

    expect(result.success).toBe(true);
    const sent = fake.createOrderCalls[0].passengers;
    expect(sent.map((p) => p.id)).toEqual(['pas_a1', 'pas_a2', 'pas_a3']);
    expect(sent.map((p) => p.given_name)).toEqual(['A1', 'A2', 'A3']);
  });

  it('maps two children to two distinct ids', async () => {
    const fake = new FakeDuffelService();
    const provider = new DuffelBookingProvider(
      fake as unknown as DuffelService,
    );

    const result = await provider.createBooking({
      offerId: 'off_1',
      offerSnapshot: snapshot([
        { id: 'pas_c1', type: 'child', age: 8 },
        { id: 'pas_c2', type: 'child', age: 5 },
      ]),
      travelers: [
        traveler({ firstName: 'C1', passengerType: 'child' }),
        traveler({ firstName: 'C2', passengerType: 'child' }),
      ],
    });

    expect(result.success).toBe(true);
    const sent = fake.createOrderCalls[0].passengers;
    expect(sent.map((p) => p.id)).toEqual(['pas_c1', 'pas_c2']);
    expect(sent.map((p) => p.given_name)).toEqual(['C1', 'C2']);
  });

  it('blocks two infants linked to the same adult', async () => {
    const fake = new FakeDuffelService();
    const provider = new DuffelBookingProvider(
      fake as unknown as DuffelService,
    );

    const result = await provider.createBooking({
      offerId: 'off_1',
      offerSnapshot: snapshot(MIXED_OFFER),
      travelers: [
        traveler({ firstName: 'Adult1', passengerType: 'adult' }),
        traveler({ firstName: 'Child1', passengerType: 'child' }),
        traveler({
          firstName: 'Inf1',
          passengerType: 'infant',
          accompanyingAdultIndex: 0,
        }),
        traveler({ firstName: 'Adult2', passengerType: 'adult' }),
        traveler({ firstName: 'Child2', passengerType: 'child' }),
        traveler({
          firstName: 'Inf2',
          passengerType: 'infant',
          accompanyingAdultIndex: 0,
        }),
      ],
    });

    expect(result.success).toBe(false);
    expect(result.error).toContain('already has an infant');
    expect(fake.createOrderCalls).toHaveLength(0);
  });

  it('blocks an infant whose named adult is a child', async () => {
    const fake = new FakeDuffelService();
    const provider = new DuffelBookingProvider(
      fake as unknown as DuffelService,
    );

    const result = await provider.createBooking({
      offerId: 'off_1',
      offerSnapshot: snapshot(MIXED_OFFER),
      travelers: [
        traveler({ firstName: 'Adult1', passengerType: 'adult' }),
        traveler({ firstName: 'Child1', passengerType: 'child' }),
        traveler({
          firstName: 'Inf1',
          passengerType: 'infant',
          accompanyingAdultIndex: 1,
        }),
        traveler({ firstName: 'Adult2', passengerType: 'adult' }),
        traveler({ firstName: 'Child2', passengerType: 'child' }),
        traveler({
          firstName: 'Inf2',
          passengerType: 'infant',
          accompanyingAdultIndex: 3,
        }),
      ],
    });

    expect(result.success).toBe(false);
    expect(result.error).toContain('infant_passenger_id');
    expect(fake.createOrderCalls).toHaveLength(0);
  });

  it('blocks when the offer has a passenger the traveller party never claims', async () => {
    const fake = new FakeDuffelService();
    const provider = new DuffelBookingProvider(
      fake as unknown as DuffelService,
    );

    const result = await provider.createBooking({
      offerId: 'off_1',
      offerSnapshot: snapshot(MIXED_OFFER),
      travelers: [
        traveler({ firstName: 'Adult1', passengerType: 'adult' }),
      ],
    });

    expect(result.success).toBe(false);
    expect(result.error).toContain('6 passengers but 1 were supplied');
    expect(fake.createOrderCalls).toHaveLength(0);
  });
});
