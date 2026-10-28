import { ArrayMaxSize, IsArray, IsNumber, IsObject, IsOptional, IsString, Length, ValidateNested } from 'class-validator';

/**
 * AI rerank contract (Phase 1C — Personalization Spine).
 *
 * The client sends a SAFE, minimal context plus a small set of REAL
 * candidates produced by the existing recommendation/search infrastructure.
 * The AI may only reorder those candidates — it can never introduce ids,
 * prices, availability, providers, or any product facts. Everything outside
 * the whitelists below is rejected by validation before any AI call.
 */

/** Context keys the AI is allowed to see. Anything else is a 400. */
const CONTEXT_WHITELIST = new Set([
  'userState',
  'countryCode',
  'recentSearchLabels',
  'viewedTitles',
  'favoriteTitles',
  'upcomingDestination',
  'topDestinations',
  'preferredStars',
  'budgetMax',
  'hasTrips',
]);

/** Metadata keys a candidate may carry. */
const CANDIDATE_META_WHITELIST = new Set(['city', 'rating', 'reviews', 'reason']);

export class RerankCandidateDto {
  /** Provider/recommendation id — the only key the AI may return. */
  @IsString()
  @Length(1, 120)
  id!: string;

  @IsString()
  @Length(1, 160)
  title!: string;

  /** Optional real price from the provider (display only, never mutated). */
  @IsOptional()
  @IsNumber()
  price?: number;

  @IsOptional()
  @IsObject()
  metadata?: Record<string, unknown>;
}

export class AiRerankDto {
  /**
   * Safe personalization context. Validated against CONTEXT_WHITELIST so no
   * tokens, emails, payment data, or precise GPS can reach the AI.
   */
  @IsObject()
  context!: Record<string, unknown>;

  /** Real candidates (≤ 30) from provider/recommendation infrastructure. */
  @IsArray()
  @ArrayMaxSize(30)
  @ValidateNested({ each: true })
  candidates!: RerankCandidateDto[];

  /** Section reasons the composer is prepared to explain. */
  @IsArray()
  @IsString({ each: true })
  allowedReasons!: string[];
}

/** Normalized, provider-agnostic rerank result. */
export interface AiRerankResult {
  rankedCandidateIds: string[];
  sectionReason: string;
  confidence?: number;
  fallback: boolean;
}

/** Validates that [context] contains only whitelisted keys. */
export function contextIsSafe(context: Record<string, unknown>): boolean {
  for (const key of Object.keys(context ?? {})) {
    if (!CONTEXT_WHITELIST.has(key)) return false;
  }
  return true;
}

/** Validates that candidate metadata carries only whitelisted keys. */
export function candidateMetaIsSafe(meta?: Record<string, unknown>): boolean {
  if (!meta) return true;
  for (const key of Object.keys(meta)) {
    if (!CANDIDATE_META_WHITELIST.has(key)) return false;
  }
  return true;
}
