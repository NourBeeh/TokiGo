import {
  HomeFlightsService,
  MAX_MOOD_CITIES,
  MOOD_FLIGHTS_TTL_SECONDS,
  TRAVEL_MOODS,
} from '../src/modules/home/home.flights.service';

/**
 * Phase 2 — GET /home/flights-for-mood.
 *
 * The rail must be built from LIVE Duffel offers only. Contracts pinned here:
 * - the origin is the curated primary airport of the traveller's country;
 * - destinations are the published cards whose AUTHORED `metadata.moods`
 *   contains the requested mood (never a keyword guess), at most three;
 * - only the cheapest real, bookable offer per city is returned;
 * - `seatsLeft` is the provider's own count and is absent when Duffel did not
 *   send it — never invented;
 * - a provider failure drops that city (honest shorter list, never a fake
 *   fare), and an empty result is not cached;
 * - a successful non-empty payload is cached for 10 minutes.
 */

function destination(title: string, moods: unknown) {
  return {
    id: `card-${title}`,
    type: 'destination',
    title,
    metadata: moods === undefined ? { country: 'Egypt' } : { moods },
  };
}

function fakeHome(cards: any[]) {
  return {
    getSections: jest.fn().mockResolvedValue([{ id: 'discover', cards }]),
  } as any;
}

function offer(overrides: Record<string, any> = {}) {
  return {
    id: 'off-1',
    type: 'flight',
    providerId: 'duffel-flight',
    providerName: 'Duffel Flight Provider',
    title: 'CAI → HRG',
    subtitle: 'Air Cairo',
    origin: 'CAI',
    destination: 'HRG',
    departureTime: '2026-11-05T08:00:00',
    arrivalTime: '2026-11-05T09:00:00',
    airline: 'Air Cairo',
    flightNumber: 'SM 1',
    price: 120,
    currency: 'USD',
    duration: 'PT1H',
    stops: 0,
    metadata: {
      providerOfferId: 'off-1',
      retrievedAt: '2026-10-22T00:00:00.000Z',
    },
    ...overrides,
  };
}

function fakeDuffel(results: Record<string, any[] | Error>) {
  return {
    searchFlights: jest.fn(async (params: any) => {
      const value = results[params.destination];
      if (value instanceof Error) {
        return {
          success: false,
          providerId: 'duffel-flight',
          providerName: 'Duffel Flight Provider',
          data: [],
          error: value.message,
          timestamp: new Date(),
        };
      }
      return {
        success: true,
        providerId: 'duffel-flight',
        providerName: 'Duffel Flight Provider',
        data: value ?? [],
        timestamp: new Date(),
      };
    }),
  } as any;
}

function fakeCache() {
  const store = new Map<string, any>();
  const sets: Array<{ key: string; ttl?: number }> = [];
  return {
    sets,
    cache: {
      get: jest.fn(async (key: string) => store.get(key) ?? null),
      set: jest.fn(async (key: string, value: any, ttl?: number) => {
        sets.push({ key, ttl });
        store.set(key, value);
      }),
      delete: jest.fn(async () => undefined),
      invalidate: jest.fn(async () => undefined),
    } as any,
  };
}

function service(cards: any[], results: Record<string, any[] | Error> = {}) {
  const home = fakeHome(cards);
  const duffel = fakeDuffel(results);
  const { cache, sets } = fakeCache();
  return {
    home,
    duffel,
    cache,
    sets,
    subject: new HomeFlightsService(home, duffel, cache),
  };
}

describe('HomeFlightsService — mood flight rail', () => {
  it('uses the agreed ten-minute cache window', () => {
    expect(MOOD_FLIGHTS_TTL_SECONDS).toBe(10 * 60);
  });

  it('searches the suggested origin for the mood-tagged city only', async () => {
    const { subject, duffel } = service(
      [
        destination('Hurghada', ['beach']),
        destination('Cairo', ['city']),
      ],
      { HRG: [offer()] },
    );

    const payload = await subject.getFlightsForMood({
      country: 'EG',
      mood: 'beach',
    });

    expect(duffel.searchFlights).toHaveBeenCalledTimes(1);
    expect(duffel.searchFlights).toHaveBeenCalledWith(
      expect.objectContaining({
        origin: 'CAI',
        destination: 'HRG',
        passengers: 1,
      }),
    );
    expect(payload.origin).toBe('CAI');
    expect(payload.originCountryCode).toBe('EG');
    expect(payload.mood).toBe('beach');
    expect(payload.flights).toHaveLength(1);
    expect(payload.flights[0]).toMatchObject({
      id: 'off-1',
      type: 'flight',
      title: 'CAI → HRG',
      price: 120,
      currency: 'USD',
      metadata: expect.objectContaining({
        destinationCity: 'Hurghada',
        originCountryCode: 'EG',
        providerId: 'duffel-flight',
        travelMood: 'beach',
      }),
    });
  });

  it('never guesses a mood from the city name', async () => {
    const { subject, duffel } = service(
      [destination('Cairo', undefined), destination('Beach Town', undefined)],
      {},
    );

    const payload = await subject.getFlightsForMood({
      country: 'EG',
      mood: 'beach',
    });

    expect(duffel.searchFlights).not.toHaveBeenCalled();
    expect(payload.flights).toEqual([]);
  });

  it('returns the cheapest real offer and skips sold-out and invalid fares', async () => {
    const { subject } = service([destination('Hurghada', ['beach'])], {
      HRG: [
        offer({ id: 'expensive', price: 300 }),
        offer({ id: 'sold-out', price: 90, metadata: { seatsLeft: 0 } }),
        offer({ id: 'invalid', price: 0 }),
        offer({ id: 'best', price: 120, metadata: { seatsLeft: 4 } }),
      ],
    });

    const payload = await subject.getFlightsForMood({
      country: 'EG',
      mood: 'beach',
    });

    expect(payload.flights.map((flight) => flight.id)).toEqual(['best']);
    expect(payload.flights[0].metadata.seatsLeft).toBe(4);
  });

  it('sorts returned city fares by ascending real price', async () => {
    const { subject } = service(
      [
        destination('Hurghada', ['beach']),
        destination('Sharm El Sheikh', ['beach']),
      ],
      {
        HRG: [offer({ id: 'hrg', price: 167.42 })],
        SSH: [offer({ id: 'ssh', price: 42.53 })],
      },
    );

    const payload = await subject.getFlightsForMood({
      country: 'EG',
      mood: 'beach',
    });

    expect(payload.flights.map((flight) => flight.price)).toEqual([42.53, 167.42]);
  });

  it('carries seatsLeft only when Duffel sent a count', async () => {
    const { subject } = service([destination('Hurghada', ['beach'])], {
      HRG: [offer()],
    });

    const payload = await subject.getFlightsForMood({
      country: 'EG',
      mood: 'beach',
    });

    expect(payload.flights[0].metadata).not.toHaveProperty('seatsLeft');
  });

  it('drops a failing city instead of inventing a fare', async () => {
    const { subject, sets } = service(
      [
        destination('Hurghada', ['beach']),
        destination('Sharm El Sheikh', ['beach']),
      ],
      {
        HRG: [offer()],
        SSH: new Error('provider down'),
      },
    );

    const payload = await subject.getFlightsForMood({
      country: 'EG',
      mood: 'beach',
    });

    expect(payload.flights).toHaveLength(1);
    expect(payload.flights[0].metadata.destinationCity).toBe('Hurghada');
    expect(sets).toEqual([
      {
        key: expect.stringContaining('home:flights:EG:beach'),
        ttl: MOOD_FLIGHTS_TTL_SECONDS,
      },
    ]);
  });

  it('does not cache an empty result so an outage can recover', async () => {
    const { subject, sets } = service(
      [destination('Hurghada', ['beach'])],
      { HRG: new Error('provider down') },
    );

    const payload = await subject.getFlightsForMood({
      country: 'EG',
      mood: 'beach',
    });

    expect(payload.flights).toEqual([]);
    expect(sets).toEqual([]);
  });

  it('serves a cached snapshot without calling the provider again', async () => {
    const { subject, duffel, cache } = service(
      [destination('Hurghada', ['beach'])],
      { HRG: [offer()] },
    );
    // The cache was created inside `service`; warm it through the first call.
    await subject.getFlightsForMood({ country: 'EG', mood: 'beach' });
    expect(duffel.searchFlights).toHaveBeenCalledTimes(1);

    const second = await subject.getFlightsForMood({
      country: 'EG',
      mood: 'beach',
    });

    expect(duffel.searchFlights).toHaveBeenCalledTimes(1);
    expect(second.flights).toHaveLength(1);
    expect(cache.get).toHaveBeenCalled();
  });

  it('caps the rail at three live searches', async () => {
    const cards = [
      destination('Hurghada', ['beach']),
      destination('Sharm El Sheikh', ['beach']),
      destination('Alexandria', ['beach']),
      destination('Jeddah', ['beach']),
    ];
    const { subject, duffel } = service(cards, {
      HRG: [offer({ id: 'hrg' })],
      SSH: [offer({ id: 'ssh' })],
      HBE: [offer({ id: 'hbe' })],
      JED: [offer({ id: 'jed' })],
    });

    const payload = await subject.getFlightsForMood({
      country: 'EG',
      mood: 'beach',
      limit: 10,
    });

    expect(MAX_MOOD_CITIES).toBe(3);
    expect(duffel.searchFlights).toHaveBeenCalledTimes(3);
    expect(payload.flights.map((flight) => flight.id).sort()).toEqual([
      'hbe',
      'hrg',
      'ssh',
    ]);
  });

  it('skips a destination with no mapped airport', async () => {
    const { subject, duffel } = service(
      [destination('Atlantis', ['beach'])],
      {},
    );

    const payload = await subject.getFlightsForMood({
      country: 'EG',
      mood: 'beach',
    });

    expect(duffel.searchFlights).not.toHaveBeenCalled();
    expect(payload.flights).toEqual([]);
  });

  it('is honest about an unknown country or mood', async () => {
    const { subject, duffel } = service(
      [destination('Hurghada', ['beach'])],
      { HRG: [offer()] },
    );

    const unknownCountry = await subject.getFlightsForMood({
      country: 'ZZ',
      mood: 'beach',
    });
    const unknownMood = await subject.getFlightsForMood({
      country: 'EG',
      mood: 'party',
    });

    expect(duffel.searchFlights).not.toHaveBeenCalled();
    expect(unknownCountry).toMatchObject({ origin: null, flights: [] });
    expect(unknownMood).toMatchObject({ mood: null, flights: [] });
    expect(TRAVEL_MOODS).not.toContain('party');
  });
});
