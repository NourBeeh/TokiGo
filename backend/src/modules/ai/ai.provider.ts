import { ServiceUnavailableException } from '@nestjs/common';

import { AiResponseDto } from '../../common/dto/ai.dto';

/** DI token so Phase 9 can bind Grok/Gemini/DeepSeek providers without
 *  touching the controller or the service. */
export const AI_PROVIDER = Symbol('AI_PROVIDER');

/**
 * DI token for the optional secondary provider used by the Phase 10C fallback
 * policy. The bound value is `null` when `AI_FALLBACK_PROVIDER` is empty, which
 * disables fallback entirely and restores single-provider behaviour.
 */
export const AI_FALLBACK_PROVIDER = Symbol('AI_FALLBACK_PROVIDER');

/**
 * AI provider abstraction.
 *
 * Every provider (mock today, real AI providers later) returns the same
 * normalized [AiResponseDto]; the provider identity never leaks into the
 * response so Flutter stays provider-agnostic.
 */
export interface AiProvider {
  readonly providerId: string;
  readonly providerName: string;

  /**
   * Produces a normalized [AiResponseDto] for the given prompt.
   *
   * [systemPrompt] is an OPTIONAL layered instruction block (Phase 2C-B
   * conversation-memory context). Providers that cannot carry it simply
   * ignore it — the base travel-assistant system prompt stays the default,
   * so the call is 100% backward-compatible.
   */
  generate(
    prompt: string,
    systemPrompt?: string,
    maxOutputTokens?: number,
  ): Promise<AiResponseDto>;
}

/**
 * Closed set of provider failure kinds.
 *
 * Doubles as the Phase 10D observability `category`: it is a fixed vocabulary,
 * so a log line can describe *what went wrong* without quoting any upstream
 * message, host or payload.
 */
export type AiFailureCategory =
  | 'not_configured'
  | 'network'
  | 'timeout'
  | 'upstream_4xx'
  | 'upstream_5xx'
  | 'empty_completion'
  | 'unexpected';

/**
 * Categories a second provider may be able to serve.
 *
 * Single source of truth for the Phase 10C policy: `retryable` is derived from
 * the category so the two can never disagree.
 */
const RETRYABLE_CATEGORIES: ReadonlySet<AiFailureCategory> = new Set<AiFailureCategory>([
  'network',
  'timeout',
  'upstream_5xx',
  'empty_completion',
]);

/**
 * A provider-level failure that states its kind and whether another provider
 * may be tried.
 *
 * Extends [ServiceUnavailableException] so `/ai/query` keeps answering 503 for
 * every provider problem exactly as before — the HTTP contract is unchanged.
 * The [category] is what lets [AiService] both honour the fallback policy and
 * log a useful reason: without it a 4xx and a 5xx upstream are
 * indistinguishable, because both previously collapsed into the same bare 503.
 *
 * [upstreamStatus] is the status the upstream provider returned, when the call
 * completed. It carries no response body, so no upstream payload or credential
 * can travel with the error.
 */
export class AiProviderFailure extends ServiceUnavailableException {
  constructor(
    message: string,
    params: { category: AiFailureCategory; upstreamStatus?: number },
  ) {
    super(message);
    this.category = params.category;
    this.upstreamStatus = params.upstreamStatus;
    this.retryable = RETRYABLE_CATEGORIES.has(params.category);
  }

  /** What kind of failure this was, from the fixed vocabulary. */
  readonly category: AiFailureCategory;

  /** True when the failure is transient and a secondary provider may help. */
  readonly retryable: boolean;

  /** Upstream HTTP status, when the request reached the provider. */
  readonly upstreamStatus?: number;
}

/** True when [error] is a provider failure that permits a fallback attempt. */
export function isFallbackEligible(error: unknown): boolean {
  return error instanceof AiProviderFailure && error.retryable;
}

/**
 * Classifies [error] for logging.
 *
 * Anything that is not an [AiProviderFailure] is a defect rather than a known
 * provider condition, so it is reported as `unexpected` — never by echoing the
 * thrown message, which could contain arbitrary text.
 */
export function categoryOf(error: unknown): AiFailureCategory {
  return error instanceof AiProviderFailure ? error.category : 'unexpected';
}

/** Upstream status when known, for observability only. */
export function upstreamStatusOf(error: unknown): number | undefined {
  return error instanceof AiProviderFailure ? error.upstreamStatus : undefined;
}
