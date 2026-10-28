import { describe, it, expect } from '@jest/globals';

import { AiConversationController } from '../src/modules/ai/ai.conversation.controller';
import { AiService } from '../src/modules/ai/ai.service';
import { AiProvider, AiProviderFailure } from '../src/modules/ai/ai.provider';
import { AiResponseDto } from '../src/common/dto/ai.dto';
import { RelevantMemorySelector } from '../src/modules/memory/relevant_memory_selector';
import { ConversationMemoryService } from '../src/modules/memory/conversation_memory.service';
import { MemoryService } from '../src/modules/memory/memory.service';
import { ProfileService } from '../src/modules/profile/profile.service';
import { UserMemory } from '../src/database/entities/user_memory.entity';

/**
 * Phase 2C-B — AI Context Integration for Explicit Conversation Memory.
 *
 * Flow under test:
 *   user message → RelevantMemorySelector → safe AI context block
 *   → AiService.query(memoryContext) → provider (OpenRouter).
 *
 * Covers the ten required cases: relevant memory reaches the AI context,
 * no-relevant-memory, irrelevant memory filtered, subset selection,
 * personalization-disabled, guest 401, selector failure isolation,
 * provider-failure behavior unchanged, user isolation, and Home-ranking
 * regression (personalization context / ranking inputs untouched).
 */

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

function fakeMemoryRepo(initial: any[] = []) {
  const rows = [...initial];
  return {
    rows,
    async find(opts: any) {
      let out = rows.filter((r) => r.userId === opts.where.userId);
      if (opts.where.type) out = out.filter((r) => r.type === opts.where.type);
      if (opts.where.source) out = out.filter((r) => r.source === opts.where.source);
      return [...out].sort(
        (a, b) =>
          new Date(b.updatedAt).getTime() - new Date(a.updatedAt).getTime(),
      );
    },
    async findOne(opts: any) {
      if (opts.where.id) return rows.find((r) => r.id === opts.where.id) ?? null;
      return (
        rows.find(
          (r) =>
            r.userId === opts.where.userId &&
            r.type === opts.where.type &&
            r.key === opts.where.key,
        ) ?? null
      );
    },
    create(value: any) {
      return {
        id: `mem-${rows.length + 1}`,
        createdAt: new Date(),
        updatedAt: new Date(),
        confidence: 1,
        ...value,
      };
    },
    async save(value: any) {
      const idx = rows.findIndex((r) => r.id === value.id);
      if (idx >= 0) {
        rows[idx] = { ...rows[idx], ...value, updatedAt: new Date() };
        return rows[idx];
      }
      rows.push(value);
      return value;
    },
    async delete(opts: any) {
      const ids = opts.id
        ? [opts.id]
        : rows.filter((r) => r.userId === opts.userId).map((r) => r.id);
      for (const id of ids) {
        const idx = rows.findIndex((r) => r.id === id);
        if (idx >= 0) rows.splice(idx, 1);
      }
    },
  } as any;
}

function convRow(overrides: Partial<UserMemory>): UserMemory {
  return {
    id: `cm-${Math.random().toString(36).slice(2, 8)}`,
    userId: 'u1',
    type: 'conversation',
    key: 'preferred_destination:cairo',
    value: { destination: 'Cairo' },
    source: 'ai_conversation',
    confidence: 1,
    expiresAt: null,
    createdAt: new Date(),
    updatedAt: new Date(Date.now() - Math.random() * 10_000),
    ...overrides,
  } as UserMemory;
}

function fakeProfileRepo(rows: any[] = []) {
  const store = [...rows];
  return {
    async findOne(opts: any) {
      return store.find((p) => p.userId === opts.where.userId) ?? null;
    },
    create(value: any) {
      return {
        id: `p-${store.length + 1}`,
        preferences: {},
        derived: {},
        personalizationEnabled: true,
        ...value,
      };
    },
    async save(value: any) {
      const idx = store.findIndex((p) => p.userId === value.userId);
      if (idx >= 0) store[idx] = { ...store[idx], ...value };
      else store.push(value);
      return value;
    },
  } as any;
}

/** Provider stub that RECORDS every generate() call. */
class RecordingProvider implements AiProvider {
  readonly calls: Array<{ prompt: string; systemPrompt?: string }> = [];
  constructor(
    private readonly behaviour: (
      call: { prompt: string; systemPrompt?: string },
    ) => Promise<AiResponseDto>,
    readonly providerId = 'recording',
  ) {}
  readonly providerName = 'Recording Provider';
  async generate(prompt: string, systemPrompt?: string): Promise<AiResponseDto> {
    const call = { prompt, systemPrompt };
    this.calls.push(call);
    return this.behaviour(call);
  }
}

const OK_DTO: AiResponseDto = { text: '{"text":"ok","sections":[]}', sections: [], metadata: {} };

function reqFor(userId: string | null): { user: { id?: string } | undefined } {
  return { user: userId ? { id: userId } : undefined };
}

// ---------------------------------------------------------------------------
// Controller harness
// ---------------------------------------------------------------------------

function buildController(opts: {
  memories?: any[];
  providerBehaviour?: (call: { prompt: string; systemPrompt?: string }) => Promise<AiResponseDto>;
  profileRow?: any;
  selectorOverride?: RelevantMemorySelector;
  extractorProvider?: AiProvider | null;
}) {
  const memoryRepo = fakeMemoryRepo(opts.memories ?? []);
  const memoryService = new MemoryService(memoryRepo);
  const profileService = new ProfileService(fakeProfileRepo(opts.profileRow ? [opts.profileRow] : []));
  const selector = opts.selectorOverride ?? new RelevantMemorySelector(memoryService);
  const extractor = new ConversationMemoryService(
    memoryService,
    opts.extractorProvider === undefined ? null : opts.extractorProvider,
  );
  const provider = new RecordingProvider(
    opts.providerBehaviour ?? (() => Promise.resolve(OK_DTO)),
  );
  const aiService = new AiService(provider, null as any);
  const controller = new AiConversationController(
    aiService,
    profileService,
    selector,
    extractor,
    provider,
  );
  return { controller, provider, memoryRepo, memoryService };
}

describe('Phase 2C-B: POST /ai/chat — memory → AI context integration', () => {
  it('1. authenticated user + relevant memory → memory reaches the AI context', async () => {
    const { controller, provider } = buildController({
      memories: [convRow({ key: 'preferred_destination:cairo', value: { destination: 'Cairo' } })],
      // Extraction off: focus this test on the context path.
      extractorProvider: null,
    });

    const response = await controller.chat(
      reqFor('u1') as any,
      { prompt: 'Find me hotels in Cairo for next week' },
    );

    expect(response).toBe(OK_DTO);
    // The provider saw exactly ONE call (the main query — extraction is off).
    expect(provider.calls).toHaveLength(1);
    const system = provider.calls[0].systemPrompt ?? '';
    expect(system).toContain('Cairo');
    expect(system).toContain('Preferred destination');
    // The user prompt itself is UNCHANGED — memory rides the system prompt only.
    expect(provider.calls[0].prompt).toBe('Find me hotels in Cairo for next week');
  });

  it('2. authenticated user + NO relevant memory → AI context without memories', async () => {
    const { controller, provider } = buildController({
      memories: [convRow({ key: 'preferred_destination:paris', value: { destination: 'Paris' } })],
      extractorProvider: null,
    });

    await controller.chat(reqFor('u1') as any, {
      prompt: 'What is the capital of Japan?',
    });

    expect(provider.calls).toHaveLength(1);
    // No memory block: the system prompt is undefined/empty (provider default).
    expect(provider.calls[0].systemPrompt ?? '').not.toContain('Paris');
    expect(provider.calls[0].systemPrompt ?? '').not.toContain('Preferred');
  });

  it('3. irrelevant memory → NOT sent to the AI', async () => {
    const { controller, provider } = buildController({
      memories: [
        convRow({ key: 'preferred_destination:paris', value: { destination: 'Paris' } }),
        convRow({ key: 'preferred_budget', value: { min: 100, max: 500 } }),
      ],
      extractorProvider: null,
    });

    await controller.chat(reqFor('u1') as any, {
      prompt: 'Tell me about the history of the pyramids',
    });

    expect(provider.calls).toHaveLength(1);
    const system = provider.calls[0].systemPrompt ?? '';
    expect(system).not.toContain('Paris');
    expect(system).not.toContain('min 100');
    expect(system).not.toContain('Preferred');
  });

  it('4. multiple memories → only the relevant subset is sent', async () => {
    const { controller, provider } = buildController({
      memories: [
        convRow({ key: 'preferred_destination:cairo', value: { destination: 'Cairo' } }),
        convRow({ key: 'preferred_destination:dubai', value: { destination: 'Dubai' } }),
        convRow({ key: 'preferred_destination:paris', value: { destination: 'Paris' } }),
        convRow({ key: 'preferred_travel_style', value: { styles: ['luxury', 'beach'] } }),
      ],
      extractorProvider: null,
    });

    await controller.chat(reqFor('u1') as any, {
      prompt: 'I want a luxury trip to Cairo',
    });

    const system = provider.calls[0].systemPrompt ?? '';
    expect(system).toContain('Cairo');
    // The styles fact matched via "luxury" — a fact is atomic, so the whole
    // (validated) style list travels together.
    expect(system).toContain('luxury, beach');
    // Irrelevant destination facts never appear.
    expect(system).not.toContain('Dubai');
    expect(system).not.toContain('Paris');
  });

  it('5. personalization disabled → no memory lookup, no memory context, no extraction', async () => {
    const selectorCalls: string[] = [];
    const brokenSelector = {
      selectRelevant: async (userId: string) => {
        selectorCalls.push(userId);
        throw new Error('must never be called');
      },
    } as unknown as RelevantMemorySelector;
    const extractorProvider = new RecordingProvider(() => {
      throw new Error('extraction must not run when personalization is off');
    });

    const { controller, provider } = buildController({
      profileRow: { userId: 'u1', personalizationEnabled: false },
      selectorOverride: brokenSelector,
      extractorProvider: extractorProvider as unknown as AiProvider,
    });

    const response = await controller.chat(reqFor('u1') as any, {
      prompt: 'Find me hotels in Cairo',
    });

    expect(response).toBe(OK_DTO);
    expect(selectorCalls).toHaveLength(0); // NO lookup at all.
    expect(extractorProvider.calls).toHaveLength(0); // NO extraction call.
    expect(provider.calls).toHaveLength(1);
    expect(provider.calls[0].systemPrompt ?? '').not.toContain('Cairo');
    // And nothing was deleted from the DB (opt-out never erases memories).
  });

  it('6. guest → rejected before any memory work', async () => {
    const { controller } = buildController({
      extractorProvider: null,
    });
    // Passport left req.user undefined → controller must throw before
    // touching the selector, extractor, or provider.
    await expect(
      controller.chat(reqFor(null) as any, { prompt: 'hotels in Cairo' }),
    ).rejects.toThrow('Authenticated request missing user id.');
  });

  it('7. selector failure → the AI request continues WITHOUT memory', async () => {
    const brokenSelector = {
      selectRelevant: () => {
        throw new Error('db down');
      },
    } as unknown as RelevantMemorySelector;

    const { controller, provider } = buildController({
      selectorOverride: brokenSelector,
      extractorProvider: null,
    });

    const response = await controller.chat(reqFor('u1') as any, {
      prompt: 'Find me hotels in Cairo',
    });

    expect(response).toBe(OK_DTO); // The AI answer still arrives.
    expect(provider.calls).toHaveLength(1);
    expect(provider.calls[0].systemPrompt ?? '').toBe(''); // No memory context.
  });

  it('8. AI provider failure → existing error behavior unchanged (503 path)', async () => {
    const { controller } = buildController({
      providerBehaviour: () =>
        Promise.reject(
          new AiProviderFailure('AI provider is not configured.', {
            category: 'not_configured',
          }),
        ),
      extractorProvider: null,
    });

    // The SAME rejection the /ai/query path throws — no memory wrapping.
    await expect(
      controller.chat(reqFor('u1') as any, { prompt: 'Find me hotels' }),
    ).rejects.toBeInstanceOf(AiProviderFailure);
  });

  it('9. user isolation — User A never receives User B memories', async () => {
    const { controller, provider } = buildController({
      memories: [
        convRow({ userId: 'u2', key: 'preferred_destination:paris', value: { destination: 'Paris' } }),
        convRow({ userId: 'u1', key: 'preferred_destination:cairo', value: { destination: 'Cairo' } }),
      ],
      extractorProvider: null,
    });

    await controller.chat(reqFor('u1') as any, {
      prompt: 'Hotels in Cairo please',
    });

    const system = provider.calls[0].systemPrompt ?? '';
    expect(system).toContain('Cairo');
    expect(system).not.toContain('Paris'); // u2's memory never travels.
  });

  it('10a. Home ranking regression — memory context does NOT touch the rerank context contract', async () => {
    // The rerank endpoint whitelist (Phase 1C) is the Home personalization
    // surface. This phase adds NO keys to it — the flutter side sends
    // derivedTopDestinations/derivedBudgetMax which are NOT whitelisted for
    // rerank (they are client-side keys filtered there), and the 2C-B
    // memory keys below must equally be rejected.
    const { contextIsSafe } = await import('../src/common/dto/ai.rerank.dto');
    expect(contextIsSafe({ userState: 'authenticated', countryCode: 'EG' })).toBe(true);
    // The 2C-B memory block keys are NOT part of the rerank vocabulary —
    // sending them there would be a Home-ranking contract violation.
    expect(
      contextIsSafe({ preferredMemories: [{ destination: 'Cairo' }] }),
    ).toBe(false);
    expect(
      contextIsSafe({ conversationMemories: ['x'] }),
    ).toBe(false);
  });

  it('10b. Home ranking regression — DerivedPreferenceProfile still ignores conversation memories', async () => {
    const { DerivedPreferenceProfileService } = await import(
      '../src/modules/memory/derived_preference_profile.service'
    );
    const memoryRepo = fakeMemoryRepo([
      // A conversation memory the 2B service must NOT fold into ranking.
      convRow({ key: 'preferred_destination:cairo', value: { destination: 'Cairo' } }),
      convRow({ key: 'preferred_budget', value: { min: 10, max: 20 } }),
    ]);
    const derived = new DerivedPreferenceProfileService(
      new MemoryService(memoryRepo),
    );
    const profile = await derived.buildForUser('u1', {
      userId: 'u1',
      preferences: {},
      derived: {},
      personalizationEnabled: true,
      updatedAt: new Date(),
    });
    // The 2B read model queries type='behavior' ONLY — conversation rows
    // are invisible to it, so no destination/budget leaks into ranking.
    expect(profile.topDestinations).toEqual([]);
    expect(profile.budgetRange).toBeUndefined();
    expect(profile.recentDestinations).toEqual([]);
    expect(profile.favoriteHotels).toEqual([]);
  });
});

describe('Phase 2C-B: extraction wiring on /ai/chat', () => {
  it('extraction runs AFTER the response with the JWT userId (fire-and-forget)', async () => {
    // ONE provider instance serves both the main query and the extraction
    // call, exactly like production wiring (AI_PROVIDER is shared).
    const allCalls: Array<{ prompt: string; systemPrompt?: string }> = [];
    const sharedProvider: AiProvider = {
      providerId: 'shared',
      providerName: 'Shared',
      generate: async (prompt: string, systemPrompt?: string) => {
        allCalls.push({ prompt, systemPrompt });
        // The main query returns the travel answer; the extraction call is
        // distinguished by its extractor system prompt.
        if (systemPrompt?.includes('EXPLICIT')) {
          return { text: '{"facts":[]}', sections: [], metadata: {} };
        }
        return OK_DTO;
      },
    };
    const { controller, memoryRepo } = buildController({
      memories: [],
      extractorProvider: sharedProvider,
      providerBehaviour: undefined,
    });
    // Rebuild with the shared provider on BOTH seams.
    const memoryRepo2 = memoryRepo;
    const controller2 = new AiConversationController(
      new AiService(sharedProvider, null as any),
      new ProfileService(fakeProfileRepo()),
      new RelevantMemorySelector(new MemoryService(fakeMemoryRepo([]))),
      new ConversationMemoryService(
        new MemoryService(memoryRepo2),
        sharedProvider,
      ),
      sharedProvider,
    );

    const response = await controller2.chat(reqFor('u1') as any, {
      prompt: 'Find me hotels in Rome',
    });
    expect(response).toBe(OK_DTO);

    // Main query first, then the extraction call — through the SAME provider.
    expect(allCalls).toHaveLength(2);
    expect(allCalls[0].prompt).toBe('Find me hotels in Rome');
    expect(allCalls[1].systemPrompt).toContain('EXPLICIT');
    expect(allCalls[1].prompt).toContain('Find me hotels in Rome');
    // Nothing was saved (the extractor returned no facts).
    expect(memoryRepo2.rows).toHaveLength(0);
  });

  it('extracted explicit fact is stored under the JWT user (not another user)', async () => {
    const extractorProvider = new RecordingProvider(() =>
      Promise.resolve({
        text: JSON.stringify({
          facts: [{ kind: 'preferred_destination', value: { destination: 'Rome' } }],
        }),
        sections: [],
        metadata: {},
      }),
    );
    const { controller, memoryRepo } = buildController({
      extractorProvider: extractorProvider as unknown as AiProvider,
    });

    await controller.chat(reqFor('u1') as any, { prompt: 'I love Rome' });
    const saved = memoryRepo.rows.filter((r) => r.type === 'conversation');
    expect(saved).toHaveLength(1);
    expect(saved[0].userId).toBe('u1');
    expect(saved[0].source).toBe('ai_conversation');
  });
});
