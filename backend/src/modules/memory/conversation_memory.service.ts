import { Inject, Injectable, Logger, Optional } from '@nestjs/common';

import { AI_PROVIDER, AiProvider } from '../ai/ai.provider';
import { AiResponseDto } from '../../common/dto/ai.dto';
import { MemoryService } from './memory.service';
import { UserMemory } from '../../database/entities/user_memory.entity';
import {
  CONVERSATION_FACT_KINDS,
  CONVERSATION_FACT_LIMITS,
  ConversationFactKind,
  conversationFactKey,
  validateConversationFact,
} from './conversation_facts';

/**
 * Explicit AI Conversation Memory extraction (Phase 2C-A).
 *
 * One user message in an AI conversation → typed, whitelisted EXPLICIT facts,
 * upserted through the Phase 2A MemoryService with
 *   type   = 'conversation'
 *   source = 'ai_conversation'
 *
 * Design invariants (phase decision):
 * - EXPLICIT ONLY: the extractor prompt forbids inference; a fact is saved
 *   only when the user STATED it in this message. Behavioural guessing is
 *   the Phase 2B pipeline's job and never touches this store.
 * - NO raw transcripts: the persisted value is the small typed fact, never
 *   the message text or the AI's answer.
 * - ISOLATION (§ events pattern): extraction failure NEVER fails the AI
 *   response. The caller wraps this in try/catch; this service also logs
 *   and swallows its own AI-call failures so the caller's contract stays
 *   "throws nothing" in practice.
 * - LOG SAFETY: logs carry kinds and counts only — never fact values.
 *
 * Phase boundary: this phase does NOT send memories into the /ai/query
 * prompt; that wiring (RelevantMemorySelector → AI context) is the next
 * phase (2C-B). Here the selector is only exercised by unit tests.
 */
@Injectable()
export class ConversationMemoryService {
  private readonly logger = new Logger(ConversationMemoryService.name);

  constructor(
    private readonly memories: MemoryService,
    // Optional so the memory module never hard-depends on an AI provider
    // binding (tests inject a stub; a null provider disables extraction).
    @Optional() @Inject(AI_PROVIDER) private readonly ai?: AiProvider | null,
  ) {}

  /**
   * Extracts explicit facts from ONE user message and upserts them.
   * Returns the extracted-and-saved memories (possibly []). NEVER throws
   * to the caller on provider/parse/validation problems — invalid facts are
   * skipped and logged by kind, never by value.
   *
   * [ai] (tests / future callers) overrides the injected provider — used by
   * the Phase 2C-B specs to drive extraction deterministically.
   */
  async extractFromMessage(
    userId: string,
    message: string,
    ai?: AiProvider | null,
  ): Promise<UserMemory[]> {
    const provider = ai ?? this.ai;
    const trimmed = (message ?? '').trim();
    if (!trimmed || !provider) return [];

    let facts: ExtractedFact[];
    try {
      facts = await this.detectExplicitFacts(trimmed, provider);
    } catch (error) {
      this.logger.warn(
        `Explicit memory extraction skipped: ${(error as Error).message}`,
      );
      return [];
    }

    const saved: UserMemory[] = [];
    for (const fact of facts) {
      try {
        saved.push(await this.saveFact(userId, fact));
      } catch (error) {
        this.logger.warn(
          `Explicit memory fact rejected (${fact.kind}): ${(error as Error).message}`,
        );
      }
    }
    if (saved.length > 0) {
      this.logger.log(`explicit memory saved kinds=${saved.map((m) => m.key).length}`);
    }
    return saved;
  }

  /**
   * Saves ONE validated explicit fact via the Phase 2A upsert
   * (userId + type + key) — re-recording the same preference updates the
   * existing row instead of piling duplicates.
   */
  async saveFact(userId: string, fact: ExtractedFact): Promise<UserMemory> {
    const validation = validateConversationFact(fact.kind, fact.value);
    if (!validation.valid) {
      throw new Error(validation.error);
    }
    const key = conversationFactKey(
      fact.kind,
      fact.kind === 'preferred_destination'
        ? String(fact.value.destination ?? '')
        : fact.kind,
    );
    return this.memories.upsert(userId, {
      type: 'conversation',
      key,
      // Phase 4B: the SANITIZED value is stored (a supported currency is
      // normalized, an unusable one is dropped) — never the raw model output.
      value: validation.value ?? fact.value,
      source: 'ai_conversation',
      confidence: 1, // The user said it themselves — no decay ladder applies.
    });
  }

  /**
   * Asks the provider to detect EXPLICIT statements only. The prompt is a
   * closed contract: only three fact kinds, only what the user literally
   * stated in THIS message, JSON only. The contract rides the provider's
   * system prompt (Phase 2C-B signature) so the user message itself stays
   * a clean, isolated input.
   */
  private async detectExplicitFacts(
    message: string,
    provider: AiProvider,
  ): Promise<ExtractedFact[]> {
    const prompt = `User message: ${message}`;

    const response: AiResponseDto = await provider.generate(
      prompt,
      EXTRACTOR_SYSTEM_PROMPT,
    );
    return parseExplicitFacts(response.text ?? '');
  }
}

/** Closed extractor contract (system-prompt tier, Phase 2C-B). */
export const EXTRACTOR_SYSTEM_PROMPT = [
  'You extract EXPLICIT travel preferences that the user states about THEMSELVES.',
  'Rules:',
  '- Save ONLY what the user explicitly says in this message (first person).',
  '- NEVER infer, guess, or derive from behaviour, context, or the assistant.',
  '- If the message contains no explicit self-stated preference, return an empty list.',
  '- For a budget, record the currency ONLY when the user states it (e.g. "up to 300 USD"). NEVER convert, guess or assume a currency.',
  '- Allowed fact kinds and value shapes:',
  `  preferred_destination: { "destination": string (max ${CONVERSATION_FACT_LIMITS.destinationMax} chars) }`,
  '  preferred_budget: { "min"?: number, "max"?: number, "currency"?: string (ISO 4217 code, ONLY when the user states it) }',
  `  preferred_travel_style: { "styles": string[] (max ${CONVERSATION_FACT_LIMITS.stylesMaxItems} items) }`,
  '- NO other kinds. NO other fields.',
  'Return ONLY a JSON object, no prose:',
  '{"facts": [{"kind": "preferred_destination | preferred_budget | preferred_travel_style", "value": { ... }}]}',
  'Example of no preference: {"facts": []}',
].join('\n');

/** One candidate explicit fact straight out of the extractor model. */
export interface ExtractedFact {
  kind: ConversationFactKind;
  value: Record<string, any>;
}

/**
 * Parses the extractor's JSON answer against the strict vocabulary.
 * Malformed output, unknown kinds, or non-object values yield [] — never a
 * throw (the caller treats extraction as best-effort).
 */
export function parseExplicitFacts(text: string): ExtractedFact[] {
  const trimmed = (text ?? '').trim();
  if (!trimmed) return [];
  const brace = trimmed.indexOf('{');
  const close = trimmed.lastIndexOf('}');
  if (brace < 0 || close <= brace) return [];
  let parsed: unknown;
  try {
    parsed = JSON.parse(trimmed.slice(brace, close + 1));
  } catch {
    return [];
  }
  const record = parsed as Record<string, unknown>;
  if (!record || typeof record !== 'object' || !Array.isArray(record.facts)) {
    return [];
  }
  const out: ExtractedFact[] = [];
  for (const raw of record.facts) {
    const entry = raw as Record<string, unknown>;
    if (!entry || typeof entry !== 'object') continue;
    const kind = entry.kind;
    const value = entry.value;
    if (
      typeof kind !== 'string' ||
      !(CONVERSATION_FACT_KINDS as string[]).includes(kind)
    ) {
      continue;
    }
    if (!value || typeof value !== 'object' || Array.isArray(value)) {
      continue;
    }
    out.push({ kind: kind as ConversationFactKind, value: value as Record<string, any> });
  }
  return out;
}
