import { NEARBY_RANKING_VERSION, PromotionalStay } from './promotional-stay.model';

/**
 * Deterministic Nearby Stays ranking (R2).
 *
 * Rating quality is Bayesian-adjusted so a 5.0 from two reviews cannot
 * outrank a 4.8 from thousands. The score then balances adjusted rating,
 * competitive one-night price and actual distance with configurable weights.
 * Nothing here is cheapest-first or rating-first, and every tie is broken by
 * hotel id so the same inputs always produce the same order.
 */

export interface RankingConfig {
  /** Prior mean on the 5-point scale. */
  priorMean: number;
  /** Prior strength in "reviews". */
  priorWeight: number;
  weightRating: number;
  weightPrice: number;
  weightDistance: number;
  /** Minimum results before the quality threshold stops relaxing. */
  minResults: number;
}

/** One gradual relaxation step of the quality gate. */
interface QualityStep {
  minAdjustedRating: number;
  minReviewCount: number;
}

/**
 * Strictest first. The last step accepts any rated or unrated hotel, so a
 * thin market still gets an honest answer — but never a hotel outside the
 * geographic radius.
 */
export const QUALITY_RELAXATION_STEPS: readonly QualityStep[] = [
  { minAdjustedRating: 3.5, minReviewCount: 20 },
  { minAdjustedRating: 3.0, minReviewCount: 10 },
  { minAdjustedRating: 2.5, minReviewCount: 1 },
  { minAdjustedRating: 0, minReviewCount: 0 },
];

export function rankingConfigFromEnv(): RankingConfig {
  const num = (name: string, fallback: number): number => {
    const value = Number(process.env[name]);
    return Number.isFinite(value) && value >= 0 ? value : fallback;
  };
  return {
    priorMean: num('NEARBY_RATING_PRIOR_MEAN', 3.5),
    priorWeight: num('NEARBY_RATING_PRIOR_WEIGHT', 10),
    weightRating: num('NEARBY_WEIGHT_RATING', 0.5),
    weightPrice: num('NEARBY_WEIGHT_PRICE', 0.3),
    weightDistance: num('NEARBY_WEIGHT_DISTANCE', 0.2),
    minResults: Math.max(1, Math.floor(num('NEARBY_MIN_RESULTS', 6))),
  };
}

/**
 * Bayesian-adjusted rating on the 5-point scale.
 *
 * `(reviews * rating + priorWeight * priorMean) / (reviews + priorWeight)`.
 * A missing rating stays null — an unknown score is never replaced by the
 * prior, because the caller needs to distinguish "no rating" from "average".
 */
export function bayesianRating(
  rating: number | null,
  reviewCount: number | null,
  config: Pick<RankingConfig, 'priorMean' | 'priorWeight'>,
): number | null {
  if (rating === null || !Number.isFinite(rating)) return null;
  const reviews = reviewCount !== null && Number.isFinite(reviewCount) ? Math.max(0, reviewCount) : 0;
  const adjusted =
    (reviews * rating + config.priorWeight * config.priorMean) /
    (reviews + config.priorWeight);
  return Number.isFinite(adjusted) ? adjusted : null;
}

export interface RankedStay {
  stay: PromotionalStay;
  score: number;
  adjustedRating: number | null;
}

export interface RankResult {
  ranked: PromotionalStay[];
  /** True when a stricter quality gate was relaxed to fill the list. */
  relaxed: boolean;
  rankingVersion: string;
}

/**
 * Ranks already-geographically-filtered, already-priced stays.
 *
 * The quality gate relaxes gradually only when fewer than `minResults`
 * hotels pass; geographic filtering is never relaxed.
 */
export function rankStays(
  stays: PromotionalStay[],
  config: RankingConfig = rankingConfigFromEnv(),
): RankResult {
  const totalWeight = config.weightRating + config.weightPrice + config.weightDistance;
  const weights =
    totalWeight > 0
      ? {
          rating: config.weightRating / totalWeight,
          price: config.weightPrice / totalWeight,
          distance: config.weightDistance / totalWeight,
        }
      : { rating: 1, price: 0, distance: 0 };

  const priced = stays.filter(
    (stay) =>
      Number.isFinite(stay.promotionalMinimumPrice) && stay.promotionalMinimumPrice > 0,
  );
  if (priced.length === 0) {
    return { ranked: [], relaxed: false, rankingVersion: NEARBY_RANKING_VERSION };
  }

  const maxDistance = Math.max(...priced.map((stay) => Math.max(0, stay.distanceKm)));

  // Prices are only compared within ONE currency. A mixed-currency candidate
  // set (a provider anomaly, or a caller-supplied override) is normalised per
  // currency group, never across exchange rates we do not have.
  const priceRangeByCurrency = new Map<string, { min: number; max: number }>();
  for (const stay of priced) {
    const currency = stay.currency.trim().toUpperCase() || 'UNKNOWN';
    const range = priceRangeByCurrency.get(currency);
    if (!range) {
      priceRangeByCurrency.set(currency, {
        min: stay.promotionalMinimumPrice,
        max: stay.promotionalMinimumPrice,
      });
    } else {
      range.min = Math.min(range.min, stay.promotionalMinimumPrice);
      range.max = Math.max(range.max, stay.promotionalMinimumPrice);
    }
  }

  const scoreOf = (stay: PromotionalStay): number => {
    const adjusted = bayesianRating(stay.rating, stay.reviewCount, config) ?? 0;
    const ratingScore = Math.min(5, Math.max(0, adjusted)) / 5;
    const currency = stay.currency.trim().toUpperCase() || 'UNKNOWN';
    const range = priceRangeByCurrency.get(currency)!;
    const span = range.max - range.min;
    const priceScore = span > 0 ? 1 - (stay.promotionalMinimumPrice - range.min) / span : 1;
    const distanceScore =
      maxDistance > 0 ? 1 - Math.max(0, stay.distanceKm) / maxDistance : 1;
    return weights.rating * ratingScore + weights.price * priceScore + weights.distance * distanceScore;
  };

  const gate = (step: QualityStep): PromotionalStay[] =>
    priced.filter((stay) => {
      const adjusted = bayesianRating(stay.rating, stay.reviewCount, config);
      const reviews = stay.reviewCount ?? 0;
      if (adjusted === null) {
        // A hotel with no rating only passes once the gate reaches the
        // unrated step; a missing score is never treated as a high score.
        return step.minAdjustedRating === 0;
      }
      return adjusted >= step.minAdjustedRating && reviews >= step.minReviewCount;
    });

  let selected: PromotionalStay[] = [];
  let relaxed = false;
  for (let index = 0; index < QUALITY_RELAXATION_STEPS.length; index += 1) {
    const candidates = gate(QUALITY_RELAXATION_STEPS[index]);
    if (candidates.length >= config.minResults || index === QUALITY_RELAXATION_STEPS.length - 1) {
      selected = candidates;
      relaxed = index > 0;
      break;
    }
  }

  const scored: RankedStay[] = selected.map((stay) => ({
    stay,
    score: scoreOf(stay),
    adjustedRating: bayesianRating(stay.rating, stay.reviewCount, config),
  }));

  // Deterministic: score desc, then hotel id asc. No reliance on input order.
  scored.sort((a, b) => {
    if (b.score !== a.score) return b.score - a.score;
    return a.stay.hotelId.localeCompare(b.stay.hotelId);
  });

  return {
    ranked: scored.map((entry) => entry.stay),
    relaxed,
    rankingVersion: NEARBY_RANKING_VERSION,
  };
}
