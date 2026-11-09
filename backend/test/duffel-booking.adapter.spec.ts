// The DTO decorators need the reflect metadata polyfill (the app loads it in
// main.ts; a bare Jest process has to load it itself).
import 'reflect-metadata';

import { DuffelService } from '../src/modules/duffel/duffel.service';
import { DuffelBookingProvider } from '../src/modules/bookings/adapters/duffel-booking.provider';

/**
 * P3-D4 — the final Duffel provider boundary.
 *
 * These tests inspect the ACTUAL object handed to `DuffelService.createOrder`
 * (the SDK boundary), not a standalone mapping helper. Duffel's
 * `CreateOrderPassenger` requires `id`, `given_name`, `family_name`,
 * `gender`, `title`, `born_on`, `email` and `phone_number` for every
 * passenger, and the adapter must never leak the internal
 * `firstName`/`lastName`/`dateOfBirth` names or invent a missing value.
 */
class FakeDuffelService {
  providerName = 'Duffel Flight Provider';

  createOrderCalls: Array<{
    offerId: string;
    passengers: Array<Record<string, unknown>>;
    payments: Array<Record<string, unknown>>;
  }> = [];

  createOrderResult: Record<string, unknown> = {
    id: 'ord_1',
    booking_reference: 'ABC123',
    status: 'confirmed',
    total_amount: '800.00',
    total_currency: 'USD',
  };

  createOrderError: Error | null = null;

  async createOrder(
    offerId: string,
    passengers: Array<Record<string, unknown>>,
    payments: Array<Record<string, unknown>>,
  ): Promise<Record<string, unknown>> {
    this.createOrderCalls.push({ offerId, passengers, payments });
    if (this.createOrderError) throw this.createOrderError;
    return this.createOrderResult;
  }
}

/** A traveller that satisfies Duffel's full required set. */
function completeTraveler(
  overrides: Record<string, unknown> = {},
): Record<string, unknown> {
  return {
    passengerType: 'adult',
    firstName: 'Nour',
    lastName: 'Adel',
    dateOfBirth: '1990-01-01',
    gender: 'M',
    title: 'mr',
    email: 'nour@example.com',
    phone: '+201000000000',
    documentType: 'PASSPORT',
    documentNumber: 'P123456',
    documentIssueCountry: 'EG',
    documentExpiry: '2030-01-01',
    ...overrides,
  };
}

/** The offer passengers captured from the stored Duffel offer. */
const OFFER_PASSENGERS = [{ id: 'pas_1', type: 'adult', age: null }];

const TWO_ADULTS = [
  { id: 'pas_1', type: 'adult', age: null },
  { id: 'pas_2', type: 'adult', age: null },
];

function offerSnapshot(
  overrides: Record<string, unknown> = {},
): Record<string, unknown> {
  return {
    offerId: 'off_1',
    duffelPassengers: OFFER_PASSENGERS,
    duffelIdentityDocumentsRequired: false,
    duffelSupportedDocumentTypes: ['passport'],
    ...overrides,
  };
}

describe('Duffel booking adapter — passenger mapping', () => {
  it('maps the collected fields to Duffel property names', async () => {
    const fake = new FakeDuffelService();
    const provider = new DuffelBookingProvider(fake as unknown as DuffelService);

    const result = await provider.createBooking({
      offerId: 'off_1',
      offerSnapshot: offerSnapshot(),
      travelers: [completeTraveler()],
    });

    expect(result.success).toBe(true);
    expect(fake.createOrderCalls).toHaveLength(1);
    const { offerId, passengers, payments } = fake.createOrderCalls[0];
    expect(offerId).toBe('off_1');
    expect(payments).toEqual([]);
    expect(passengers).toEqual([
      {
        id: 'pas_1',
        given_name: 'Nour',
        family_name: 'Adel',
        born_on: '1990-01-01',
        gender: 'm',
        title: 'mr',
        email: 'nour@example.com',
        phone_number: '+201000000000',
        identity_documents: [
          {
            type: 'passport',
            unique_identifier: 'P123456',
            issuing_country_code: 'EG',
            expires_on: '2030-01-01',
          },
        ],
      },
    ]);
  });

  it('never leaks internal TokiGo property names into the Duffel payload', async () => {
    const fake = new FakeDuffelService();
    const provider = new DuffelBookingProvider(fake as unknown as DuffelService);

    await provider.createBooking({
      offerId: 'off_1',
      offerSnapshot: offerSnapshot(),
      travelers: [completeTraveler()],
    });

    const passenger = fake.createOrderCalls[0].passengers[0];
    for (const internalName of [
      'firstName',
      'lastName',
      'dateOfBirth',
      'birthday',
      'phone',
      'documentType',
      'documentNumber',
      'documentIssueCountry',
      'documentExpiry',
      'passengerId',
    ]) {
      expect(passenger).not.toHaveProperty(internalName);
    }
  });

  it('preserves passenger ordering', async () => {
    const fake = new FakeDuffelService();
    const provider = new DuffelBookingProvider(fake as unknown as DuffelService);

    await provider.createBooking({
      offerId: 'off_1',
      offerSnapshot: offerSnapshot({
        duffelPassengers: [
          { id: 'pas_1', type: 'adult', age: null },
          { id: 'pas_2', type: 'adult', age: null },
          { id: 'pas_3', type: 'adult', age: null },
        ],
      }),
      travelers: [
        completeTraveler({ firstName: 'Nour' }),
        completeTraveler({ firstName: 'Mona', gender: 'F' }),
        completeTraveler({ firstName: 'Youssef' }),
      ],
    });

    const passengers = fake.createOrderCalls[0].passengers;
    expect(passengers.map((entry) => entry.id)).toEqual([
      'pas_1',
      'pas_2',
      'pas_3',
    ]);
    expect(passengers.map((entry) => entry.given_name)).toEqual([
      'Nour',
      'Mona',
      'Youssef',
    ]);
  });

  it('normalises gender and title to Duffel’s lowercase sets', async () => {
    const fake = new FakeDuffelService();
    const provider = new DuffelBookingProvider(fake as unknown as DuffelService);

    await provider.createBooking({
      offerId: 'off_1',
      offerSnapshot: offerSnapshot({ duffelPassengers: TWO_ADULTS }),
      travelers: [
        completeTraveler({ gender: 'F', title: 'MRS' }),
        completeTraveler({ gender: 'female', title: 'Miss' }),
      ],
    });

    const passengers = fake.createOrderCalls[0].passengers;
    expect(passengers[0].gender).toBe('f');
    expect(passengers[0].title).toBe('mrs');
    expect(passengers[1].gender).toBe('f');
    expect(passengers[1].title).toBe('miss');
  });

  it('omits identity documents when the funnel did not collect them all', async () => {
    const fake = new FakeDuffelService();
    const provider = new DuffelBookingProvider(fake as unknown as DuffelService);

    const result = await provider.createBooking({
      offerId: 'off_1',
      offerSnapshot: offerSnapshot(),
      travelers: [completeTraveler({ documentNumber: undefined })],
    });

    // The document is optional at this boundary; the rest still maps.
    expect(result.success).toBe(true);
    expect(
      fake.createOrderCalls[0].passengers[0],
    ).not.toHaveProperty('identity_documents');
  });

  it('accepts Duffel-native field names too (no double mapping)', async () => {
    const fake = new FakeDuffelService();
    const provider = new DuffelBookingProvider(fake as unknown as DuffelService);

    await provider.createBooking({
      offerId: 'off_1',
      offerSnapshot: offerSnapshot(),
      travelers: [
        {
          passengerType: 'adult',
          given_name: 'Mona',
          family_name: 'Adel',
          born_on: '1992-05-05',
          gender: 'f',
          title: 'ms',
          email: 'mona@example.com',
          phone_number: '+201111111111',
        },
      ],
    });

    expect(fake.createOrderCalls[0].passengers[0]).toEqual({
      id: 'pas_1',
      given_name: 'Mona',
      family_name: 'Adel',
      born_on: '1992-05-05',
      gender: 'f',
      title: 'ms',
      email: 'mona@example.com',
      phone_number: '+201111111111',
    });
  });
});

describe('Duffel booking adapter — fail closed before the provider call', () => {
  it('blocks the call when a required field is missing', async () => {
    const fake = new FakeDuffelService();
    const provider = new DuffelBookingProvider(fake as unknown as DuffelService);

    const result = await provider.createBooking({
      offerId: 'off_1',
      offerSnapshot: offerSnapshot(),
      travelers: [completeTraveler({ title: undefined })],
    });

    expect(result.success).toBe(false);
    expect(fake.createOrderCalls).toHaveLength(0);
    expect(result.error).toContain('title');
  });

  it('does not copy the lead traveller’s contact onto another passenger', async () => {
    const fake = new FakeDuffelService();
    const provider = new DuffelBookingProvider(fake as unknown as DuffelService);

    const result = await provider.createBooking({
      offerId: 'off_1',
      offerSnapshot: offerSnapshot({ duffelPassengers: TWO_ADULTS }),
      travelers: [
        completeTraveler({
          firstName: 'Nour',
          email: 'lead@example.com',
          phone: '+201000000000',
        }),
        completeTraveler({
          firstName: 'Mona',
          email: undefined,
          phone: undefined,
        }),
      ],
    });

    expect(result.success).toBe(false);
    expect(fake.createOrderCalls).toHaveLength(0);
    expect(result.error).toContain('passenger 2: email, phone_number');
  });

  it('blocks the call when the offer passenger ids are absent from the snapshot', async () => {
    const fake = new FakeDuffelService();
    const provider = new DuffelBookingProvider(fake as unknown as DuffelService);

    const result = await provider.createBooking({
      offerId: 'off_1',
      travelers: [completeTraveler()],
    });

    expect(result.success).toBe(false);
    expect(fake.createOrderCalls).toHaveLength(0);
    expect(result.error).toContain('duffelPassengers');
  });

  it('blocks the call for an empty traveller list', async () => {
    const fake = new FakeDuffelService();
    const provider = new DuffelBookingProvider(fake as unknown as DuffelService);

    const result = await provider.createBooking({ offerId: 'off_1' });

    expect(result.success).toBe(false);
    expect(fake.createOrderCalls).toHaveLength(0);
  });

  it('rejects a gender or title outside Duffel’s accepted sets', async () => {
    const fake = new FakeDuffelService();
    const provider = new DuffelBookingProvider(fake as unknown as DuffelService);

    const result = await provider.createBooking({
      offerId: 'off_1',
      offerSnapshot: offerSnapshot(),
      travelers: [completeTraveler({ gender: 'unknown', title: 'mx' })],
    });

    expect(result.success).toBe(false);
    expect(fake.createOrderCalls).toHaveLength(0);
    expect(result.error).toContain('gender');
    expect(result.error).toContain('title');
  });
});

describe('Duffel booking adapter — unchanged error handling', () => {
  it('surfaces a provider throw as a structured failure', async () => {
    const fake = new FakeDuffelService();
    fake.createOrderError = new Error('Duffel rejected the order');
    const provider = new DuffelBookingProvider(fake as unknown as DuffelService);

    const result = await provider.createBooking({
      offerId: 'off_1',
      offerSnapshot: offerSnapshot(),
      travelers: [completeTraveler()],
    });

    expect(result.success).toBe(false);
    expect(result.error).toBe('Duffel rejected the order');
    expect(fake.createOrderCalls).toHaveLength(1);
  });

  it('still returns the provider reference and booking id', async () => {
    const fake = new FakeDuffelService();
    const provider = new DuffelBookingProvider(fake as unknown as DuffelService);

    const result = await provider.createBooking({
      offerId: 'off_1',
      offerSnapshot: offerSnapshot(),
      travelers: [completeTraveler()],
    });

    expect(result.success).toBe(true);
    expect(result.data?.reference).toBe('ABC123');
    expect(result.data?.providerBookingId).toBe('ord_1');
  });
});
