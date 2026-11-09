// The DTO decorators need the reflect metadata polyfill (the app loads it in
// main.ts; a bare Jest process has to load it itself).
import 'reflect-metadata';

import { DuffelService } from '../src/modules/duffel/duffel.service';
import { DuffelBookingProvider } from '../src/modules/bookings/adapters/duffel-booking.provider';
import { NuiteeFlightService } from '../src/modules/nuitee/nuitee.flight.service';
import { NuiteeFlightBookingProvider } from '../src/modules/bookings/adapters/nuitee-flight-booking.provider';

/**
 * P3-D6 — cross-provider isolation.
 *
 * A traveller record is shared by every provider, so a field collected for one
 * provider must never leak into another provider's payload, and no internal
 * TokiGo name may appear where the provider contract defines its own.
 */
class FakeDuffelService {
  providerName = 'Duffel Flight Provider';

  createOrderCalls: Array<{
    passengers: Array<Record<string, unknown>>;
  }> = [];

  async createOrder(
    _offerId: string,
    passengers: Array<Record<string, unknown>>,
    _payments: Array<Record<string, unknown>>,
  ): Promise<Record<string, unknown>> {
    this.createOrderCalls.push({ passengers });
    return {
      id: 'ord_1',
      booking_reference: 'ABC123',
      status: 'confirmed',
      total_amount: '800.00',
      total_currency: 'USD',
    };
  }
}

class FakeNuiteeFlightService {
  prebookFlightCalls: Array<Record<string, unknown>> = [];

  async prebookFlight(payload: Record<string, unknown>) {
    this.prebookFlightCalls.push(payload);
    return {
      success: true,
      prebookId: 'pb_1',
      transactionId: 'tx_1',
      price: 800,
      currency: 'USD',
      servicesAttachable: { expiresAt: '2026-12-01T00:00:00Z' },
      timestamp: new Date(),
    };
  }
}

const TRAVELER = {
  firstName: 'Nour',
  lastName: 'Adel',
  dateOfBirth: '1990-01-01',
  gender: 'M',
  nationality: 'EG',
  passengerType: 'adult',
  title: 'mr',
  email: 'nour@example.com',
  phone: '201000000000',
  phoneCountryCode: '+20',
  documentType: 'passport',
  documentNumber: 'P123456',
  documentIssueCountry: 'EG',
  documentExpiry: '2030-01-01',
  // Provider-specific values that must never cross over.
  prebookId: 'pb_nuitee',
  duffelPassengers: [{ id: 'pas_1', type: 'adult' }],
};

const DUFFEL_INTERNAL_NAMES: string[] = [
  'firstName',
  'lastName',
  'dateOfBirth',
  'phoneCountryCode',
  'passengerType',
  'accompanyingAdultIndex',
  'documentNumber',
  'documentIssueCountry',
  'documentExpiry',
  'prebookId',
  'duffelPassengers',
];

// `phoneCountryCode` is a genuine LiteAPI contact field, not an internal name.
const NUITEE_INTERNAL_NAMES: string[] = [
  'infant_passenger_id',
  'given_name',
  'family_name',
  'born_on',
  'phone_number',
  'duffelPassengers',
  'accompanyingAdultIndex',
];

describe('Provider isolation — Duffel payload', () => {
  it('contains no internal TokiGo or Nuitee field names', async () => {
    const fake = new FakeDuffelService();
    const provider = new DuffelBookingProvider(
      fake as unknown as DuffelService,
    );

    const result = await provider.createBooking({
      offerId: 'off_1',
      offerSnapshot: {
        offerId: 'off_1',
        duffelPassengers: [{ id: 'pas_1', type: 'adult', age: null }],
        duffelIdentityDocumentsRequired: false,
        duffelSupportedDocumentTypes: ['passport'],
      },
      travelers: [TRAVELER],
    });

    expect(result.success).toBe(true);
    expect(fake.createOrderCalls).toHaveLength(1);
    const payload = JSON.stringify(fake.createOrderCalls[0].passengers);
    for (const name of DUFFEL_INTERNAL_NAMES) {
      expect(payload).not.toContain(`"${name}"`);
    }
    // The Nuitee prebook id must never reach Duffel.
    expect(payload).not.toContain('pb_nuitee');
  });

  it('uses Duffel contract names only', async () => {
    const fake = new FakeDuffelService();
    const provider = new DuffelBookingProvider(
      fake as unknown as DuffelService,
    );

    await provider.createBooking({
      offerId: 'off_1',
      offerSnapshot: {
        offerId: 'off_1',
        duffelPassengers: [{ id: 'pas_1', type: 'adult', age: null }],
        duffelIdentityDocumentsRequired: false,
        duffelSupportedDocumentTypes: ['passport'],
      },
      travelers: [TRAVELER],
    });

    const sent = fake.createOrderCalls[0].passengers[0];
    expect(Object.keys(sent).sort()).toEqual([
      'born_on',
      'email',
      'family_name',
      'gender',
      'given_name',
      'id',
      'identity_documents',
      'phone_number',
      'title',
    ]);
  });
});

describe('Provider isolation — Nuitee payload', () => {
  it('contains no Duffel field names and no sandbox placeholder', async () => {
    const fake = new FakeNuiteeFlightService();
    const provider = new NuiteeFlightBookingProvider(
      fake as unknown as NuiteeFlightService,
    );

    const result = await provider.revalidateBooking('off_1', {
      travelers: [TRAVELER],
    });

    expect(result.success).toBe(true);
    expect(fake.prebookFlightCalls).toHaveLength(1);
    const payload = JSON.stringify(fake.prebookFlightCalls[0]);
    for (const name of NUITEE_INTERNAL_NAMES) {
      expect(payload).not.toContain(`"${name}"`);
    }
    // No Duffel passenger id may enter a LiteAPI request.
    expect(payload).not.toContain('pas_1');
    expect(payload).not.toContain('pb_nuitee');
    // A traveller-carrying prebook is never the sandbox placeholder.
    expect(payload).not.toContain('Test Guest');
  });

  it('uses LiteAPI contract names only', async () => {
    const fake = new FakeNuiteeFlightService();
    const provider = new NuiteeFlightBookingProvider(
      fake as unknown as NuiteeFlightService,
    );

    await provider.revalidateBooking('off_1', {
      travelers: [TRAVELER],
    });

    const passenger = (
      fake.prebookFlightCalls[0].passengers as Array<Record<string, unknown>>
    )[0];
    expect(Object.keys(passenger).sort()).toEqual([
      'birthday',
      'documentExpiry',
      'documentIssueCountry',
      'documentNumber',
      'documentType',
      'firstName',
      'gender',
      'lastName',
      'nationality',
      'passengerType',
      'title',
    ]);
    // LiteAPI requires an INTEGER passenger type.
    expect(passenger.passengerType).toBe(0);
  });
});
