import { describe, it, expect } from '@jest/globals';

import { AiService } from '../src/modules/ai/ai.service';

/**
 * /ai/suggest typeahead contract — the smart search sheet's live backend.
 * The endpoint must stay fast, bilingual (AR/EN) and deterministic: it is a
 * template catalogue match, never an LLM call.
 */
describe('AiService.suggest', () => {
  it('returns default prompts for a too-short query', async () => {
    const service = new AiService(undefined as any, undefined as any);
    const result = await service.suggest('a');
    expect(result.length).toBeGreaterThan(0);
    expect(result.length).toBeLessThanOrEqual(6);
  });

  it('matches English flight prompts by substring', async () => {
    const service = new AiService(undefined as any, undefined as any);
    const result = await service.suggest('flights to dubai');
    expect(result.length).toBeGreaterThan(0);
    expect(result[0].toLowerCase()).toContain('dubai');
  });

  it('matches Arabic hotel prompts by substring', async () => {
    const service = new AiService(undefined as any, undefined as any);
    const result = await service.suggest('فنادق في دبي');
    expect(result.length).toBeGreaterThan(0);
    expect(result[0]).toContain('فنادق');
    expect(result[0]).toContain('دبي');
  });

  it('ranks direct substring matches above token-overlap matches', async () => {
    const service = new AiService(undefined as any, undefined as any);
    const result = await service.suggest('hotels in dubai');
    expect(result[0].toLowerCase()).toContain('dubai');
    // Direct containment should outrank token-overlap-only matches.
    expect(result[0].toLowerCase()).toContain('hotels in dubai');
  });

  it('falls back to default prompts when nothing matches', async () => {
    const service = new AiService(undefined as any, undefined as any);
    const result = await service.suggest('zzzzqqqxxx');
    expect(result.length).toBeGreaterThan(0);
    expect(result.length).toBeLessThanOrEqual(6);
  });

  it('never returns more than six suggestions', async () => {
    const service = new AiService(undefined as any, undefined as any);
    const result = await service.suggest('في');
    expect(result.length).toBeLessThanOrEqual(6);
  });
});
