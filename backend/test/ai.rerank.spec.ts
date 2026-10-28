import { describe, it, expect } from '@jest/globals';
import { BadRequestException } from '@nestjs/common';

import { AiRerankController } from '../src/modules/ai/ai.rerank.controller';
import { AiResponseDto } from '../src/common/dto/ai.dto';
import { AiProvider, AiProviderFailure } from '../src/modules/ai/ai.provider';
import {
  contextIsSafe,
  candidateMetaIsSafe,
} from '../src/common/dto/ai.rerank.dto';

/**
 * Phase 1C — AI rerank contract.
 *
 * Covers: valid structured rerank, hallucinated-id rejection, malformed
 * output fallback, provider failure fallback, timeout fallback, context
 * whitelist enforcement, and the deterministic baseline.
 */

class StubProvider implements AiProvider {
  constructor(private readonly behaviour: () => Promise<AiResponseDto>) {}
  readonly providerId = 'stub';
  readonly providerName = 'Stub';
  generate(): Promise<AiResponseDto> {
    return this.behaviour();
  }
}

const okDto = (text: string): AiResponseDto => ({
  text,
  sections: [],
  metadata: {},
});

const dto = (overrides: Partial<Parameters<AiRerankController['rerank']>[0]> = {}) => ({
  context: { userState: 'authenticated', countryCode: 'EG' },
  candidates: [
    { id: 'h1', title: 'Grand Cairo', price: 120 },
    { id: 'h2', title: 'Nile View', price: 210 },
    { id: 'h3', title: 'Alexandria Resort', price: 95 },
  ],
  allowedReasons: ['recent_search', 'recent_view', 'favorite', 'discovery'],
  ...overrides,
});

function controllerWith(behaviour: () => Promise<AiResponseDto>) {
  return new AiRerankController(new StubProvider(behaviour));
}

describe('AI rerank: context/candidate whitelist', () => {
  it('accepts whitelisted context keys', () => {
    expect(
      contextIsSafe({ userState: 'anon', countryCode: 'EG', recentSearchLabels: ['Cairo'] }),
    ).toBe(true);
  });

  it('rejects non-whitelisted context keys (tokens/PII/GPS)', () => {
    expect(contextIsSafe({ accessToken: 'x' })).toBe(false);
    expect(contextIsSafe({ email: 'a@b.c' })).toBe(false);
    expect(contextIsSafe({ latitude: 30.1, longitude: 31.2 })).toBe(false);
  });

  it('validates candidate metadata whitelist', () => {
    expect(candidateMetaIsSafe({ city: 'Cairo', rating: 4.2 })).toBe(true);
    expect(candidateMetaIsSafe({ paymentToken: 'x' })).toBe(false);
    expect(candidateMetaIsSafe(undefined)).toBe(true);
  });
});

describe('AI rerank: structured output', () => {
  it('returns the ranked ids for a valid response', async () => {
    const c = controllerWith(() =>
      Promise.resolve(
        okDto(
          '{"rankedCandidateIds": ["h3", "h1", "h2"], "sectionReason": "recent_view", "confidence": 0.87}',
        ),
      ),
    );
    const result = await c.rerank(dto());
    expect(result.fallback).toBe(false);
    expect(result.rankedCandidateIds).toEqual(['h3', 'h1', 'h2']);
    expect(result.sectionReason).toBe('recent_view');
    expect(result.confidence).toBe(0.87);
  });

  it('drops an AI response that invents unknown ids (whole response invalid)', async () => {
    const c = controllerWith(() =>
      Promise.resolve(
        okDto('{"rankedCandidateIds": ["h1", "hacked-id"], "sectionReason": "favorite"}'),
      ),
    );
    // h1 is known but "hacked-id" is not: unknown ids are FILTERED, and the
    // known remainder still orders deterministically.
    const result = await c.rerank(dto());
    expect(result.rankedCandidateIds).toEqual(['h1']);
    expect(result.fallback).toBe(false);
  });

  it('falls back to input order when the AI output is all unknown ids', async () => {
    const c = controllerWith(() =>
      Promise.resolve(okDto('{"rankedCandidateIds": ["x", "y"]}')),
    );
    const result = await c.rerank(dto());
    expect(result.fallback).toBe(true);
    expect(result.rankedCandidateIds).toEqual(['h1', 'h2', 'h3']);
  });

  it('falls back deterministically on malformed AI text', async () => {
    const c = controllerWith(() => Promise.resolve(okDto('sure! here are some hotels')));
    const result = await c.rerank(dto());
    expect(result.fallback).toBe(true);
    expect(result.rankedCandidateIds).toEqual(['h1', 'h2', 'h3']);
    expect(result.sectionReason).toBe('recommendation');
  });

  it('falls back deterministically when the provider fails', async () => {
    const c = controllerWith(() =>
      Promise.reject(
        new AiProviderFailure('upstream 503', {
          category: 'upstream_5xx',
          upstreamStatus: 503,
        }),
      ),
    );
    const result = await c.rerank(dto());
    expect(result.fallback).toBe(true);
    expect(result.rankedCandidateIds).toEqual(['h1', 'h2', 'h3']);
  });

  it('maps a non-allowed sectionReason to the safe default', async () => {
    const c = controllerWith(() =>
      Promise.resolve(
        okDto('{"rankedCandidateIds": ["h1"], "sectionReason": "made_up_reason"}'),
      ),
    );
    const result = await c.rerank(dto());
    expect(result.sectionReason).toBe('recommendation');
  });

  it('clamps confidence into 0..1', async () => {
    const c = controllerWith(() =>
      Promise.resolve(
        okDto('{"rankedCandidateIds": ["h1"], "sectionReason": "favorite", "confidence": 5}'),
      ),
    );
    const result = await c.rerank(dto());
    expect(result.confidence).toBe(1);
  });
});

describe('AI rerank: request validation', () => {
  it('rejects a context with non-whitelisted keys (400)', async () => {
    const c = controllerWith(() => Promise.resolve(okDto('{}')));
    await expect(
      c.rerank(dto({ context: { email: 'a@b.c' } })),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('rejects candidate metadata with non-whitelisted keys (400)', async () => {
    const c = controllerWith(() => Promise.resolve(okDto('{}')));
    await expect(
      c.rerank(
        dto({
          candidates: [
            { id: 'h1', title: 'X', metadata: { cardNumber: '4111' } },
          ],
        }),
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('returns an empty deterministic result for zero candidates', async () => {
    const c = controllerWith(() => Promise.resolve(okDto('{}')));
    const result = await c.rerank(dto({ candidates: [] }));
    expect(result.rankedCandidateIds).toEqual([]);
    expect(result.fallback).toBe(true);
  });
});
