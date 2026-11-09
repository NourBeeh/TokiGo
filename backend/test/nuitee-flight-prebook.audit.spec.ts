// The DTO decorators need the reflect metadata polyfill (the app loads it in
// main.ts; a bare Jest process has to load it itself).
import 'reflect-metadata';

import { NuiteeFlightService } from '../src/modules/nuitee/nuitee.flight.service';
import { NuiteeFlightBookingProvider } from '../src/modules/bookings/adapters/nuitee-flight-booking.provider';

/**
 * P3-D4 — Nuitee flight prebook audit (READ-ONLY).
 *
 * The LiteAPI `/flights/prebooks` contract supports real traveller data:
 *   passengers [{ passengerType, firstName, lastName, birthday, gender,
 *                 nationality, documentType, documentNumber,
 *                 documentIssueCountry, documentExpiry }]
 *
 * The booking adapter nevertheless prebooks with FIXED sandbox values, and
 * the final `/flights/bookings` call only reuses the `prebookId`. These tests
 * pin the exact fixed behaviour and its scope so the gap is visible and
 * cannot drift silently.
 *
 * P3-D5: the passenger shape is now contract-correct (INTEGER passengerType),
 * the prepare-time prebook returns the real journey price, and the confirm
 * step maps REAL travellers. The prepare-time contact stays sandbox because
 * travellers do not exist yet at that point.
 *
 * P3-D6: the duplicate prebook is gone. `BookingsService.create` passes the
 * persisted travellers to `revalidateBooking`, so the confirm-time prebook
 * already carries the real party; `createBooking` only reuses its prebookId
 * and calls `/flights/bookings`. One logical booking operation creates ONE
 * prebook.
 */
class FakeNuiteeFlightService {
  prebookFlightCalls: Array<Record<string, unknown>> = [];
  bookFlightCalls: Array<Record<string, unknown>> = [];
  prebookLookupCalls: string[] = [];
  verifyCalls: string[] = [];

  prebookPrice = 800;
  prebookCurrency = 'USD';

  // Review-stage read-only lookups (P3-D7).
  verifyPrice = 800;
  verifyCurrency = 'USD';
  verifyChanged = false;
  verifyOldPrice?: number;
  verifyNewPrice?: number;
  verifyFails = false;
  prebookLookupFails = false;
  prebookLookupPrice = 800;

  async prebookFlight(payload: Record<string, unknown>) {
    this.prebookFlightCalls.push(payload);
    return {
      success: true,
      prebookId: 'pb_1',
      transactionId: 'tx_1',
      price: this.prebookPrice,
      currency: this.prebookCurrency,
      servicesAttachable: { expiresAt: '2026-12-01T00:00:00Z' },
      timestamp: new Date(),
    };
  }

  async bookFlight(payload: Record<string, unknown>) {
    this.bookFlightCalls.push(payload);
    return {
      success: true,
      bookingId: 'bk_1',
      bookingRef: 'FH-1',
      status: 'CREATED',
      timestamp: new Date(),
    };
  }

  async getFlightPrebook(prebookId: string) {
    this.prebookLookupCalls.push(prebookId);
    if (this.prebookLookupFails) {
      return {
        success: false,
        error: `Nuitee flight prebook lookup failed (404): ${prebookId}`,
        timestamp: new Date(),
      };
    }
    return {
      success: true,
      prebookId,
      transactionId: 'tx_1',
      price: this.prebookLookupPrice,
      currency: 'USD',
      available: this.prebookLookupPrice > 0,
      expiresAt: '2026-12-01T00:00:00Z',
      timestamp: new Date(),
    };
  }

  async verifyFlightOffer(offerId: string) {
    this.verifyCalls.push(offerId);
    if (this.verifyFails) {
      return {
        success: false,
        error: 'Nuitee flight verify failed (404): offer expired',
        timestamp: new Date(),
      };
    }
    return {
      success: true,
      price: this.verifyPrice,
      currency: this.verifyCurrency,
      available: this.verifyPrice > 0,
      priceChanged: this.verifyChanged,
      oldPrice: this.verifyOldPrice,
      newPrice: this.verifyNewPrice,
      expiresAt: '2026-12-01T00:00:00Z',
      timestamp: new Date(),
    };
  }
}

describe('Nuitee flight prebook — fixed sandbox passenger (audit)', () => {
  const REAL_TRAVELERS = [
    {
      firstName: 'Nour',
      lastName: 'Adel',
      dateOfBirth: '1990-01-01',
      gender: 'M',
      nationality: 'EG',
      passengerType: 'adult',
      email: 'nour@example.com',
      phone: '201000000000',
      phoneCountryCode: '+20',
    },
    {
      firstName: 'Sara',
      lastName: 'Adel',
      dateOfBirth: '1992-05-04',
      gender: 'F',
      nationality: 'EG',
      passengerType: 'adult',
      email: 'sara@example.com',
      phone: '201000000001',
      phoneCountryCode: '+20',
    },
  ];

  it('P3-D8 prepare (no snapshot, no travellers) VERIFIES and never prebooks', async () => {
    const fake = new FakeNuiteeFlightService();
    const provider = new NuiteeFlightBookingProvider(
      fake as unknown as NuiteeFlightService,
    );

    const result = await provider.revalidateBooking('off_1');

    expect(result.success).toBe(true);
    expect(result.data?.price).toBe(800);
    expect(result.data?.currency).toBe('USD');
    expect(result.data?.available).toBe(true);
    // Prepare must NOT reserve inventory for a party that does not exist yet:
    // LiteAPI has no prebook cancel/release endpoint, so that hold would be
    // orphaned. Verify is the documented pre-booking price check.
    expect(fake.prebookFlightCalls).toHaveLength(0);
    expect(fake.prebookLookupCalls).toHaveLength(0);
    expect(fake.verifyCalls).toEqual(['off_1']);
    expect(result.data?.handoff).toEqual({ offerId: 'off_1' });
    // No sandbox passenger payload is ever sent.
    expect(JSON.stringify(fake.prebookFlightCalls)).not.toContain('Test');
  });

  it('revalidateBooking WITH travellers prebooks the REAL party', async () => {
    const fake = new FakeNuiteeFlightService();
    const provider = new NuiteeFlightBookingProvider(
      fake as unknown as NuiteeFlightService,
    );

    const result = await provider.revalidateBooking('off_1', {
      travelers: REAL_TRAVELERS,
    });

    expect(result.success).toBe(true);
    expect(result.data?.price).toBe(800);
    expect(result.data?.handoff?.prebookId).toBe('pb_1');
    expect(fake.prebookFlightCalls).toHaveLength(1);
    expect(fake.prebookFlightCalls[0]).toMatchObject({
      offerId: 'off_1',
      contact: {
        firstName: 'Nour',
        lastName: 'Adel',
        email: 'nour@example.com',
        phoneCountryCode: '20',
        phoneNumber: '201000000000',
      },
      passengers: [
        {
          passengerType: 0,
          firstName: 'Nour',
          lastName: 'Adel',
          birthday: '1990-01-01',
          gender: 'M',
          nationality: 'EG',
        },
        {
          passengerType: 0,
          firstName: 'Sara',
          lastName: 'Adel',
          birthday: '1992-05-04',
          gender: 'F',
          nationality: 'EG',
        },
      ],
    });
    // The sandbox placeholder must never appear on a traveller-carrying
    // prebook.
    expect(JSON.stringify(fake.prebookFlightCalls[0])).not.toContain('Test');
  });

  it('createBooking REUSES the prebookId and never prebooks again', async () => {
    const fake = new FakeNuiteeFlightService();
    const provider = new NuiteeFlightBookingProvider(
      fake as unknown as NuiteeFlightService,
    );

    const result = await provider.createBooking({
      offerId: 'off_1',
      offerSnapshot: { prebookId: 'pb_real', transactionId: 'tx_1', offerId: 'off_1' },
      travelers: REAL_TRAVELERS,
    });

    expect(result.success).toBe(true);
    expect(result.data?.reference).toBe('FH-1');
    // The prebook belongs to the confirm-time revalidation; prebooking again
    // would create a duplicate provider inventory hold.
    expect(fake.prebookFlightCalls).toHaveLength(0);
    expect(fake.bookFlightCalls).toEqual([
      { prebookId: 'pb_real', payment: { method: 'ACC_CREDIT_CARD' } },
    ]);
  });

  it('one logical booking operation creates exactly ONE prebook', async () => {
    const fake = new FakeNuiteeFlightService();
    const provider = new NuiteeFlightBookingProvider(
      fake as unknown as NuiteeFlightService,
    );

    // Confirm-time revalidation (BookingsService.create passes the travellers).
    const revalidation = await provider.revalidateBooking('off_1', {
      travelers: REAL_TRAVELERS,
    });
    expect(revalidation.success).toBe(true);

    // Confirmation reuses that prebook.
    const booking = await provider.createBooking({
      offerId: 'off_1',
      offerSnapshot: {
        prebookId: revalidation.data?.handoff?.prebookId,
        transactionId: revalidation.data?.handoff?.transactionId,
      },
      travelers: REAL_TRAVELERS,
    });
    expect(booking.success).toBe(true);

    expect(fake.prebookFlightCalls).toHaveLength(1);
    expect(fake.bookFlightCalls).toHaveLength(1);
  });

  // ------------------------------------------------------------------
  // P3-D7 — review revalidation reuses the existing prebook
  // ------------------------------------------------------------------

  it('P3-D7 review revalidation succeeds WITHOUT calling prebookFlight', async () => {
    const fake = new FakeNuiteeFlightService();
    const provider = new NuiteeFlightBookingProvider(
      fake as unknown as NuiteeFlightService,
    );

    const result = await provider.revalidateBooking('off_1', {
      offerSnapshot: {
        offerId: 'off_1',
        prebookId: 'pb_1',
        transactionId: 'tx_1',
      },
    });

    expect(result.success).toBe(true);
    expect(result.data?.price).toBe(800);
    expect(result.data?.currency).toBe('USD');
    expect(result.data?.available).toBe(true);
    // The hold is READ, never recreated.
    expect(fake.prebookFlightCalls).toHaveLength(0);
    expect(fake.prebookLookupCalls).toEqual(['pb_1']);
    expect(fake.verifyCalls).toEqual(['off_1']);
    // The handoff still names the SAME prebook — confirmation reuses it.
    expect(result.data?.handoff?.prebookId).toBe('pb_1');
  });

  it('P3-D7 repeated review revalidation creates no additional holds', async () => {
    const fake = new FakeNuiteeFlightService();
    const provider = new NuiteeFlightBookingProvider(
      fake as unknown as NuiteeFlightService,
    );

    for (let i = 0; i < 3; i++) {
      const result = await provider.revalidateBooking('off_1', {
        offerSnapshot: { offerId: 'off_1', prebookId: 'pb_1' },
      });
      expect(result.success).toBe(true);
    }

    expect(fake.prebookFlightCalls).toHaveLength(0);
    expect(fake.prebookLookupCalls).toHaveLength(3);
  });

  it('P3-D8 a review without a prebookId verifies and never prebooks', async () => {
    const fake = new FakeNuiteeFlightService();
    const provider = new NuiteeFlightBookingProvider(
      fake as unknown as NuiteeFlightService,
    );

    const result = await provider.revalidateBooking('off_1', {
      offerSnapshot: { offerId: 'off_1' },
    });

    expect(result.success).toBe(true);
    expect(result.data?.price).toBe(800);
    // Nothing to validate and nothing to create — the review is read-only.
    expect(fake.prebookFlightCalls).toHaveLength(0);
    expect(fake.prebookLookupCalls).toHaveLength(0);
    expect(fake.verifyCalls).toEqual(['off_1']);
  });

  it('P3-D7 an expired/invalid prebook is not silently reused', async () => {
    const fake = new FakeNuiteeFlightService();
    fake.prebookLookupFails = true;
    const provider = new NuiteeFlightBookingProvider(
      fake as unknown as NuiteeFlightService,
    );

    const result = await provider.revalidateBooking('off_1', {
      offerSnapshot: { offerId: 'off_1', prebookId: 'pb_dead' },
    });

    expect(result.success).toBe(false);
    expect(result.error).toContain('prebook lookup failed');
    // Fail closed BEFORE the price check and WITHOUT prebooking again.
    expect(fake.verifyCalls).toHaveLength(0);
    expect(fake.prebookFlightCalls).toHaveLength(0);
  });

  it('P3-D7 a verify failure fails the review instead of inventing a price', async () => {
    const fake = new FakeNuiteeFlightService();
    fake.verifyFails = true;
    const provider = new NuiteeFlightBookingProvider(
      fake as unknown as NuiteeFlightService,
    );

    const result = await provider.revalidateBooking('off_1', {
      offerSnapshot: { offerId: 'off_1', prebookId: 'pb_1' },
    });

    expect(result.success).toBe(false);
    expect(result.error).toContain('verify failed');
    expect(fake.prebookFlightCalls).toHaveLength(0);
  });

  it('P3-D7 the review surfaces a provider-reported price change', async () => {
    const fake = new FakeNuiteeFlightService();
    fake.verifyPrice = 950;
    fake.verifyChanged = true;
    fake.verifyOldPrice = 800;
    fake.verifyNewPrice = 950;
    const provider = new NuiteeFlightBookingProvider(
      fake as unknown as NuiteeFlightService,
    );

    const result = await provider.revalidateBooking('off_1', {
      offerSnapshot: { offerId: 'off_1', prebookId: 'pb_1' },
    });

    expect(result.success).toBe(true);
    expect(result.data?.price).toBe(950);
    expect(result.data?.priceChanged).toBe(true);
    expect(result.data?.oldPrice).toBe(800);
    expect(fake.prebookFlightCalls).toHaveLength(0);
  });

  it('P3-D7 the review never reports the sandbox passenger party', async () => {
    const fake = new FakeNuiteeFlightService();
    const provider = new NuiteeFlightBookingProvider(
      fake as unknown as NuiteeFlightService,
    );

    await provider.revalidateBooking('off_1', {
      offerSnapshot: { offerId: 'off_1', prebookId: 'pb_1' },
    });

    // No prebook payload at all — the review reads the existing hold.
    expect(JSON.stringify(fake.prebookFlightCalls)).not.toContain('Test');
  });

  it('P3-D7 a confirm retry with the SAME party reuses the prebook', async () => {
    const fake = new FakeNuiteeFlightService();
    const provider = new NuiteeFlightBookingProvider(
      fake as unknown as NuiteeFlightService,
    );

    const first = await provider.revalidateBooking('off_1', {
      travelers: REAL_TRAVELERS,
    });
    expect(first.success).toBe(true);
    expect(fake.prebookFlightCalls).toHaveLength(1);

    const retry = await provider.revalidateBooking('off_1', {
      travelers: REAL_TRAVELERS,
      offerSnapshot: {
        offerId: 'off_1',
        prebookId: first.data?.handoff?.prebookId,
        travelerFingerprint: first.data?.handoff?.travelerFingerprint,
      },
    });

    expect(retry.success).toBe(true);
    expect(retry.data?.handoff?.prebookId).toBe('pb_1');
    // The retry READ the existing hold — no second inventory hold.
    expect(fake.prebookFlightCalls).toHaveLength(1);
    expect(fake.prebookLookupCalls).toEqual(['pb_1']);
  });

  it('P3-D7 a DIFFERENT party prebooks again (fingerprint mismatch)', async () => {
    const fake = new FakeNuiteeFlightService();
    const provider = new NuiteeFlightBookingProvider(
      fake as unknown as NuiteeFlightService,
    );

    const first = await provider.revalidateBooking('off_1', {
      travelers: REAL_TRAVELERS,
    });
    const second = await provider.revalidateBooking('off_1', {
      travelers: [REAL_TRAVELERS[0]],
      offerSnapshot: {
        offerId: 'off_1',
        prebookId: first.data?.handoff?.prebookId,
        travelerFingerprint: first.data?.handoff?.travelerFingerprint,
      },
    });

    expect(second.success).toBe(true);
    expect(fake.prebookFlightCalls).toHaveLength(2);
  });

  it('fails closed when a required passenger field is missing', async () => {
    const fake = new FakeNuiteeFlightService();
    const provider = new NuiteeFlightBookingProvider(
      fake as unknown as NuiteeFlightService,
    );

    const result = await provider.createBooking({
      offerId: 'off_1',
      offerSnapshot: { prebookId: 'pb_real' },
      travelers: [{ firstName: 'Nour', lastName: 'Adel' }],
    });

    expect(result.success).toBe(false);
    expect(result.error).toContain('requires a complete party');
    expect(fake.prebookFlightCalls).toHaveLength(0);
    expect(fake.bookFlightCalls).toHaveLength(0);
  });

  it('fails closed when the lead contact has no phone country code', async () => {
    const fake = new FakeNuiteeFlightService();
    const provider = new NuiteeFlightBookingProvider(
      fake as unknown as NuiteeFlightService,
    );

    const result = await provider.createBooking({
      offerId: 'off_1',
      offerSnapshot: { prebookId: 'pb_real' },
      travelers: [
        {
          firstName: 'Nour',
          lastName: 'Adel',
          dateOfBirth: '1990-01-01',
          gender: 'M',
          nationality: 'EG',
          passengerType: 'adult',
          email: 'nour@example.com',
          phone: '201000000000',
        },
      ],
    });

    expect(result.success).toBe(false);
    expect(result.error).toContain('phone country code');
    expect(fake.prebookFlightCalls).toHaveLength(0);
    expect(fake.bookFlightCalls).toHaveLength(0);
  });

  it('fails closed when the snapshot carries no prebookId', async () => {
    const fake = new FakeNuiteeFlightService();
    const provider = new NuiteeFlightBookingProvider(
      fake as unknown as NuiteeFlightService,
    );

    const result = await provider.createBooking({
      offerId: 'off_1',
      travelers: REAL_TRAVELERS,
    });

    expect(result.success).toBe(false);
    expect(result.error).toContain('prebookId');
    expect(fake.bookFlightCalls).toHaveLength(0);
  });
});
