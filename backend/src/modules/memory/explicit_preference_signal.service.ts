import { Injectable, Logger } from '@nestjs/common';

import { MemoryService } from './memory.service';
import {
  conversationKindFromKey,
  validateConversationFact,
} from './conversation_facts';
import { normalizeBudgetCurrency } from './budget_currency';

/**
 * Explicit Preference Signal (PH-7).
 *
 * The SEPARATE, additive adapter that lets EXPLICIT AI-conversation memories
 * influence Home Ranking — WITHOUT converting `type='conversation'` rows into
 * `type='behavior'`, WITHOUT touching `DerivedPreferenceProfile` semantics,
 * and WITHOUT changing the behavioural event pipeline.
 *
 * Boundary (phase decision, AGENTS.md 2C rule lifted for PH-7 only):
 * - Reads ONLY `type='conversation' + source='ai_conversation'` rows via ONE
 *   user-scoped batch query (MemoryService.listForUser) — no N+1, no per-card
 *   lookup, no AI call, no OpenRouter dependency.
 * - Ownership/expiration are inherited from the Phase 2A listing contract
 *   (expired rows hidden; other users' rows can never appear).
 * - Every row is re-validated with the 2C-A vocabulary validator, so
 *   malformed / sensitive / wrong-shape rows are ignored safely.
 * - Latest valid value wins per kind (rows arrive `updatedAt DESC`) — a
 *   re-stated preference overrides the previous one, and repeated identical
 *   facts cannot inflate a score (exactly one bounded signal per kind).
 * - `preferred_budget` never treats a missing bound as zero.
 * - `preferred_travel_style` is carried for CONTRACT completeness ONLY and is
 *   DELIBERATELY NOT consumed by ranking: Home candidates expose no
 *   deterministic style/amenity vocabulary, so inventing a mapping is
 *   forbidden (spec PH-7 §Vocabulary). It is returned so the deferral is
 *   explicit and regression-testable.
 *
 * Failure isolation: never throws to the caller — degrades to `null` (no
 * signal), so `/profile/me` and Home can never break because of this.
 */
@Injectable()
export class ExplicitPreferenceSignalService {
  private readonly logger = new Logger(ExplicitPreferenceSignalService.name);

  constructor(private readonly memories: MemoryService) {}

  /**
   * Builds the explicit preference signal for [userId]. Returns `null` when
   * the user has opted out of personalization, on any failure, or when no
   * usable signal exists (so consumers treat null exactly like "no signal").
   */
  async buildForUserSafe(
    userId: string,
    personalizationEnabled: boolean,
  ): Promise<ExplicitPreferenceSignal | null> {
    // Personalization disabled → NO memory lookup at all (spec PH-7).
    if (!personalizationEnabled) return null;
    try {
      return await this.buildForUser(userId);
    } catch (error) {
      this.logger.warn(
        `Explicit preference signal failed: ${(error as Error).message}`,
      );
      return null;
    }
  }

  /**
   * ONE bounded, user-scoped batch read → the bounded explicit signal.
   * Pure read; NEVER writes. Exposed for tests + the profile read model.
   */
  async buildForUser(userId: string): Promise<ExplicitPreferenceSignal | null> {
    // Single query for this user's explicit conversation memories; expired
    // rows are already hidden by the Phase 2A listing default.
    const rows = await this.memories.listForUser(userId, {
      type: 'conversation',
      source: 'ai_conversation',
    });
    if (rows.length === 0) return null;

    let destination: string | undefined;
    let budget: { min?: number; max?: number } | undefined;
    let travelStyles: string[] | undefined;

    for (const row of rows) {
      const kind = conversationKindFromKey(row.key);
      if (!kind) continue;
      const value = (row.value ?? {}) as Record<string, any>;

      // Re-validate against the 2C-A vocabulary: malformed / sensitive /
      // wrong-shape rows are silently skipped (never crash Home).
      const validation = validateConversationFact(kind, value);
      if (!validation.valid) continue;

      // rows are `updatedAt DESC` → the first valid value seen per kind is
      // the most recent one; later (older) rows never overwrite it.
      switch (kind) {
        case 'preferred_destination': {
          if (destination === undefined) {
            const name = String(value.destination ?? '').trim();
            if (name) destination = name;
          }
          break;
        }
        case 'preferred_budget': {
          if (budget === undefined) {
            const min = finiteNumber(value.min);
            const max = finiteNumber(value.max);
            // Phase 4B: the currency is optional and only kept when it is a
            // supported code — the app never converts prices, so an unknown
            // currency must not reach a consumer.
            const currency = normalizeBudgetCurrency(value.currency);
            // Missing bound is NEVER zero — omit it entirely.
            if (min !== undefined || max !== undefined) {
              budget = {
                ...(min !== undefined ? { min } : {}),
                ...(max !== undefined ? { max } : {}),
                ...(currency ? { currency } : {}),
              };
            }
          }
          break;
        }
        case 'preferred_travel_style': {
          if (travelStyles === undefined && Array.isArray(value.styles)) {
            travelStyles = value.styles
              .filter((s): s is string => typeof s === 'string' && s.length > 0)
              .slice(0, 60);
          }
          break;
        }
        default:
          break;
      }
    }

    if (destination === undefined && budget === undefined && travelStyles === undefined) {
      return null;
    }
    return {
      ...(destination !== undefined ? { destination } : {}),
      ...(budget !== undefined ? { budget } : {}),
      ...(travelStyles !== undefined ? { travelStyles } : {}),
    };
  }
}

/** Bounded explicit preference signal consumed by Home Ranking (PH-7). */
export interface ExplicitPreferenceSignal {
  /** Most-recent explicit destination (destination/city matching only). */
  destination?: string;
  /** Most-recent explicit budget range; a missing bound is never zero. */
  budget?: { min?: number; max?: number; currency?: string };
  /**
   * Carried for contract completeness only — NOT consumed by ranking (no
   * deterministic style/amenity vocabulary exists on Home candidates yet).
   */
  travelStyles?: string[];
}

/** Returns the finite numeric value, or undefined (never 0 for missing). */
function finiteNumber(raw: unknown): number | undefined {
  return typeof raw === 'number' && Number.isFinite(raw) ? raw : undefined;
}
