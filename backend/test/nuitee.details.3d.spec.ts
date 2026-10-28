import { NuiteeService } from '../src/modules/nuitee/nuitee.service';
import { NuiteeFlightService } from '../src/modules/nuitee/nuitee.flight.service';

/**
 * Phase 3D — Product details (adapter contract).
 *
 * The details page renders provider-verbatim fields; the adapters must carry
 * them through metadata (never invented, absent stays absent). Contracts:
 * - Nuitee HOTELS: stars / boardName / taxesAndFees (amount, currency,
 *   included, description) / cancellationPolicy (refundableUntil,
 *   feeAmount, feeCurrency, timezone) — the LAST policy window verbatim.
 * - Nuitee FLIGHTS: fareFamily / refundable / baggage verbatim.
 * - Missing provider fields → metadata keys stay absent (never invented).
 */

function fetchMock(body: any) {
  return jest.fn().mockResolvedValue({
    ok: true,
    status: 200,
    text: async () => JSON.stringify(body),
  });
}

const HOTEL_RESPONSE = {
  data: [
    {
      hotelId: 'H1',
      roomTypes: [
        {
          roomTypeName: 'Twin Room',
          rates: [
            {
              rateId: 'rate-1',
              name: 'Twin Room (Madina Deluxe)',
              boardName: 'Room Only',
              boardType: 'RO',
              retailRate: {
                total: [{ amount: 490, currency: 'USD' }],
                taxesAndFees: [
                  { amount: 25.69, currency: 'USD', included: true, description: 'Tax' },
                ],
              },
              cancellationPolicies: {
                refundableTag: 'RFN',
                cancelPolicyInfos: [
                  { cancelTime: '2026-10-12 07:00:00', amount: 100, currency: 'USD', type: 'amount', timezone: 'GMT' },
                  { cancelTime: '2026-10-13 07:00:00', amount: 623.2, currency: 'USD', type: 'amount', timezone: 'GMT' },
                ],
              },
            },
          ],
        },
      ],
    },
  ],
  hotels: [{ id: 'H1', name: 'Cairo Grand', stars: 5, rating: 9.6, city_name: 'Cairo' }],
};

const FLIGHT_RESPONSE = {
  data: [
    {
      journeys: [
        {
          journeyKey: 'j-1',
          segments: [
            {
              originCode: 'CAI',
              destinationCode: 'DXB',
              departureTime: '2026-09-12T08:30:00',
              arrivalTime: '2026-09-12T12:45:00',
              carrier: { marketingName: 'EgyptAir', marketingCode: 'MS' },
              flight: { marketingNumber: '910' },
            },
          ],
          totalDuration: { iso8601: 'PT4H15M' },
          offers: [
            {
              offerId: 'of-1',
              pricing: { display: { total: 320.5, currency: 'USD' } },
              fare: { family: 'Basic' },
              terms: { refundable: true },
              baggage: { quantity: 1, type: 'checked' },
              expiration: '2026-09-10T00:00:00Z',
            },
          ],
        },
      ],
    },
  ],
};

describe('3D — Nuitee adapter carries verbatim detail fields', () => {
  const realFetch = global.fetch;

  afterEach(() => {
    (global as any).fetch = realFetch;
  });

  it('HOTEL: stars/boardName/taxesAndFees/cancellationPolicy pass through verbatim', async () => {
    (global as any).fetch = fetchMock(HOTEL_RESPONSE);
    const service = new NuiteeService({ get: () => 'sand_key' } as any);
    const result = await service.searchHotels({
      city: 'Cairo',
      checkIn: new Date('2026-10-14'),
      checkOut: new Date('2026-10-17'),
    });

    const offer = (result.data ?? [])[0];
    const meta = offer.metadata;
    expect(meta.stars).toBe(5);
    expect(meta.boardName).toBe('Room Only');
    expect(meta.taxesAndFees).toEqual({
      amount: 25.69,
      currency: 'USD',
      included: true,
      description: 'Tax',
    });
    // LAST policy window (closest to check-in) verbatim.
    expect(meta.cancellationPolicy).toEqual({
      refundableUntil: '2026-10-13 07:00:00',
      feeAmount: 623.2,
      feeCurrency: 'USD',
      timezone: 'GMT',
    });
    expect(meta.refundable).toBe(true);
  });

  it('HOTEL: absent provider fields → metadata keys stay ABSENT (never invented)', async () => {
    (global as any).fetch = fetchMock({
      data: [
        {
          hotelId: 'H1',
          roomTypes: [
            {
              roomTypeName: 'Twin',
              rates: [
                {
                  rateId: 'rate-1',
                  retailRate: { total: [{ amount: 100, currency: 'USD' }] },
                  cancellationPolicies: { refundableTag: 'NRFN' },
                },
              ],
            },
          ],
        },
      ],
      hotels: [{ id: 'H1', name: 'Bare Hotel' }],
    });
    const service = new NuiteeService({ get: () => 'sand_key' } as any);
    const result = await service.searchHotels({
      city: 'Cairo',
      checkIn: new Date('2026-10-14'),
      checkOut: new Date('2026-10-17'),
    });

    const meta = (result.data ?? [])[0].metadata;
    expect(meta.stars).toBeUndefined();
    expect(meta.boardName).toBeUndefined();
    expect(meta.taxesAndFees).toBeUndefined();
    expect(meta.cancellationPolicy).toBeUndefined();
    expect(meta.refundable).toBe(false);
  });

  it('FLIGHT: fareFamily/refundable/baggage pass through verbatim', async () => {
    (global as any).fetch = fetchMock(FLIGHT_RESPONSE);
    const service = new NuiteeFlightService({ get: () => 'sand_key' } as any);
    const result = await service.searchFlights({
      origin: 'CAI',
      destination: 'DXB',
      departure: new Date('2026-09-12'),
    });

    const offer = (result.data ?? [])[0];
    expect(offer.metadata.fareFamily).toBe('Basic');
    expect(offer.metadata.refundable).toBe(true);
    expect(offer.metadata.baggage).toEqual({ quantity: 1, type: 'checked' });
  });

  it('FLIGHT: absent fields stay absent', async () => {
    (global as any).fetch = fetchMock({
      data: [
        {
          journeys: [
            {
              journeyKey: 'j-1',
              segments: [
                {
                  originCode: 'CAI',
                  destinationCode: 'DXB',
                  departureTime: '2026-09-12T08:30:00',
                  arrivalTime: '2026-09-12T12:45:00',
                },
              ],
              offers: [
                { offerId: 'of-2', pricing: { display: { total: 99, currency: 'USD' } } },
              ],
            },
          ],
        },
      ],
    });
    const service = new NuiteeFlightService({ get: () => 'sand_key' } as any);
    const result = await service.searchFlights({
      origin: 'CAI',
      destination: 'DXB',
      departure: new Date('2026-09-12'),
    });

    const meta = (result.data ?? [])[0].metadata;
    expect(meta.fareFamily).toBeUndefined();
    expect(meta.refundable).toBeUndefined();
    expect(meta.baggage).toBeUndefined();
  });
});
