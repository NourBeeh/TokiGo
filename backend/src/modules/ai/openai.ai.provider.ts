import { randomUUID } from 'crypto';

import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

import {
  AiActionDto,
  AiItemDto,
  AiResponseDto,
  AiSectionDto,
} from '../../common/dto/ai.dto';
import { AiProvider, AiProviderFailure } from './ai.provider';

const ALLOWED_CARD_TYPES: ReadonlySet<string> = new Set([
  'hotel',
  'flight',
  'car',
  'package',
  'destination',
  'deal',
  'experience',
  'story',
]);

const ALLOWED_LAYOUTS: ReadonlySet<AiSectionDto['layout']> = new Set([
  'vertical',
  'horizontal',
  'horizontalPeek',
  'grid',
]);

const DEFAULT_BASE_URL = 'https://api.openai.com/v1';
const DEFAULT_MODEL = 'gpt-4o-mini';
// The free OpenRouter router (`openrouter/free`) queues behind free models and
// can take well over 30s; 90s gives it headroom while still bounding the call.
const REQUEST_TIMEOUT_MS = 90_000;

/** True when [cause] is the abort raised by `AbortSignal.timeout`. */
function isRequestTimeout(cause: unknown): boolean {
  if (!cause || typeof cause !== 'object') return false;
  const name = (cause as { name?: unknown }).name;
  return name === 'TimeoutError' || name === 'AbortError';
}

/**
 * Instructs the model to answer with ONLY plain JSON matching the
 * AiResponseDto contract — the exact shape the Flutter app parses.
 */
const SYSTEM_PROMPT = [
  'You are the TokiGo travel assistant.',
  'Respond with ONLY valid JSON — no markdown, no commentary.',
  'The JSON must match this exact shape:',
  JSON.stringify({
    text: 'natural-language answer',
    sections: [
      {
        title: 'section title',
        subtitle: 'optional subtitle',
        layout: 'horizontal | horizontalPeek | vertical | grid',
        order: 1,
        items: [
          {
            id: 'unique id',
            type: 'hotel | flight | car | package | destination | deal | experience | story',
            title: 'card title',
            subtitle: 'optional',
            description: 'optional',
            imageUrl: 'optional https image url',
            price: 123,
            currency: 'USD',
            rating: 4.5,
            reviewCount: 100,
            badge: 'optional',
            tags: ['optional'],
            actionLabel: 'optional',
            rawPrice: 100,
            order: 1,
            data: {},
            actions: [{ type: 'book | view | open', label: 'optional', payload: {} }],
          },
        ],
      },
    ],
  }),
].join("\n");

/**
 * Real OpenAI-compatible AI provider (Phase 9).
 *
 * Uses the chat-completions REST protocol with the environment-provided API
 * key. The same implementation works for any OpenAI-compatible endpoint
 * (Groq, DeepSeek, OpenRouter, ...) by pointing AI_BASE_URL elsewhere.
 *
 * Never hardcodes API keys; the endpoint fails explicitly when AI_API_KEY is
 * missing. The provider identity never leaks into the response, so Flutter
 * stays provider-agnostic.
 */
@Injectable()
export class OpenAiAiProvider implements AiProvider {
  readonly providerId = 'openai-compatible';
  readonly providerName = 'OpenAI-compatible AI';

  private readonly apiKey: string | undefined;
  private readonly baseUrl: string;
  private readonly model: string;

  constructor(private readonly config: ConfigService) {
    this.apiKey = config.get<string>('AI_API_KEY');
    this.baseUrl = (
      config.get<string>('AI_BASE_URL') ?? DEFAULT_BASE_URL
    ).replace(/\/+$/, '');
    this.model = config.get<string>('AI_MODEL') ?? DEFAULT_MODEL;
  }

  async generate(prompt: string, systemPrompt?: string): Promise<AiResponseDto> {
    const key = this.apiKey;
    if (!key) {
      // A missing key is a deployment mistake, not a transient outage: failing
      // fast surfaces the misconfiguration instead of quietly serving fallback
      // answers forever.
      throw new AiProviderFailure(
        'AI provider is not configured: AI_API_KEY is missing.',
        { category: 'not_configured' },
      );
    }

    try {
      // Phase 2C-B: a caller may LAYER a conversation-memory context block on
      // top of the base system prompt. The base prompt is never replaced —
      // memory context is additive, and the merged prompt stays a single
      // system message so the chat-completions contract is unchanged.
      const system = systemPrompt
        ? `${SYSTEM_PROMPT}\n\n${systemPrompt}`
        : SYSTEM_PROMPT;
      const response = await fetch(`${this.baseUrl}/chat/completions`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${key}`,
        },
        body: JSON.stringify({
          model: this.model,
          temperature: 0.2,
          messages: [
            { role: 'system', content: system },
            { role: 'user', content: prompt },
          ],
        }),
        signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
      });

      if (!response.ok) {
        // 5xx is transient and may be retried elsewhere; 4xx means the request
        // itself was rejected, so another provider would fail the same way.
        throw new AiProviderFailure(
          `AI provider request failed (HTTP ${response.status}).`,
          {
            category: response.status >= 500 ? 'upstream_5xx' : 'upstream_4xx',
            upstreamStatus: response.status,
          },
        );
      }

      const payload = (await response.json()) as {
        choices?: Array<{ message?: { content?: unknown } }>;
      };
      const content: unknown = payload?.choices?.[0]?.message?.content;
      if (typeof content !== 'string' || content.trim().length === 0) {
        throw new AiProviderFailure(
          'AI provider returned an empty completion.',
          { category: 'empty_completion', upstreamStatus: response.status },
        );
      }
      return normalizeAiResponse(content);
    } catch (cause) {
      // A failure already classified by this provider (HTTP status, empty
      // completion) is re-thrown untouched.
      if (cause instanceof AiProviderFailure) {
        throw cause;
      }
      // AbortSignal.timeout can fire while waiting for headers or while
      // reading the body (response.json()). Both surface as Timeout/Abort
      // errors, so classify them as `timeout` — a retryable category that lets
      // the configured fallback provider serve the request instead of failing.
      if (isRequestTimeout(cause)) {
        throw new AiProviderFailure('AI provider request timed out.', {
          category: 'timeout',
        });
      }
      // Connection refused, DNS failure, TLS failure. The cause is deliberately
      // not interpolated: it can carry the resolved host and port. Both cases
      // are transient, so a fallback is allowed.
      throw new AiProviderFailure('AI provider could not be reached.', {
        category: 'network',
      });
    }
  }
}

// ---------------------------------------------------------------------------// Normalization: raw LLM output → AiResponseDto (provider-agnostic).// ---------------------------------------------------------------------------//

/**
 * Extracts pure JSON from the model's response, handling various formats:
 * - Fenced code blocks (```json ... ``` or ``` ... ```)
 * - Inline JSON at the start of the response
 * - Strips leading/trailing whitespace and commentary
 */
export function extractJsonContent(content: string): string {
  const trimmed = content.trim();

  // 1. Try to extract from fenced code blocks (```json ... ``` or ``` ... ```)
  const fencedMatch = trimmed.match(/```(?:json)?\s*([\s\S]*?)\s*```/i);
  if (fencedMatch) {
    return fencedMatch[1].trim();
  }

  // 2. Try to find the first { ... } balanced pair (simple approach)
  //    This handles cases where the model returns text before/after the JSON.
  const firstBrace = trimmed.indexOf('{');
  const lastBrace = trimmed.lastIndexOf('}');
  if (firstBrace >= 0 && lastBrace > firstBrace) {
    const candidate = trimmed.substring(firstBrace, lastBrace + 1);
    // Quick check: if it starts with { and has key-value pairs, treat as JSON candidate
    if (candidate.startsWith('{')) {
      return candidate;
    }
  }

  // 3. Return trimmed content as-is (caller will attempt JSON parse)
  return trimmed;
}

export function tryParseJson(value: string): unknown {
  try {
    return JSON.parse(value);
  } catch {
    return null;
  }
}

export function asRecord(value: unknown): Record<string, any> | null {
  return value !== null &&
    typeof value === 'object' &&
    !Array.isArray(value)
    ? (value as Record<string, any>)
    : null;
}

export function asString(value: unknown): string | undefined {
  return typeof value === 'string' ? value : undefined;
}

export function asNumber(value: unknown): number | undefined {
  if (typeof value === 'number') return value;
  if (typeof value === 'string') {
    const n = Number(value);
    return Number.isFinite(n) ? n : undefined;
  }
  return undefined;
}

/**
 * Parses and hard-normalizes the model's JSON answer into an [AiResponseDto].
 *
 * Anything outside the contract (bad card types, malformed items, unsupported
 * layouts) is dropped rather than propagated, so the Flutter contract can
 * never see provider-specific shapes.
 *
 * Safety rules:
 * - Never returns raw provider output verbatim.
 * - Falls back to a safe, provider-agnostic text when parsing fails.
 * - Strips any provider-identifying metadata from the fallback.
 */
export function normalizeAiResponse(content: string): AiResponseDto {
  const jsonContent = extractJsonContent(content);
  const parsed = tryParseJson(jsonContent);
  const record = asRecord(parsed);
  if (!record) {
    // Parsing failed entirely - return safe fallback with no provider leakage.
    return {
      text: "I received a response from the AI assistant, but I couldn't parse the suggestions at this time. Please try again.",
      sections: [],
      metadata: { queryId: randomUUID(), version: 1, parseFallback: true },
    };
  }

  // Ensure text is a clean string (fallback if missing or non-string)
  const text = asString(record.text) || "I received a response from the AI assistant.";

  const sections: AiSectionDto[] = [];
  if (Array.isArray(record.sections)) {
    for (const raw of record.sections) {
      const section = toSection(raw);
      if (section) sections.push(section);
    }
  }

  return {
    text,
    sections,
    metadata: { queryId: randomUUID(), version: 1 },
  };
}

function toSection(value: unknown): AiSectionDto | null {
  const record = asRecord(value);
  if (!record) return null;

  const title = asString(record.title);
  if (!title) return null;

  const rawLayout = asString(record.layout);
  const layout: AiSectionDto['layout'] =
    rawLayout !== undefined && ALLOWED_LAYOUTS.has(rawLayout as AiSectionDto['layout'])
      ? (rawLayout as AiSectionDto['layout'])
      : 'vertical';

  const section: AiSectionDto = { title, layout, items: [], metadata: {} };

  const id = asString(record.id);
  if (id !== undefined) section.id = id;
  const subtitle = asString(record.subtitle);
  if (subtitle !== undefined) section.subtitle = subtitle;
  const order = asNumber(record.order);
  if (order !== undefined) section.order = order;

  if (Array.isArray(record.items)) {
    for (const rawItem of record.items) {
      const item = toItem(rawItem);
      if (item) section.items.push(item);
    }
  }
  return section;
}

function toItem(value: unknown): AiItemDto | null {
  const record = asRecord(value);
  if (!record) return null;

  const id = asString(record.id);
  const type = asString(record.type);
  const title = asString(record.title);
  if (!id || !type || !title || !ALLOWED_CARD_TYPES.has(type)) return null;

  const item: AiItemDto = { id, type, title };

  const subtitle = asString(record.subtitle);
  if (subtitle !== undefined) item.subtitle = subtitle;
  const description = asString(record.description);
  if (description !== undefined) item.description = description;
  const imageUrl = asString(record.imageUrl);
  if (imageUrl !== undefined) item.imageUrl = imageUrl;
  const price = asNumber(record.price);
  if (price !== undefined) item.price = price;
  const currency = asString(record.currency);
  if (currency !== undefined) item.currency = currency;
  const rating = asNumber(record.rating);
  if (rating !== undefined) item.rating = rating;
  const reviewCount = asNumber(record.reviewCount);
  if (reviewCount !== undefined) item.reviewCount = reviewCount;
  const badge = asString(record.badge);
  if (badge !== undefined) item.badge = badge;
  const actionLabel = asString(record.actionLabel);
  if (actionLabel !== undefined) item.actionLabel = actionLabel;
  const rawPrice = asNumber(record.rawPrice);
  if (rawPrice !== undefined) item.rawPrice = rawPrice;
  const order = asNumber(record.order);
  if (order !== undefined) item.order = order;
  const data = asRecord(record.data);
  if (data) item.data = data;
  const metadata = asRecord(record.metadata);
  if (metadata) item.metadata = metadata;

  if (Array.isArray(record.highlights)) {
    item.highlights = record.highlights
      .filter((h): h is string => typeof h === 'string')
      .slice(0, 20);
  }
  if (Array.isArray(record.tags)) {
    item.tags = record.tags
      .filter((t): t is string => typeof t === 'string')
      .slice(0, 20);
  }
  if (Array.isArray(record.actions)) {
    const actions: AiActionDto[] = [];
    for (const rawAction of record.actions) {
      const action = toAction(rawAction);
      if (action) actions.push(action);
    }
    if (actions.length > 0) item.actions = actions;
  }

  return item;
}

function toAction(value: unknown): AiActionDto | null {
  const record = asRecord(value);
  if (!record) return null;
  const type = asString(record.type);
  if (!type) return null;

  const action: AiActionDto = { type };
  const label = asString(record.label);
  if (label !== undefined) action.label = label;
  const payload = asRecord(record.payload);
  if (payload) action.payload = payload;
  return action;
}
