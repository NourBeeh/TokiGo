/**
 * Phase 2D — flight itinerary grouping + provider mapper contracts.
 *
 * These tests pin the identity rules that decide when two provider offers are
 * the SAME itinerary, and prove that grouping never discards a valid fare or
 * mixes provider identities. Fixtures follow the documented Duffel Offers and
 * Nuitee/LiteAPI v3.0 flights payload shapes; no test performs network I/O.
 */
import {
  buildFlightItineraryGroups,
  compareFlightOffers,
  flightDesignator,
  flightItineraryKey,
  isValidFlightOffer,
  normalizeInstant,
} from '../src/modules/providers/flight-itinerary';
import { mapDuffelOffer } from '../src/modules/duffel/duffel.service';
import { NuiteeFlightService } from '../src/modules/nuitee/nuitee.flight.service';

function segment(overrides: Record<string, any> = {}) {
  return {
    origin: 'CAI',
    destination: 'DXB',
    departureAt: '2026-10-01T08:00:00',
    arrivalAt: '2026-10-01T12:30:00',
    marketingCarrier: { code: 'MS', name: 'EgyptAir' },
    operatingCarrier: { code: 'MS', name: 'EgyptAir' },
    marketingFlightNumber: '985',
    operatingFlightNumber: '985',
    stopCount: 0,
    ...overrides,
  };
}

function flightOffer(overrides: Record<string, any> = {}) {
  const id = overrides.id ?? 'offer-1';
  const providerId = overrides.providerId ?? 'duffel-flight';
  return {
    id,
    type: 'flight',
    providerId,
    providerName: overrides.providerName ?? providerId,
    title: 'CAI → DXB',
    price: 100,
    currency: 'USD',
    airline: 'EgyptAir',
    flightNumber: 'MS985',
    origin: 'CAI',
    destination: 'DXB',
    departureTime: '2026-10-01T08:00:00',
    arrivalTime: '2026-10-01T12:30:00',
    segments: [segment()],
    metadata: { providerOfferId: id },
    ...overrides,
  };
}

function group(...providerOffers: Array<{ providerId: string; offers: any[] }>) {
  return buildFlightItineraryGroups(
    providerOffers.map((entry) => ({
      success: true,
      providerId: entry.providerId,
      data: entry.offers,
    })),
  );
}

describe('flight itinerary identity', () => {
  it('normalizes instants without converting or merging unproven offsets', () => {
    expect(normalizeInstant('2026-10-01T08:00')).toBe('2026-10-01T08:00:00');
    expect(normalizeInstant('2026-10-01T08:00:00.123')).toBe(
      '2026-10-01T08:00:00',
    );
    expect(normalizeInstant('2026-10-01T08:00:00+0200')).toBe(
      '2026-10-01T08:00:00+02:00',
    );
    // The same local clock text without an offset is NOT provably the same
    // instant, so it must stay different.
    expect(normalizeInstant('2026-10-01T08:00:00')).not.toBe(
      normalizeInstant('2026-10-01T08:00:00+02:00'),
    );
    expect(normalizeInstant(null)).toBeNull();
  });

  it('builds a marketing designator without double-prefixing', () => {
    expect(flightDesignator('DE', '2017')).toBe('DE2017');
    expect(flightDesignator('DE', 'DE2017')).toBe('DE2017');
    expect(flightDesignator('', '985')).toBe('985');
    expect(flightDesignator('MS', '')).toBe('');
  });

  it('returns null for an offer whose ordered segments cannot be proven', () => {
    expect(
      flightItineraryKey(
        flightOffer({
          segments: [],
          origin: '',
          destination: '',
          departureTime: null,
          arrivalTime: null,
        }),
      ),
    ).toBeNull();
    expect(
      flightItineraryKey(
        flightOffer({
          segments: [
            segment({ marketingFlightNumber: '', operatingFlightNumber: '' }),
          ],
        }),
      ),
    ).toBeNull();
  });

  it('validates only offers a customer can see and book', () => {
    expect(isValidFlightOffer(flightOffer())).toBe(true);
    expect(isValidFlightOffer(flightOffer({ price: 0 }))).toBe(false);
    expect(isValidFlightOffer(flightOffer({ currency: '' }))).toBe(false);
    expect(isValidFlightOffer(flightOffer({ id: '' }))).toBe(false);
    expect(isValidFlightOffer(flightOffer({ type: 'hotel' }))).toBe(false);
    expect(
      isValidFlightOffer(
        flightOffer({ segments: [segment({ arrivalAt: null })] }),
      ),
    ).toBe(false);
  });
});

describe('flight itinerary grouping', () => {
  it('groups identical ordered segments across providers and keeps every exact offer', () => {
    const result = group(
      {
        providerId: 'duffel-flight',
        offers: [
          flightOffer({
            id: 'off_duffel_1',
            providerId: 'duffel-flight',
            price: 120,
            metadata: { providerOfferId: 'off_duffel_1' },
          }),
        ],
      },
      {
        providerId: 'nuitee-flight',
        offers: [
          flightOffer({
            id: 'nt_1',
            providerId: 'nuitee-flight',
            price: 95,
            metadata: { providerOfferId: 'nt_1' },
          }),
        ],
      },
    );

    expect(result.results).toHaveLength(1);
    const row = result.results[0];
    expect(row.offers).toHaveLength(2);
    expect(row.offers.map((offer: any) => offer.id)).toEqual(['nt_1', 'off_duffel_1']);
    expect(row.offers.map((offer: any) => offer.providerId)).toEqual([
      'nuitee-flight',
      'duffel-flight',
    ]);
    // The row summary is the cheapest valid offer; the other fare survives
    // untouched with its own provider and original offer id.
    expect(row.id).toBe('nt_1');
    expect(row.providerId).toBe('nuitee-flight');
    expect(row.price).toBe(95);
    expect(row.offerCount).toBe(2);
    expect(row.providerIds).toEqual(['nuitee-flight', 'duffel-flight']);
    expect(row.providerOfferIds).toEqual(['nt_1', 'off_duffel_1']);
    expect(row.metadata.groupedOfferCount).toBe(2);
    expect(result.duplicatesDropped).toBe(0);
    expect(result.invalidOffersDropped).toBe(0);
  });

  it('keeps different connection airports in separate rows', () => {
    const viaIstanbul = flightOffer({
      id: 'via-ist',
      segments: [
        segment({ origin: 'CAI', destination: 'IST' }),
        segment({
          origin: 'IST',
          destination: 'DXB',
          departureAt: '2026-10-01T12:00:00',
          arrivalAt: '2026-10-01T16:30:00',
          marketingCarrier: { code: 'TK', name: 'Turkish Airlines' },
          operatingCarrier: { code: 'TK', name: 'Turkish Airlines' },
          marketingFlightNumber: '760',
          operatingFlightNumber: '760',
        }),
      ],
    });
    const viaAmman = flightOffer({
      id: 'via-amm',
      segments: [
        segment({ origin: 'CAI', destination: 'AMM' }),
        segment({
          origin: 'AMM',
          destination: 'DXB',
          departureAt: '2026-10-01T12:00:00',
          arrivalAt: '2026-10-01T16:30:00',
          marketingCarrier: { code: 'TK', name: 'Turkish Airlines' },
          operatingCarrier: { code: 'TK', name: 'Turkish Airlines' },
          marketingFlightNumber: '760',
          operatingFlightNumber: '760',
        }),
      ],
    });

    const result = group({ providerId: 'duffel-flight', offers: [viaIstanbul, viaAmman] });
    expect(result.results).toHaveLength(2);
    expect(result.results.map((row: any) => row.id)).toEqual(['via-ist', 'via-amm']);
  });

  it('keeps different operating carriers (codeshares) in separate rows', () => {
    const operatedByMs = flightOffer({ id: 'op-ms' });
    const operatedByXy = flightOffer({
      id: 'op-xy',
      segments: [
        segment({
          operatingCarrier: { code: 'XY', name: 'Sky Express' },
          operatingFlightNumber: '985',
        }),
      ],
    });

    const result = group({
      providerId: 'duffel-flight',
      offers: [operatedByMs, operatedByXy],
    });
    expect(result.results).toHaveLength(2);
    // Marketing identity is preserved verbatim on the codeshare offer.
    expect(operatedByXy.segments[0].marketingCarrier.code).toBe('MS');
    expect(operatedByXy.segments[0].operatingCarrier.code).toBe('XY');
  });

  it('keeps different segment order in separate rows', () => {
    const outThenBack = flightOffer({
      id: 'ordered-ab',
      segments: [
        segment({ origin: 'CAI', destination: 'IST' }),
        segment({
          origin: 'IST',
          destination: 'DXB',
          departureAt: '2026-10-01T12:00:00',
          arrivalAt: '2026-10-01T16:30:00',
        }),
      ],
    });
    const backThenOut = flightOffer({
      id: 'ordered-ba',
      segments: [
        segment({ origin: 'IST', destination: 'DXB' }),
        segment({
          origin: 'CAI',
          destination: 'IST',
          departureAt: '2026-10-01T12:00:00',
          arrivalAt: '2026-10-01T16:30:00',
        }),
      ],
    });

    const result = group({
      providerId: 'duffel-flight',
      offers: [outThenBack, backThenOut],
    });
    expect(result.results).toHaveLength(2);
  });

  it('keeps different departure/arrival times separate', () => {
    const atEight = flightOffer({ id: 'at-8' });
    const atNine = flightOffer({
      id: 'at-9',
      segments: [segment({ departureAt: '2026-10-01T09:00:00' })],
    });

    const result = group({
      providerId: 'duffel-flight',
      offers: [atEight, atNine],
    });
    expect(result.results).toHaveLength(2);
  });

  it('does not merge an offset-bearing instant with the same local clock text', () => {
    const noOffset = flightOffer({ id: 'no-offset' });
    const withOffset = flightOffer({
      id: 'with-offset',
      segments: [segment({ departureAt: '2026-10-01T08:00:00+02:00' })],
    });

    const result = group({
      providerId: 'duffel-flight',
      offers: [noOffset, withOffset],
    });
    expect(result.results).toHaveLength(2);
  });

  it('treats equivalent instant spellings as the same moment', () => {
    const short = flightOffer({ id: 'short' });
    const long = flightOffer({
      id: 'long',
      segments: [
        segment({
          departureAt: '2026-10-01T08:00:00.000',
          arrivalAt: '2026-10-01T12:30:00.000',
        }),
      ],
    });
    const offsetA = flightOffer({
      id: 'offset-a',
      segments: [segment({ departureAt: '2026-10-01T08:00:00+0200' })],
    });
    const offsetB = flightOffer({
      id: 'offset-b',
      segments: [segment({ departureAt: '2026-10-01T08:00:00+02:00' })],
    });

    expect(group({ providerId: 'p', offers: [short, long] }).results).toHaveLength(1);
    expect(group({ providerId: 'p', offers: [offsetA, offsetB] }).results).toHaveLength(1);
  });

  it('keeps different technical stop counts separate', () => {
    const nonStopSegment = flightOffer({ id: 'tech-0' });
    const technicalStop = flightOffer({
      id: 'tech-1',
      segments: [segment({ stopCount: 1 })],
    });

    const result = group({
      providerId: 'duffel-flight',
      offers: [nonStopSegment, technicalStop],
    });
    expect(result.results).toHaveLength(2);
  });

  it('groups cabin/fare-brand variants of one itinerary into a single row with every fare', () => {
    const economySaver = flightOffer({
      id: 'eco-saver',
      price: 100,
      cabinClass: 'economy',
      fareBrand: 'Economy Saver',
    });
    const economyFlex = flightOffer({
      id: 'eco-flex',
      price: 180,
      cabinClass: 'economy',
      fareBrand: 'Economy Flex',
    });
    const business = flightOffer({
      id: 'business',
      price: 600,
      cabinClass: 'business',
      fareBrand: 'Business',
    });

    const result = group({
      providerId: 'duffel-flight',
      offers: [economyFlex, business, economySaver],
    });
    expect(result.results).toHaveLength(1);
    expect(result.results[0].offers).toHaveLength(3);
    expect(result.results[0].offers.map((offer: any) => offer.id)).toEqual([
      'eco-saver',
      'eco-flex',
      'business',
    ]);
    expect(result.results[0].offers.map((offer: any) => offer.fareBrand)).toEqual([
      'Economy Saver',
      'Economy Flex',
      'Business',
    ]);
  });

  it('dedupes duplicate provider+offer id inside one row, first one wins', () => {
    const first = flightOffer({
      id: 'shared-id',
      providerId: 'duffel-flight',
      price: 120,
    });
    const duplicate = flightOffer({
      id: 'shared-id',
      providerId: 'duffel-flight',
      price: 50,
    });
    const otherProvider = flightOffer({
      id: 'shared-id',
      providerId: 'nuitee-flight',
      price: 100,
    });

    const result = group(
      { providerId: 'duffel-flight', offers: [first, duplicate] },
      { providerId: 'nuitee-flight', offers: [otherProvider] },
    );

    expect(result.results).toHaveLength(1);
    // The first duplicate was kept; the second was dropped, never silently
    // substituted with its cheaper price. Offers are cheapest-first, so the
    // surviving duffel fare (120) follows the nuitee fare (100).
    expect(result.results[0].offers).toHaveLength(2);
    expect(result.results[0].offers[0].providerId).toBe('nuitee-flight');
    expect(result.results[0].offers[0].price).toBe(100);
    expect(result.results[0].offers[1].providerId).toBe('duffel-flight');
    expect(result.results[0].offers[1].price).toBe(120);
    expect(result.duplicatesDropped).toBe(1);
  });

  it('never merges the same provider+id across different itineraries', () => {
    const cairoDubai = flightOffer({ id: 'reused-id', destination: 'DXB' });
    const cairoIstanbul = flightOffer({
      id: 'reused-id',
      destination: 'IST',
      arrivalTime: '2026-10-01T10:15:00',
      segments: [
        segment({ destination: 'IST', arrivalAt: '2026-10-01T10:15:00' }),
      ],
    });

    const result = group({
      providerId: 'duffel-flight',
      offers: [cairoDubai, cairoIstanbul],
    });
    expect(result.results).toHaveLength(2);
    expect(result.results.map((row: any) => row.id)).toEqual([
      'reused-id',
      'reused-id',
    ]);
    expect(result.duplicatesDropped).toBe(0);
  });

  it('chooses the lowest effective customer amount as the row summary', () => {
    const providerCheap = flightOffer({
      id: 'provider-cheap',
      price: 90,
    });
    const customerCheap = flightOffer({
      id: 'customer-cheap',
      price: 100,
      customerPrice: {
        customerAmount: 4000,
        customerCurrency: 'USD',
      },
    });
    const customerDear = flightOffer({
      id: 'customer-dear',
      price: 95,
      customerPrice: {
        customerAmount: 6000,
        customerCurrency: 'USD',
      },
    });

    const result = group({
      providerId: 'duffel-flight',
      offers: [customerDear, customerCheap, providerCheap],
    });
    expect(result.results).toHaveLength(1);
    expect(result.results[0].id).toBe('provider-cheap');
    expect(result.results[0].price).toBe(90);
    // Every other fare is still present and selectable.
    expect(result.results[0].offers.map((offer: any) => offer.id)).toEqual([
      'provider-cheap',
      'customer-cheap',
      'customer-dear',
    ]);
  });

  it('never falsely ranks amounts across different currencies', () => {
    const egpQuote = flightOffer({
      id: 'egp-quote',
      price: 100,
      customerPrice: {
        customerAmount: 5000,
        customerCurrency: 'EGP',
      },
    });
    const usdNoQuote = flightOffer({
      id: 'usd-no-quote',
      price: 90,
      currency: 'USD',
    });

    // Deterministic currency-first order; 5000 EGP is never compared to 90 USD
    // as if it were the smaller number.
    expect(compareFlightOffers(egpQuote, usdNoQuote)).toBeLessThan(0);
    expect(compareFlightOffers(usdNoQuote, egpQuote)).toBeGreaterThan(0);

    const result = group({
      providerId: 'duffel-flight',
      offers: [usdNoQuote, egpQuote],
    });
    expect(result.results).toHaveLength(1);
    expect(result.results[0].id).toBe('egp-quote');
  });

  it('is deterministic for equal prices across providers', () => {
    const b = flightOffer({ id: 'b', providerId: 'provider-b', price: 100 });
    const a = flightOffer({ id: 'a', providerId: 'provider-a', price: 100 });

    const first = group(
      { providerId: 'provider-b', offers: [b] },
      { providerId: 'provider-a', offers: [a] },
    );
    const second = group(
      { providerId: 'provider-a', offers: [a] },
      { providerId: 'provider-b', offers: [b] },
    );

    expect(first.results[0].offers.map((offer: any) => offer.id)).toEqual(['a', 'b']);
    expect(second.results[0].offers.map((offer: any) => offer.id)).toEqual(['a', 'b']);
  });

  it('drops invalid offers and counts them without inventing replacements', () => {
    const valid = flightOffer({ id: 'valid' });
    const noPrice = flightOffer({ id: 'no-price', price: 0 });
    const noCurrency = flightOffer({ id: 'no-currency', currency: '' });
    const noTimes = flightOffer({
      id: 'no-times',
      segments: [segment({ departureAt: null })],
    });
    const noId = flightOffer({ id: '' });

    const result = group({
      providerId: 'duffel-flight',
      offers: [valid, noPrice, noCurrency, noTimes, noId],
    });

    expect(result.results).toHaveLength(1);
    expect(result.results[0].id).toBe('valid');
    expect(result.invalidOffersDropped).toBe(4);
    expect(result.duplicatesDropped).toBe(0);
  });

  it('gives an unprovable itinerary its own row instead of merging it', () => {
    const unprovableA = flightOffer({
      id: 'unprovable-a',
      segments: [
        segment({ marketingFlightNumber: '', operatingFlightNumber: '' }),
      ],
    });
    const unprovableB = flightOffer({
      id: 'unprovable-b',
      segments: [
        segment({ marketingFlightNumber: '', operatingFlightNumber: '' }),
      ],
    });

    const result = group({
      providerId: 'duffel-flight',
      offers: [unprovableA, unprovableB],
    });
    expect(result.results).toHaveLength(2);
    expect(result.results.map((row: any) => row.id)).toEqual([
      'unprovable-a',
      'unprovable-b',
    ]);
  });

  it('falls back to the top-level route/time only for a conservative single-segment identity', () => {
    const legacyA = {
      id: 'legacy-a',
      type: 'flight',
      providerId: 'provider-a',
      providerName: 'Provider A',
      title: 'CAI → DXB',
      price: 100,
      currency: 'USD',
      airline: 'EgyptAir',
      flightNumber: '985',
      origin: 'CAI',
      destination: 'DXB',
      departureTime: '2026-10-01T08:00:00',
      arrivalTime: '2026-10-01T12:30:00',
    };
    const legacyB = {
      ...legacyA,
      id: 'legacy-b',
      providerId: 'provider-b',
      providerName: 'Provider B',
      price: 90,
    };

    const result = group(
      { providerId: 'provider-a', offers: [legacyA] },
      { providerId: 'provider-b', offers: [legacyB] },
    );
    expect(result.results).toHaveLength(1);
    expect(result.results[0].offers).toHaveLength(2);
  });
});

// ── Duffel mapper ─────────────────────────────────────────────────────────

function duffelSegment(overrides: Record<string, any> = {}) {
  return {
    origin: { iata_code: 'CAI' },
    destination: { iata_code: 'IST' },
    departing_at: '2026-10-01T08:00:00',
    arriving_at: '2026-10-01T10:15:00',
    marketing_carrier: { iata_code: 'MS', name: 'EgyptAir' },
    operating_carrier: { iata_code: 'MS', name: 'EgyptAir' },
    marketing_carrier_flight_number: '985',
    operating_carrier_flight_number: '985',
    aircraft: { name: 'Airbus A320neo' },
    duration: 'PT2H15M',
    stops: [],
    passengers: [
      {
        cabin_class: 'economy',
        cabin_class_marketing_name: 'Economy',
        fare_basis_code: 'Y',
        baggages: [
          { type: 'carry_on', quantity: 1 },
          { type: 'checked', quantity: 1 },
        ],
      },
    ],
    ...overrides,
  };
}

function duffelOffer(overrides: Record<string, any> = {}) {
  return {
    id: 'off_duffel_123',
    total_amount: '542.30',
    total_currency: 'USD',
    owner: { name: 'EgyptAir' },
    expires_at: '2026-10-01T12:00:00Z',
    conditions: {
      refund_before_departure: {
        allowed: true,
        penalty_amount: '50.00',
        penalty_currency: 'USD',
      },
      change_before_departure: {
        allowed: false,
        penalty_amount: null,
        penalty_currency: null,
      },
    },
    slices: [
      {
        comparison_key: 'slice-key-1',
        fare_brand_name: 'Economy Standard',
        duration: 'PT7H30M',
        origin: { iata_code: 'CAI' },
        destination: { iata_code: 'DXB' },
        segments: [
          duffelSegment(),
          duffelSegment({
            origin: { iata_code: 'IST' },
            destination: { iata_code: 'DXB' },
            departing_at: '2026-10-01T12:00:00',
            arriving_at: '2026-10-01T16:30:00',
            marketing_carrier: { iata_code: 'TK', name: 'Turkish Airlines' },
            operating_carrier: { iata_code: 'TK', name: 'Turkish Airlines' },
            marketing_carrier_flight_number: '760',
            operating_carrier_flight_number: '760',
            aircraft: { iata_code: '77W' },
            duration: 'PT3H30M',
            stops: [{ iata_code: 'ADB' }],
            passengers: [
              {
                cabin_class: 'economy',
                cabin_class_marketing_name: 'Economy',
                fare_basis_code: 'Y',
                baggages: [{ type: 'carry_on', quantity: 1 }],
              },
            ],
          }),
        ],
      },
    ],
    ...overrides,
  };
}

describe('Duffel offer mapper (documented Offers contract)', () => {
  it('maps ordered segments, both carriers, baggage, conditions and stop counts', () => {
    const mapped = mapDuffelOffer(
      duffelOffer(),
      'duffel-flight',
      'Duffel Flight Provider',
    );

    expect(mapped).not.toBeNull();
    expect(mapped.id).toBe('off_duffel_123');
    expect(mapped.type).toBe('flight');
    expect(mapped.providerId).toBe('duffel-flight');
    expect(mapped.price).toBe(542.3);
    expect(mapped.currency).toBe('USD');
    expect(mapped.origin).toBe('CAI');
    expect(mapped.destination).toBe('DXB');
    expect(mapped.departureTime).toBe('2026-10-01T08:00:00');
    expect(mapped.arrivalTime).toBe('2026-10-01T16:30:00');
    expect(mapped.airline).toBe('EgyptAir');
    expect(mapped.flightNumber).toBe('MS985');
    expect(mapped.stops).toBe(2); // 1 connection + 1 technical stop
    expect(mapped.title).toBe('CAI → DXB');

    expect(mapped.segments).toHaveLength(2);
    const [first, second] = mapped.segments;
    expect(first.sliceIndex).toBe(0);
    expect(first.segmentIndex).toBe(0);
    expect(first.origin).toBe('CAI');
    expect(first.destination).toBe('IST');
    expect(first.marketingCarrier).toEqual({
      code: 'MS',
      name: 'EgyptAir',
    });
    expect(first.operatingCarrier).toEqual({
      code: 'MS',
      name: 'EgyptAir',
    });
    expect(first.marketingFlightNumber).toBe('985');
    expect(first.operatingFlightNumber).toBe('985');
    expect(first.stopCount).toBe(0);
    expect(first.cabinClass).toBe('economy');
    expect(first.cabinClassMarketingName).toBe('Economy');
    expect(first.fareBasisCode).toBe('Y');
    expect(first.aircraft).toBe('Airbus A320neo');
    expect(first.duration).toBe('PT2H15M');
    expect(first.baggage).toEqual([
      { type: 'carry_on', quantity: 1 },
      { type: 'checked', quantity: 1 },
    ]);

    expect(second.origin).toBe('IST');
    expect(second.destination).toBe('DXB');
    expect(second.marketingCarrier.code).toBe('TK');
    expect(second.marketingFlightNumber).toBe('760');
    expect(second.stopCount).toBe(1);
    expect(second.aircraft).toBe('77W');
    expect(second.baggage).toEqual([{ type: 'carry_on', quantity: 1 }]);

    // Offer-level baggage is the minimum every segment guarantees: the
    // second segment has no checked bag, so the offer cannot claim one.
    expect(mapped.baggageAllowances).toEqual([
      { type: 'carry_on', quantity: 1 },
    ]);
    expect(mapped.metadata.baggage).toEqual({
      type: 'carry_on',
      quantity: 1,
    });

    expect(mapped.conditions.refundBeforeDeparture).toEqual({
      allowed: true,
      penaltyAmount: 50,
      penaltyCurrency: 'USD',
    });
    expect(mapped.conditions.changeBeforeDeparture).toEqual({
      allowed: false,
      penaltyAmount: null,
      penaltyCurrency: null,
    });
    expect(mapped.metadata.refundable).toBe(true);
    expect(mapped.metadata.changeable).toBe(false);

    expect(mapped.cabinClass).toBe('economy');
    expect(mapped.fareBrand).toBe('Economy Standard');
    expect(mapped.metadata.fareFamily).toBe('Economy Standard');
    expect(mapped.metadata.comparisonKey).toBe('slice-key-1');
    expect(mapped.metadata.stopAirport).toBe('IST');
    expect(mapped.metadata.connectionAirports).toEqual(['IST']);
    expect(mapped.metadata.technicalStops).toBe(1);
    expect(mapped.validUntil).toBe('2026-10-01T12:00:00Z');
    expect(mapped.metadata.expiresAt).toBe('2026-10-01T12:00:00Z');
    expect(mapped.metadata.providerOfferId).toBe('off_duffel_123');
  });

  it('keeps marketing and operating carriers distinct on a codeshare', () => {
    const mapped = mapDuffelOffer(
      duffelOffer({
        slices: [
          {
            comparison_key: 'codeshare-slice',
            fare_brand_name: 'Economy',
            segments: [
              duffelSegment({
                marketing_carrier: { iata_code: 'BA', name: 'British Airways' },
                operating_carrier: {
                  iata_code: 'AA',
                  name: 'American Airlines',
                },
                marketing_carrier_flight_number: '123',
                operating_carrier_flight_number: '456',
              }),
            ],
          },
        ],
      }),
      'duffel-flight',
      'Duffel Flight Provider',
    );

    expect(mapped.airline).toBe('British Airways');
    expect(mapped.flightNumber).toBe('BA123');
    expect(mapped.segments[0].marketingCarrier.code).toBe('BA');
    expect(mapped.segments[0].operatingCarrier.code).toBe('AA');
    expect(mapped.segments[0].marketingFlightNumber).toBe('123');
    expect(mapped.segments[0].operatingFlightNumber).toBe('456');
  });

  it('uses offer-level conditions as authoritative, then slice conditions only when every slice agrees', () => {
    const offerLevelWins = mapDuffelOffer(
      duffelOffer({
        conditions: {
          refund_before_departure: {
            allowed: true,
            penalty_amount: '10.00',
            penalty_currency: 'USD',
          },
        },
        slices: [
          {
            conditions: {
              refund_before_departure: {
                allowed: false,
                penalty_amount: null,
                penalty_currency: null,
              },
            },
            segments: [duffelSegment()],
          },
        ],
      }),
      'duffel-flight',
      'Duffel Flight Provider',
    );
    expect(offerLevelWins.conditions.refundBeforeDeparture.allowed).toBe(true);

    const allSlicesAgree = mapDuffelOffer(
      duffelOffer({
        conditions: undefined,
        slices: [
          {
            conditions: {
              refund_before_departure: {
                allowed: true,
                penalty_amount: '10.00',
                penalty_currency: 'USD',
              },
            },
            segments: [duffelSegment()],
          },
          {
            conditions: {
              refund_before_departure: {
                allowed: true,
                penalty_amount: '10.00',
                penalty_currency: 'USD',
              },
            },
            segments: [duffelSegment({ origin: { iata_code: 'DXB' } })],
          },
        ],
      }),
      'duffel-flight',
      'Duffel Flight Provider',
    );
    expect(allSlicesAgree.conditions.refundBeforeDeparture).toEqual({
      allowed: true,
      penaltyAmount: 10,
      penaltyCurrency: 'USD',
    });

    const slicesDisagree = mapDuffelOffer(
      duffelOffer({
        conditions: undefined,
        slices: [
          {
            conditions: {
              refund_before_departure: {
                allowed: true,
                penalty_amount: '10.00',
                penalty_currency: 'USD',
              },
            },
            segments: [duffelSegment()],
          },
          {
            conditions: {
              refund_before_departure: {
                allowed: false,
                penalty_amount: null,
                penalty_currency: null,
              },
            },
            segments: [duffelSegment({ origin: { iata_code: 'DXB' } })],
          },
        ],
      }),
      'duffel-flight',
      'Duffel Flight Provider',
    );
    // Unknown, not "not allowed": no single slice speaks for the itinerary.
    expect(slicesDisagree.conditions).toBeUndefined();
    expect(slicesDisagree.metadata.refundable).toBeUndefined();
  });

  it('leaves baggage unknown when a segment did not state it, and treats [] as known none', () => {
    const unknown = mapDuffelOffer(
      duffelOffer({
        slices: [
          {
            fare_brand_name: 'Economy',
            segments: [
              duffelSegment({
                passengers: [{ cabin_class: 'economy' }],
              }),
            ],
          },
        ],
      }),
      'duffel-flight',
      'Duffel Flight Provider',
    );
    expect(unknown.baggageAllowances).toEqual([]);
    expect(unknown.segments[0].baggage).toEqual([]);
    expect(unknown.metadata.baggage).toBeUndefined();

    const knownNone = mapDuffelOffer(
      duffelOffer({
        slices: [
          {
            fare_brand_name: 'Economy',
            segments: [
              duffelSegment({
                passengers: [
                  { cabin_class: 'economy', baggages: [] },
                ],
              }),
            ],
          },
        ],
      }),
      'duffel-flight',
      'Duffel Flight Provider',
    );
    expect(knownNone.baggageAllowances).toEqual([]);
    expect(knownNone.segments[0].baggage).toEqual([]);
    expect(knownNone.metadata.baggage).toBeUndefined();
  });

  it('does not invent a single cabin or fare brand when legs differ', () => {
    const mixed = mapDuffelOffer(
      duffelOffer({
        slices: [
          {
            fare_brand_name: 'Economy Standard',
            origin: { iata_code: 'CAI' },
            destination: { iata_code: 'DXB' },
            segments: [
              duffelSegment({
                passengers: [
                  {
                    cabin_class: 'economy',
                    baggages: [{ type: 'carry_on', quantity: 1 }],
                  },
                ],
              }),
            ],
          },
          {
            fare_brand_name: 'Business Flex',
            origin: { iata_code: 'DXB' },
            destination: { iata_code: 'CAI' },
            segments: [
              duffelSegment({
                origin: { iata_code: 'DXB' },
                destination: { iata_code: 'CAI' },
                passengers: [
                  {
                    cabin_class: 'business',
                    baggages: [{ type: 'carry_on', quantity: 2 }],
                  },
                ],
              }),
            ],
          },
        ],
      }),
      'duffel-flight',
      'Duffel Flight Provider',
    );

    expect(mixed.title).toBe('CAI → DXB → CAI');
    expect(mixed.origin).toBe('CAI');
    expect(mixed.destination).toBe('CAI');
    expect(mixed.cabinClass).toBeUndefined();
    expect(mixed.metadata.mixedCabin).toBe(true);
    expect(mixed.fareBrand).toBeUndefined();
    expect(mixed.metadata.fareFamily).toBeUndefined();
    expect(mixed.metadata.sliceFareBrands).toEqual([
      'Economy Standard',
      'Business Flex',
    ]);
    expect(mixed.segments.map((entry: any) => entry.sliceIndex)).toEqual([0, 1]);
  });

  it('drops an offer with missing id, price, currency, slices or segment times', () => {
    expect(
      mapDuffelOffer(duffelOffer({ id: undefined }), 'duffel-flight', 'Duffel'),
    ).toBeNull();
    expect(
      mapDuffelOffer(duffelOffer({ total_amount: '0' }), 'duffel-flight', 'Duffel'),
    ).toBeNull();
    expect(
      mapDuffelOffer(duffelOffer({ total_currency: '' }), 'duffel-flight', 'Duffel'),
    ).toBeNull();
    expect(
      mapDuffelOffer(duffelOffer({ slices: [] }), 'duffel-flight', 'Duffel'),
    ).toBeNull();
    expect(
      mapDuffelOffer(
        duffelOffer({
          slices: [
            {
              segments: [duffelSegment({ departing_at: null })],
            },
          ],
        }),
        'duffel-flight',
        'Duffel',
      ),
    ).toBeNull();
  });

  it('never fabricates an expiry or an airline', () => {
    const noExpiry = mapDuffelOffer(
      duffelOffer({
        expires_at: undefined,
        owner: undefined,
        slices: [
          {
            segments: [
              duffelSegment({
                marketing_carrier: { iata_code: 'MS', name: '' },
                operating_carrier: { iata_code: 'MS', name: '' },
              }),
            ],
          },
        ],
      }),
      'duffel-flight',
      'Duffel Flight Provider',
    );
    expect(noExpiry.validUntil).toBeUndefined();
    expect(noExpiry.metadata.expiresAt).toBeUndefined();
    expect(noExpiry.airline).toBe('');
  });
});

// ── Nuitee mapper ─────────────────────────────────────────────────────────

const nuiteeService = new NuiteeFlightService({
  get: (name: string) =>
    name === 'NUITEE_API_KEY' ? 'sand_test_key' : undefined,
} as any);

function nuiteeJourney(overrides: Record<string, any> = {}) {
  return {
    journeyKey: 'journey-hash-1',
    totalDuration: { iso8601: 'PT7H45M', minutes: 465 },
    connections: [
      {
        arrivalAirportCode: 'IST',
        departureAirportCode: 'IST',
        duration: { iso8601: 'PT1H45M' },
      },
    ],
    segments: [
      {
        segmentKey: 'seg-1',
        originCode: 'CAI',
        destinationCode: 'IST',
        departureTime: '2026-10-01T08:00:00',
        arrivalTime: '2026-10-01T10:15:00',
        direction: 'OUTBOUND',
        stopCount: 0,
        duration: { iso8601: 'PT2H15M' },
        carrier: {
          marketingCode: 'MS',
          marketingName: 'EgyptAir',
          operatingCode: 'MS',
          operatingName: 'EgyptAir',
        },
        flight: { marketingNumber: '985', operatingNumber: '985' },
      },
      {
        segmentKey: 'seg-2',
        originCode: 'IST',
        destinationCode: 'DXB',
        departureTime: '2026-10-01T12:00:00',
        arrivalTime: '2026-10-01T16:30:00',
        direction: 'OUTBOUND',
        stopCount: 0,
        duration: { iso8601: 'PT3H30M' },
        carrier: {
          marketingCode: 'TK',
          marketingName: 'Turkish Airlines',
          operatingCode: 'TK',
          operatingName: 'Turkish Airlines',
        },
        flight: { marketingNumber: '760', operatingNumber: '760' },
      },
    ],
    offers: [],
    ...overrides,
  };
}

function nuiteeOffer(overrides: Record<string, any> = {}) {
  return {
    offerId: 'nt_offer_123',
    expiration: '2026-10-01T12:00:00Z',
    searchId: 'search-abc',
    pricing: {
      display: {
        base: '400.00',
        taxes: '100.00',
        fees: '0.00',
        total: '500.00',
        currency: 'USD',
      },
    },
    fare: {
      family: 'Economy Flex',
      mixedCabin: false,
      mixedFareFamily: false,
      seatsRemaining: 4,
    },
    terms: {
      refundable: true,
      changeable: true,
      hasRefundFee: true,
      hasChangeFee: true,
      refundFee: {
        pricing: { display: { amount: 50, currency: 'USD' } },
      },
      changeFee: {
        pricing: { display: { amount: 25, currency: 'USD' } },
      },
      summary: [{ level: 'warning', message: 'Fare is non-transferable' }],
    },
    baggage: {
      included: [
        {
          bagType: 'cabin',
          pieces: 1,
          weightKg: 7,
          description: 'Cabin bag',
          passengerType: 'ADT',
        },
        {
          bagType: 'checked',
          pieces: 1,
          weightKg: 23,
          description: 'Checked bag',
          passengerType: 'ADT',
        },
      ],
    },
    segmentFares: [
      { segmentKey: 'seg-2', cabin: 'economy', fareBasisCode: 'Y' },
      { segmentKey: 'seg-1', cabin: 'economy', fareBasisCode: 'Y' },
    ],
    segmentAmenities: [
      { segmentKey: 'seg-2', aircraftType: 'Boeing 737' },
      { segmentKey: 'seg-1', aircraftType: 'Airbus A320' },
    ],
    ...overrides,
  };
}

describe('Nuitee offer mapper (documented v3.0 flights contract)', () => {
  it('maps ordered segments, carriers, fare facts, baggage and terms', () => {
    const mapped = nuiteeService.mapOffer(
      nuiteeOffer(),
      nuiteeJourney(),
      { origin: 'CAI', destination: 'DXB' },
    );

    expect(mapped).not.toBeNull();
    expect(mapped.id).toBe('nt_offer_123');
    expect(mapped.type).toBe('flight');
    expect(mapped.providerId).toBe('nuitee-flight');
    expect(mapped.price).toBe(500);
    expect(mapped.currency).toBe('USD');
    expect(mapped.origin).toBe('CAI');
    expect(mapped.destination).toBe('DXB');
    expect(mapped.departureTime).toBe('2026-10-01T08:00:00');
    expect(mapped.arrivalTime).toBe('2026-10-01T16:30:00');
    expect(mapped.airline).toBe('EgyptAir');
    expect(mapped.flightNumber).toBe('MS985');
    expect(mapped.title).toBe('CAI → DXB');
    expect(mapped.stops).toBe(1); // one documented connection
    expect(mapped.duration).toBe('PT7H45M');

    expect(mapped.segments).toHaveLength(2);
    const [first, second] = mapped.segments;
    expect(first.sliceIndex).toBe(0);
    expect(first.segmentIndex).toBe(0);
    expect(first.segmentKey).toBe('seg-1');
    expect(first.marketingCarrier).toEqual({
      code: 'MS',
      name: 'EgyptAir',
    });
    expect(first.operatingCarrier).toEqual({
      code: 'MS',
      name: 'EgyptAir',
    });
    expect(first.marketingFlightNumber).toBe('985');
    expect(first.operatingFlightNumber).toBe('985');
    expect(first.stopCount).toBe(0);
    expect(first.cabinClass).toBe('economy');
    expect(first.fareBasisCode).toBe('Y');
    expect(first.aircraft).toBe('Airbus A320');
    expect(first.duration).toBe('PT2H15M');
    expect(second.segmentKey).toBe('seg-2');
    expect(second.marketingCarrier.code).toBe('TK');
    expect(second.aircraft).toBe('Boeing 737');

    expect(mapped.fareBrand).toBe('Economy Flex');
    expect(mapped.metadata.fareFamily).toBe('Economy Flex');
    expect(mapped.metadata.mixedFareFamily).toBeUndefined();
    expect(mapped.metadata.seatsLeft).toBe(4);
    expect(mapped.metadata.journeyKey).toBe('journey-hash-1');
    expect(mapped.metadata.searchId).toBe('search-abc');
    expect(mapped.metadata.stopAirport).toBe('IST');
    expect(mapped.metadata.connectionAirports).toEqual(['IST']);
    expect(mapped.metadata.termsSummary).toEqual([
      { level: 'warning', message: 'Fare is non-transferable' },
    ]);

    expect(mapped.conditions.refundBeforeDeparture).toEqual({
      allowed: true,
      penaltyAmount: 50,
      penaltyCurrency: 'USD',
      feeApplies: true,
    });
    expect(mapped.conditions.changeBeforeDeparture).toEqual({
      allowed: true,
      penaltyAmount: 25,
      penaltyCurrency: 'USD',
      feeApplies: true,
    });
    expect(mapped.metadata.refundable).toBe(true);
    expect(mapped.metadata.changeable).toBe(true);

    expect(mapped.baggageAllowances).toEqual([
      {
        type: 'cabin',
        quantity: 1,
        weightKg: 7,
        description: 'Cabin bag',
        passengerType: 'ADT',
      },
      {
        type: 'checked',
        quantity: 1,
        weightKg: 23,
        description: 'Checked bag',
        passengerType: 'ADT',
      },
    ]);
    expect(mapped.metadata.baggage).toEqual({ type: 'cabin', quantity: 1 });

    expect(mapped.validUntil).toBe('2026-10-01T12:00:00Z');
    expect(mapped.metadata.expiresAt).toBe('2026-10-01T12:00:00Z');
    expect(mapped.metadata.providerOfferId).toBe('nt_offer_123');
  });

  it('maps a round trip to ordered legs without inventing a one-way route', () => {
    const journey = nuiteeJourney({
      connections: [],
      segments: [
        {
          segmentKey: 'out-1',
          originCode: 'JFK',
          destinationCode: 'CDG',
          departureTime: '2026-10-01T18:00:00',
          arrivalTime: '2026-10-02T07:30:00',
          direction: 'OUTBOUND',
          carrier: {
            marketingCode: 'DE',
            marketingName: 'Condor',
            operatingCode: 'DE',
            operatingName: 'Condor',
          },
          flight: { marketingNumber: '2017', operatingNumber: '2017' },
        },
        {
          segmentKey: 'in-1',
          originCode: 'CDG',
          destinationCode: 'JFK',
          departureTime: '2026-10-08T10:00:00',
          arrivalTime: '2026-10-08T12:45:00',
          direction: 'INBOUND',
          carrier: {
            marketingCode: 'DE',
            marketingName: 'Condor',
            operatingCode: 'DE',
            operatingName: 'Condor',
          },
          flight: { marketingNumber: '2018', operatingNumber: '2018' },
        },
      ],
    });

    const mapped = nuiteeService.mapOffer(nuiteeOffer(), journey, {
      origin: 'JFK',
      destination: 'CDG',
    });

    expect(mapped.title).toBe('JFK → CDG → JFK');
    expect(mapped.origin).toBe('JFK');
    expect(mapped.destination).toBe('JFK');
    expect(mapped.segments.map((entry: any) => entry.sliceIndex)).toEqual([0, 1]);
    expect(mapped.stops).toBe(0);
  });

  it('keeps marketing and operating carriers distinct on a codeshare', () => {
    const journey = nuiteeJourney({
      connections: [],
      segments: [
        {
          segmentKey: 'codeshare',
          originCode: 'CAI',
          destinationCode: 'DXB',
          departureTime: '2026-10-01T08:00:00',
          arrivalTime: '2026-10-01T12:30:00',
          carrier: {
            marketingCode: 'MS',
            marketingName: 'EgyptAir',
            operatingCode: 'XY',
            operatingName: 'Sky Express',
          },
          flight: { marketingNumber: '985', operatingNumber: '777' },
        },
      ],
    });

    const mapped = nuiteeService.mapOffer(nuiteeOffer(), journey, {
      origin: 'CAI',
      destination: 'DXB',
    });
    expect(mapped.airline).toBe('EgyptAir');
    expect(mapped.flightNumber).toBe('MS985');
    expect(mapped.segments[0].marketingCarrier.code).toBe('MS');
    expect(mapped.segments[0].operatingCarrier.code).toBe('XY');
    expect(mapped.segments[0].marketingFlightNumber).toBe('985');
    expect(mapped.segments[0].operatingFlightNumber).toBe('777');
  });

  it('does not invent a fare brand, cabin or refund status when the provider is silent', () => {
    const mapped = nuiteeService.mapOffer(
      nuiteeOffer({
        fare: { seatsRemaining: 2 },
        terms: {},
        baggage: undefined,
        segmentFares: [],
        segmentAmenities: [],
      }),
      nuiteeJourney(),
      { origin: 'CAI', destination: 'DXB' },
    );

    expect(mapped.fareBrand).toBeUndefined();
    expect(mapped.metadata.fareFamily).toBeUndefined();
    expect(mapped.cabinClass).toBeUndefined();
    expect(mapped.conditions).toBeUndefined();
    expect(mapped.metadata.refundable).toBeUndefined();
    expect(mapped.metadata.changeable).toBeUndefined();
    expect(mapped.baggageAllowances).toEqual([]);
    expect(mapped.metadata.baggage).toBeUndefined();
    expect(mapped.segments[0].cabinClass).toBeNull();
    expect(mapped.segments[0].aircraft).toBeNull();
  });

  it('keeps weight-only baggage as weight, not a fabricated piece count', () => {
    const mapped = nuiteeService.mapOffer(
      nuiteeOffer({
        baggage: {
          included: [
            { bagType: 'checked', weightKg: 23, passengerType: 'ADT' },
          ],
        },
      }),
      nuiteeJourney(),
      { origin: 'CAI', destination: 'DXB' },
    );

    expect(mapped.baggageAllowances).toEqual([
      { type: 'checked', quantity: null, weightKg: 23, passengerType: 'ADT' },
    ]);
    // A weight-only allowance is not a piece count, so the legacy piece
    // summary must stay absent.
    expect(mapped.metadata.baggage).toBeUndefined();
  });

  it('honours mixedCabin/mixedFareFamily flags instead of choosing one leg', () => {
    const mapped = nuiteeService.mapOffer(
      nuiteeOffer({
        fare: {
          family: 'Economy Flex',
          mixedCabin: true,
          mixedFareFamily: true,
          seatsRemaining: 1,
        },
      }),
      nuiteeJourney(),
      { origin: 'CAI', destination: 'DXB' },
    );

    expect(mapped.fareBrand).toBeUndefined();
    expect(mapped.metadata.fareFamily).toBe('Economy Flex');
    expect(mapped.metadata.mixedFareFamily).toBe(true);
    expect(mapped.metadata.mixedCabin).toBe(true);
  });

  it('never fabricates an expiry when the offer did not state one', () => {
    const mapped = nuiteeService.mapOffer(
      nuiteeOffer({ expiration: undefined }),
      nuiteeJourney(),
      { origin: 'CAI', destination: 'DXB' },
    );
    expect(mapped.validUntil).toBeUndefined();
    expect(mapped.metadata.expiresAt).toBeUndefined();
  });

  it('drops an offer with missing id, price, currency, segments or segment times', () => {
    expect(
      nuiteeService.mapOffer(nuiteeOffer({ offerId: undefined }), nuiteeJourney(), {
        origin: 'CAI',
        destination: 'DXB',
      }),
    ).toBeNull();
    expect(
      nuiteeService.mapOffer(
        nuiteeOffer({ pricing: { display: { total: 0, currency: 'USD' } } }),
        nuiteeJourney(),
        { origin: 'CAI', destination: 'DXB' },
      ),
    ).toBeNull();
    expect(
      nuiteeService.mapOffer(
        nuiteeOffer({ pricing: { display: { total: 100 } } }),
        nuiteeJourney(),
        { origin: 'CAI', destination: 'DXB' },
      ),
    ).toBeNull();
    expect(
      nuiteeService.mapOffer(nuiteeOffer(), nuiteeJourney({ segments: [] }), {
        origin: 'CAI',
        destination: 'DXB',
      }),
    ).toBeNull();

    const brokenJourney = nuiteeJourney();
    brokenJourney.segments[1] = {
      ...brokenJourney.segments[1],
      arrivalTime: '',
    };
    expect(
      nuiteeService.mapOffer(nuiteeOffer(), brokenJourney, {
        origin: 'CAI',
        destination: 'DXB',
      }),
    ).toBeNull();
  });
});
