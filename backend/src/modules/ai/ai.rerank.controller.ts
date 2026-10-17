import { BadRequestException, Body, Controller, Inject, Logger, Post, UseGuards } from '@nestjs/common';

import { AI_PROVIDER, AiProvider } from './ai.provider';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import {
  AiRerankDto,
  AiRerankResult,
  candidateMetaIsSafe,
  contextIsSafe,
} from '../../common/dto/ai.rerank.dto';

/**
 * AI rerank endpoint (Phase 1C — Personalization Spine).
 *
 * Optional enhancement ONLY: the Home composer's deterministic ordering is
 * always the baseline. When the AI answers within the timeout with a
 * well-formed response, its ordering is applied — but only to the ids the
 * request already contained. Any invented id, malformed JSON, provider
 * failure, or timeout degrades to `fallback: true` (the client keeps its
 * deterministic order) without any UI failure.
 *
 * Safety: the context and candidate metadata are validated against strict
 * whitelists BEFORE any AI call — no tokens, PII, payment data, or precise
 * GPS can reach the prompt. The AI never receives or produces product facts
 * beyond reordering the given ids.
 */
@Controller('ai')
@UseGuards(JwtAuthGuard)
export class AiRerankController {
  private readonly logger = new Logger(AiRerankController.name);

  /** Hard ceiling on the AI call — rerank must never block Home. */
  private static readonly aiTimeoutMs = 15_000;

  constructor(@Inject(AI_PROVIDER) private readonly ai: AiProvider | null) {}

  @Post('rerank')
  async rerank(@Body() dto: AiRerankDto): Promise<AiRerankResult> {
    if (!contextIsSafe(dto.context)) {
      throw new BadRequestException('Context contains non-whitelisted keys.');
    }
    for (const candidate of dto.candidates ?? []) {
      if (!candidateMetaIsSafe(candidate.metadata)) {
        throw new BadRequestException(
          'Candidate metadata contains non-whitelisted keys.',
        );
      }
    }

    const knownIds = new Set((dto.candidates ?? []).map((c) => c.id));
    if (knownIds.size === 0) {
      return { rankedCandidateIds: [], sectionReason: 'discovery', fallback: true };
    }

    if (!this.ai) {
      return this.deterministic(dto);
    }

    const prompt = [
      'You are the TokiGo Home reranker.',
      'Reorder the candidate ids by personal relevance to the user context.',
      'Return ONLY a JSON object, no prose:',
      '{"rankedCandidateIds": ["<id1>", "<id2", ...], "sectionReason": "<one of the allowed reasons>", "confidence": 0.0-1.0}',
      'NEVER invent ids, prices, availability, or providers.',
      'Every returned id MUST come from the candidate list.',
      `Allowed sectionReason values: ${JSON.stringify(dto.allowedReasons ?? [])}.`,
      `User context: ${JSON.stringify(dto.context ?? {})}`,
      `Candidates: ${JSON.stringify(
        (dto.candidates ?? []).map((c) => ({
          id: c.id,
          title: c.title,
          ...(c.price !== undefined ? { price: c.price } : {}),
          ...(c.metadata ?? {}),
        })),
      )}`,
    ].join('\n');

    try {
      const response = await withTimeout(
        this.ai.generate(prompt),
        AiRerankController.aiTimeoutMs,
      );
      const parsed = extractRerank(response.text ?? '');
      if (!parsed) {
        return this.deterministic(dto);
      }
      // Strict validation: any unknown id invalidates the WHOLE response so
      // a hallucinated id can never leak into the Home composition.
      const ranked = (parsed.rankedCandidateIds ?? []).filter((id) =>
        knownIds.has(id),
      );
      if (ranked.length === 0) {
        return this.deterministic(dto);
      }
      const reasonAllowed = (dto.allowedReasons ?? []).includes(
        parsed.sectionReason,
      );
      return {
        rankedCandidateIds: ranked,
        sectionReason: reasonAllowed
          ? parsed.sectionReason
          : 'recommendation',
        confidence: clampConfidence(parsed.confidence),
        fallback: false,
      };
    } catch (error) {
      this.logger.warn(
        `AI rerank skipped: ${(error as Error).message}`,
      );
      return this.deterministic(dto);
    }
  }

  /** Deterministic fallback: input order preserved, no AI involved. */
  private deterministic(dto: AiRerankDto): AiRerankResult {
    return {
      rankedCandidateIds: (dto.candidates ?? []).map((c) => c.id),
      sectionReason: 'recommendation',
      fallback: true,
    };
  }
}

/** Best-effort JSON extraction from the model text (mirrors extractIds). */
function extractRerank(
  text: string,
): { rankedCandidateIds: string[]; sectionReason: string; confidence?: number } | null {
  const trimmed = (text ?? '').trim();
  const brace = trimmed.indexOf('{');
  const close = trimmed.indexOf('}');
  if (brace < 0 || close <= brace) return null;
  try {
    const parsed = JSON.parse(trimmed.slice(brace, close + 1));
    const ids = parsed?.rankedCandidateIds;
    if (!Array.isArray(ids)) return null;
    return {
      rankedCandidateIds: ids.filter((x: unknown): x is string => typeof x === 'string'),
      sectionReason:
        typeof parsed?.sectionReason === 'string' ? parsed.sectionReason : '',
      confidence: typeof parsed?.confidence === 'number' ? parsed.confidence : undefined,
    };
  } catch {
    return null;
  }
}

function clampConfidence(value?: number): number | undefined {
  if (value === undefined || !Number.isFinite(value)) return undefined;
  return Math.min(1, Math.max(0, value));
}

function withTimeout<T>(promise: Promise<T>, ms: number): Promise<T> {
  return Promise.race([
    promise,
    new Promise<T>((_, reject) =>
      setTimeout(() => reject(new Error('rerank timeout')), ms),
    ),
  ]);
}
