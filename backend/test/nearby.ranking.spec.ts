import {
  bayesianRating,
  QUALITY_RELAXATION_STEPS,
  rankStays,
  rankingConfigFromEnv,
  RankingConfig,
} from '../src/modules/nearby/nearby-ranking.service';
import { PromotionalStay } from '../src/modules/nearby/promotional-stay.model';

function stay(overrides: Partial<PromotionalStay> = {}): PromotionalStay {
  return {
    hotelId: 'h1',
    hotelName: 'Hotel',
    city: 'Cairo',
    country: 'EG',
    image: null,
    latitude: 30.04,
    longitude: 31.23,
    distanceKm: 2,
    rating: 4.5,
    reviewCount: 100,
    promotionalMinimumPrice: 100,
    currency: 'USD',
    searchedFromDate: '2026-11-21',
    searchedToDate: '2026-11-28',
    occupancy: 2,
    nationality: 'EG',
    provider: 'nuitee',
    fetchedAt: '2026-11-21T00:00:00.000Z',
    locationConfidence: 'high',
    ...overrides,
  };
}

const config: RankingConfig = {
  priorMean: 3.5,
  priorWeight: 10,
  weightRating: 0.5,
  weightPrice: 0.3,
  weightDistance: 0.2,
  minResults: 6,
};

describe('nearby ranking', () => {
  it('Bayesian-adjusts a thin 5.0 below a well-reviewed 4.8', () => {
    const thin = bayesianRating(5.0, 2, config)!;
    const solid = bayesianRating(4.8, 5000, config)!;
    expect(thin).toBeCloseTo(3.75, 2);
    expect(solid).toBeGreaterThan(4.7);
    expect(thin).toBeLessThan(solid);
  });

  it('keeps a missing rating missing instead of inventing an average', () => {
    expect(bayesianRating(null, 100, config)).toBeNull();
    expect(bayesianRating(4.5, null, config)).not.toBeNull();
  });

  it('ranks a well-reviewed hotel above a thin 5.0 with equal price and distance', () => {
    const result = rankStays([
      stay({ hotelId: 'thin', rating: 5.0, reviewCount: 2 }),
      stay({ hotelId: 'solid', rating: 4.8, reviewCount: 5000 }),
    ], config);
    expect(result.ranked.map((stay) => stay.hotelId)).toEqual(['solid', 'thin']);
  });

  it('prioritises distance when rating and price are equal', () => {
    const result = rankStays([
      stay({ hotelId: 'far', distanceKm: 10 }),
      stay({ hotelId: 'near', distanceKm: 1 }),
    ], config);
    expect(result.ranked.map((stay) => stay.hotelId)).toEqual(['near', 'far']);
  });

  it('prioritises a competitive price when rating and distance are equal', () => {
    const result = rankStays([
      stay({ hotelId: 'pricey', promotionalMinimumPrice: 300 }),
      stay({ hotelId: 'cheap', promotionalMinimumPrice: 80 }),
    ], config);
    expect(result.ranked.map((stay) => stay.hotelId)).toEqual(['cheap', 'pricey']);
  });

  it('excludes a stay without a valid promotional price', () => {
    const result = rankStays([
      stay({ hotelId: 'priced', promotionalMinimumPrice: 100 }),
      stay({ hotelId: 'free', promotionalMinimumPrice: 0 }),
      stay({ hotelId: 'negative', promotionalMinimumPrice: -5 }),
    ], config);
    expect(result.ranked.map((stay) => stay.hotelId)).toEqual(['priced']);
  });

  it('never compares prices across currencies', () => {
    // 80 EUR is not "cheaper" than 100 USD without an exchange rate; each
    // currency is normalised within its own group, so both get priceScore 1.
    const result = rankStays([
      stay({ hotelId: 'usd', promotionalMinimumPrice: 100, currency: 'USD' }),
      stay({ hotelId: 'eur', promotionalMinimumPrice: 80, currency: 'EUR' }),
    ], config);
    expect(result.ranked).toHaveLength(2);
    // Deterministic tie-break by hotel id.
    expect(result.ranked.map((stay) => stay.hotelId)).toEqual(['eur', 'usd']);
  });

  it('drops an unrated hotel while enough rated hotels pass the gate', () => {
    const result = rankStays([
      stay({ hotelId: 'rated-1', rating: 4.5, reviewCount: 100 }),
      stay({ hotelId: 'rated-2', rating: 4.4, reviewCount: 100 }),
      stay({ hotelId: 'unrated', rating: null, reviewCount: null }),
    ], { ...config, minResults: 2 });
    expect(result.ranked.map((stay) => stay.hotelId)).toEqual(['rated-1', 'rated-2']);
    expect(result.relaxed).toBe(false);
  });

  it('relaxes the quality gate gradually when the strict pool is too small', () => {
    const stays = [
      stay({ hotelId: 'strict-1', rating: 4.5, reviewCount: 100 }),
      stay({ hotelId: 'strict-2', rating: 4.4, reviewCount: 100 }),
      stay({ hotelId: 'weak-1', rating: 2.0, reviewCount: 2 }),
      stay({ hotelId: 'weak-2', rating: 2.1, reviewCount: 3 }),
      stay({ hotelId: 'weak-3', rating: 2.2, reviewCount: 4 }),
      stay({ hotelId: 'weak-4', rating: 2.3, reviewCount: 5 }),
    ];
    const result = rankStays(stays, { ...config, minResults: 6 });
    expect(result.relaxed).toBe(true);
    expect(result.ranked).toHaveLength(6);
    expect(result.ranked.slice(0, 2).map((stay) => stay.hotelId)).toEqual([
      'strict-1',
      'strict-2',
    ]);
    expect(QUALITY_RELAXATION_STEPS.length).toBeGreaterThan(1);
  });

  it('is deterministic regardless of input order', () => {
    const stays = [
      stay({ hotelId: 'b', distanceKm: 3, promotionalMinimumPrice: 120 }),
      stay({ hotelId: 'a', distanceKm: 2, promotionalMinimumPrice: 110 }),
      stay({ hotelId: 'c', distanceKm: 1, promotionalMinimumPrice: 130 }),
    ];
    const first = rankStays(stays, config).ranked.map((stay) => stay.hotelId);
    const second = rankStays([...stays].reverse(), config).ranked.map((stay) => stay.hotelId);
    expect(first).toEqual(second);
  });

  it('exposes configurable weights and a sane default', () => {
    const defaults = rankingConfigFromEnv();
    expect(defaults.weightRating).toBeGreaterThan(0);
    expect(defaults.weightPrice).toBeGreaterThan(0);
    expect(defaults.weightDistance).toBeGreaterThan(0);
  });
});
