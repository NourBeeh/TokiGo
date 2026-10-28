import { Injectable, Logger } from '@nestjs/common';

import { MemoryService } from './memory.service';
import { UserMemory } from '../../database/entities/user_memory.entity';
import { conversationKindFromKey } from './conversation_facts';

/**
 * Relevant Memory Selector (Phase 2C-A).
 *
 * Server-side read helper for the FUTURE AI-context integration (Phase 2C-B):
 * given the user's next message, return a SMALL, relevant subset of their
 * explicit conversation memories — never a full dump.
 *
 * Phase boundary: this selector is pure read logic over the memory spine.
 * It does NOT touch DerivedPreferenceProfile, Home Ranking, or any AI
 * prompt yet. Nothing in Phase 2C-A sends memories to OpenRouter.
 *
 * Safety contract:
 * - Reads ONLY type='conversation' + source='ai_conversation' rows —
 *   behavioral memories (Phase 2B) are invisible here by construction.
 * - Ownership: every query goes through MemoryService.listForUser(userId)
 *   so rows from other users can never appear.
 * - Expiration: expired rows are hidden (Phase 2A listing default).
 * - Deterministic relevance (no ML/embeddings): keyword overlap between
 *   the message tokens and the fact's own text, then recency as the
 *   tiebreaker (the listing is already updatedAt DESC).
 * - Bounded output: capped at `maxMemories` (default 5).
 */
@Injectable()
export class RelevantMemorySelector {
  private readonly logger = new Logger(RelevantMemorySelector.name);

  /** Hard output cap — the caller gets a small subset, not a dump. */
  static readonly DEFAULT_MAX_MEMORIES = 5;

  constructor(private readonly memories: MemoryService) {}

  /**
   * Returns the explicit conversation memories relevant to [message], capped
   * and ordered by relevance (keyword overlap) then recency. Degrades to []
   * on any failure — a selector problem must never break an AI query.
   */
  async selectRelevant(
    userId: string,
    message: string,
    maxMemories: number = RelevantMemorySelector.DEFAULT_MAX_MEMORIES,
  ): Promise<UserMemory[]> {
    try {
      const rows = await this.memories.listForUser(userId, {
        type: 'conversation',
        source: 'ai_conversation',
      });
      const cap = Math.max(1, Math.min(maxMemories, 20));
      if (rows.length === 0) return [];

      const tokens = tokenize(message);
      if (tokens.size === 0) {
        // Degenerate input (no usable tokens) → nothing can be relevant.
        return [];
      }

      const scored = rows
        .map((row) => ({ row, score: relevanceScore(row, tokens) }))
        .filter((entry) => entry.score > 0)
        .sort((a, b) =>
          b.score !== a.score
            ? b.score - a.score
            : // rows arrive updatedAt DESC — stable, deterministic tiebreak.
              0,
        );
      // STRICT relevance (Phase 2C-B): an irrelevant memory never travels to
      // the AI. No "recent fallback" — absence of a match is the correct
      // answer, not a reason to dump the newest rows.
      return scored.slice(0, cap).map((entry) => entry.row);
    } catch (error) {
      this.logger.warn(
        `Relevant memory selection skipped: ${(error as Error).message}`,
      );
      return [];
    }
  }
}

/**
 * Deterministic keyword overlap between the message and a memory's own
 * fields (destination text, budget numbers, style words). Pure — no model,
 * no embeddings. A fact scores >0 only when at least one of its own tokens
 * appears in the message.
 */
export function relevanceScore(row: UserMemory, tokens: Set<string>): number {
  const value = (row.value ?? {}) as Record<string, any>;
  let score = 0;

  const kind = conversationKindFromKey(row.key);
  const destination = typeof value.destination === 'string' ? value.destination : '';
  if (destination) {
    for (const token of tokenize(destination)) {
      if (tokens.has(token)) score += 2;
    }
  }
  const styles = Array.isArray(value.styles) ? value.styles : [];
  for (const style of styles) {
    if (typeof style === 'string') {
      for (const token of tokenize(style)) {
        if (tokens.has(token)) score += 1;
      }
    }
  }
  // Budget relevance: a budget fact is relevant when the message mentions
  // price/budget vocabulary; the numbers themselves are never stringified.
  if (kind === 'preferred_budget') {
    const messageText = [...tokens].join(' ');
    if (/(budget|price|cheap|expensive|cost|ميزانية|سعر|تكلفة)/i.test(messageText)) {
      score += 1;
    }
  }
  return score;
}

/** Lowercases, strips punctuation, and keeps Arabic + Latin word tokens. */
export function tokenize(text: string): Set<string> {
  const raw = (text ?? '').toLowerCase();
  const tokens = new Set<string>();
  for (const match of raw.matchAll(/[a-z0-9\u0600-\u06FF]+/g)) {
    const token = match[0];
    // Skip bare numbers and single letters — noise for keyword matching.
    if (token.length > 1 || /[\u0600-\u06FF]/.test(token)) {
      tokens.add(token);
    }
  }
  return tokens;
}
