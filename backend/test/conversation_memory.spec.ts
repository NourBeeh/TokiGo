import {
  CONVERSATION_FACT_KINDS,
  conversationFactKey,
  conversationKindFromKey,
  validateConversationFact,
} from '../src/modules/memory/conversation_facts';
import {
  ConversationMemoryService,
  parseExplicitFacts,
} from '../src/modules/memory/conversation_memory.service';
import { RelevantMemorySelector } from '../src/modules/memory/relevant_memory_selector';
import { MemoryService } from '../src/modules/memory/memory.service';
import { AiProvider, AiProviderFailure } from '../src/modules/ai/ai.provider';
import { AiResponseDto } from '../src/common/dto/ai.dto';
import { UserMemory } from '../src/database/entities/user_memory.entity';

/**
 * Phase 2C-A — Explicit AI Conversation Memory (backend).
 *
 * Covers the required matrix: explicit destination/budget/travel-style
 * extraction, multiple facts, unrelated → nothing, inferred → rejected,
 * invalid/oversized rejection, duplicate → update (upsert), extraction
 * isolation from the AI flow, and the selector's conversation-only scope,
 * expiry/ownership handling, and bounded relevant subset.
 */

function fakeMemoryRepo(initial: any[] = []) {
  const rows = [...initial];
  return {
    rows,
    async find(opts: any) {
      let out = rows.filter((r) => r.userId === opts.where.userId);
      if (opts.where.type) out = out.filter((r) => r.type === opts.where.type);
      if (opts.where.source) out = out.filter((r) => r.source === opts.where.source);
      if (opts.where.key) out = out.filter((r) => r.key === opts.where.key);
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

function memoryServiceWith(initial: any[] = []) {
  const repo = fakeMemoryRepo(initial);
  return { service: new MemoryService(repo), repo };
}

/** Stub provider that returns ONE fixed extractor answer. */
class StubExtractor implements AiProvider {
  constructor(
    private readonly behaviour: () => Promise<AiResponseDto>,
    readonly providerId = 'stub-extractor',
  ) {}
  readonly providerName = 'Stub Extractor';
  generate(): Promise<AiResponseDto> {
    return this.behaviour();
  }
}

const extractorAnswer = (facts: unknown[]): AiResponseDto => ({
  text: JSON.stringify({ facts }),
  sections: [],
  metadata: {},
});

const failingProvider = () =>
  Promise.reject(
    new AiProviderFailure('AI provider is not configured.', {
      category: 'not_configured',
    }),
  );

describe('Conversation fact vocabulary + validators', () => {
  it('exposes exactly the three Phase 2C kinds', () => {
    expect(CONVERSATION_FACT_KINDS).toEqual([
      'preferred_destination',
      'preferred_budget',
      'preferred_travel_style',
    ]);
    expect(
      (CONVERSATION_FACT_KINDS as string[]).includes('preferred_hotel_style'),
    ).toBe(false);
  });

  it('builds suffixed keys for destinations and bare keys otherwise', () => {
    expect(conversationFactKey('preferred_destination', 'Sharm El Sheikh'))
      .toBe('preferred_destination:sharm-el-sheikh');
    expect(conversationFactKey('preferred_budget', 'x')).toBe('preferred_budget');
    expect(conversationFactKey('preferred_travel_style', 'x'))
      .toBe('preferred_travel_style');
    expect(conversationKindFromKey('preferred_travel_style')).toBe('preferred_travel_style');
    expect(conversationKindFromKey('behavioral:cairo')).toBeNull();
  });

  it('accepts exactly the declared fields per fact kind', () => {
    expect(
      validateConversationFact('preferred_destination', { destination: 'Cairo' }).valid,
    ).toBe(true);
    expect(
      validateConversationFact('preferred_budget', { min: 100, max: 500 }).valid,
    ).toBe(true);
    expect(
      validateConversationFact('preferred_travel_style', {
        styles: ['luxury', 'adventure'],
      }).valid,
    ).toBe(true);
  });

  it('rejects unknown fields, wrong types, and empty facts', () => {
    expect(
      validateConversationFact('preferred_destination', {
        destination: 'Cairo',
        extra: 'x',
      }).valid,
    ).toBe(false);
    expect(
      validateConversationFact('preferred_budget', { min: 'cheap' }).valid,
    ).toBe(false);
    expect(
      validateConversationFact('preferred_travel_style', { styles: 'luxury' }).valid,
    ).toBe(false);
    expect(
      validateConversationFact('preferred_travel_style', { styles: [] }).valid,
    ).toBe(false);
    expect(
      validateConversationFact('preferred_destination', {}).valid,
    ).toBe(false);
  });

  it('rejects oversized values (destination > 80 chars, styles > 60 items)', () => {
    expect(
      validateConversationFact('preferred_destination', {
        destination: 'x'.repeat(81),
      }).valid,
    ).toBe(false);
    expect(
      validateConversationFact('preferred_destination', {
        destination: 'x'.repeat(80),
      }).valid,
    ).toBe(true);
    expect(
      validateConversationFact('preferred_travel_style', {
        styles: Array.from({ length: 61 }, () => 'style'),
      }).valid,
    ).toBe(false);
    expect(
      validateConversationFact('preferred_travel_style', {
        styles: Array.from({ length: 60 }, () => 'style'),
      }).valid,
    ).toBe(true);
  });

  it('rejects sensitive values through the Phase 2A scanner', () => {
    expect(
      validateConversationFact('preferred_destination', {
        destination: 'Cairo',
        password: 'x',
      }).valid,
    ).toBe(false);
  });

  it('Phase 4B: a budget currency is optional, normalized and allow-listed', () => {
    // Legacy budgets (no currency) stay valid.
    expect(
      validateConversationFact('preferred_budget', { min: 100, max: 500 }).valid,
    ).toBe(true);

    const normalized = validateConversationFact('preferred_budget', {
      min: 100,
      max: 500,
      currency: 'usd',
    });
    expect(normalized.valid).toBe(true);
    expect(normalized.value?.currency).toBe('USD');

    // An unknown currency is DROPPED, not invented and not fatal: the bounds
    // survive, the budget simply cannot filter anything.
    const dropped = validateConversationFact('preferred_budget', {
      min: 100,
      currency: 'XYZ',
    });
    expect(dropped.valid).toBe(true);
    expect(dropped.value?.currency).toBeUndefined();
    expect(dropped.value?.min).toBe(100);

    // A wrong TYPE is still a malformed fact.
    expect(
      validateConversationFact('preferred_budget', {
        min: 100,
        currency: 300,
      }).valid,
    ).toBe(false);
  });
});

describe('parseExplicitFacts — strict extractor output contract', () => {
  it('parses valid facts of every kind', () => {
    const facts = parseExplicitFacts(
      JSON.stringify({
        facts: [
          { kind: 'preferred_destination', value: { destination: 'Cairo' } },
          { kind: 'preferred_budget', value: { min: 50, max: 300 } },
          { kind: 'preferred_travel_style', value: { styles: ['luxury'] } },
        ],
      }),
    );
    expect(facts).toHaveLength(3);
    expect(facts[0].kind).toBe('preferred_destination');
  });

  it('drops unknown kinds, malformed entries, and non-JSON text', () => {
    expect(
      parseExplicitFacts(
        JSON.stringify({
          facts: [
            { kind: 'preferred_hotel_style', value: { style: 'boutique' } },
            { kind: 'preferred_destination' },
            'garbage',
          ],
        }),
      ),
    ).toEqual([]);
    expect(parseExplicitFacts('not json at all')).toEqual([]);
    expect(parseExplicitFacts('')).toEqual([]);
  });
});

describe('ConversationMemoryService — explicit extraction + storage', () => {
  it('saves an explicit destination as conversation/ai_conversation', async () => {
    const { service } = memoryServiceWith();
    const extractor = new ConversationMemoryService(
      service,
      new StubExtractor(() =>
        Promise.resolve(
          extractorAnswer([
            { kind: 'preferred_destination', value: { destination: 'Cairo' } },
          ]),
        ),
      ),
    );
    const saved = await extractor.extractFromMessage('u1', 'I love Cairo, take me there');
    expect(saved).toHaveLength(1);
    expect(saved[0].type).toBe('conversation');
    expect(saved[0].source).toBe('ai_conversation');
    expect(saved[0].key).toBe('preferred_destination:cairo');
    expect(saved[0].value).toEqual({ destination: 'Cairo' });
    expect(saved[0].confidence).toBe(1);
  });

  it('saves an explicit budget', async () => {
    const { service } = memoryServiceWith();
    const extractor = new ConversationMemoryService(
      service,
      new StubExtractor(() =>
        Promise.resolve(
          extractorAnswer([{ kind: 'preferred_budget', value: { min: 100, max: 500 } }]),
        ),
      ),
    );
    const saved = await extractor.extractFromMessage('u1', 'My budget is 100-500');
    expect(saved).toHaveLength(1);
    expect(saved[0].key).toBe('preferred_budget');
    expect(saved[0].value).toEqual({ min: 100, max: 500 });
  });

  it('saves an explicit travel style', async () => {
    const { service } = memoryServiceWith();
    const extractor = new ConversationMemoryService(
      service,
      new StubExtractor(() =>
        Promise.resolve(
          extractorAnswer([
            { kind: 'preferred_travel_style', value: { styles: ['adventure', 'budget'] } },
          ]),
        ),
      ),
    );
    const saved = await extractor.extractFromMessage('u1', 'I like adventure travel');
    expect(saved).toHaveLength(1);
    expect(saved[0].key).toBe('preferred_travel_style');
    expect(saved[0].value).toEqual({ styles: ['adventure', 'budget'] });
  });

  it('saves multiple facts from one message', async () => {
    const { service } = memoryServiceWith();
    const extractor = new ConversationMemoryService(
      service,
      new StubExtractor(() =>
        Promise.resolve(
          extractorAnswer([
            { kind: 'preferred_destination', value: { destination: 'Dubai' } },
            { kind: 'preferred_budget', value: { max: 2000 } },
            { kind: 'preferred_travel_style', value: { styles: ['luxury'] } },
          ]),
        ),
      ),
    );
    const saved = await extractor.extractFromMessage('u1', 'Dubai, max 2000, luxury');
    expect(saved).toHaveLength(3);
    expect(saved.map((m: UserMemory) => m.key).sort()).toEqual([
      'preferred_budget',
      'preferred_destination:dubai',
      'preferred_travel_style',
    ]);
  });

  it('unrelated conversation → no memory (empty facts)', async () => {
    const { service } = memoryServiceWith();
    const extractor = new ConversationMemoryService(
      service,
      new StubExtractor(() => Promise.resolve(extractorAnswer([]))),
    );
    const saved = await extractor.extractFromMessage('u1', 'What is the weather like?');
    expect(saved).toEqual([]);
    expect(service).toBeDefined();
  });

  it('inferred preference (extractor did not mark it explicit) is never saved', async () => {
    const { service, repo } = memoryServiceWith();
    // The extractor returns an "inferred" flag the contract forbids — the
    // parser only reads kind+value, so the only way an inference reaches
    // storage is if the MODEL violated the contract. Guard: a fact whose
    // value does not validate is skipped; and here we simulate the model
    // returning a behavioural fact kind (preferred_hotel_style — deferred),
    // which parseExplicitFacts must drop entirely.
    const extractor = new ConversationMemoryService(
      service,
      new StubExtractor(() =>
        Promise.resolve(
          extractorAnswer([
            { kind: 'preferred_hotel_style', value: { style: 'boutique' } },
          ]),
        ),
      ),
    );
    const saved = await extractor.extractFromMessage('u1', 'You seem to like boutique hotels');
    expect(saved).toEqual([]);
    expect(repo.rows).toHaveLength(0);
  });

  it('invalid/oversized extractor values are rejected, valid ones saved', async () => {
    const { service, repo } = memoryServiceWith();
    const extractor = new ConversationMemoryService(
      service,
      new StubExtractor(() =>
        Promise.resolve(
          extractorAnswer([
            { kind: 'preferred_destination', value: { destination: 'x'.repeat(200) } },
            { kind: 'preferred_budget', value: { min: 'cheap' } },
            { kind: 'preferred_travel_style', value: { styles: ['beach'] } },
          ]),
        ),
      ),
    );
    const saved = await extractor.extractFromMessage('u1', 'beach please');
    // Only the travel style survives validation.
    expect(saved).toHaveLength(1);
    expect(saved[0].key).toBe('preferred_travel_style');
    expect(repo.rows).toHaveLength(1);
  });

  it('duplicate preference UPDATES the existing memory instead of duplicating', async () => {
    const { service, repo } = memoryServiceWith();
    const extractor = new ConversationMemoryService(
      service,
      new StubExtractor(() =>
        Promise.resolve(
          extractorAnswer([
            { kind: 'preferred_destination', value: { destination: 'Cairo' } },
          ]),
        ),
      ),
    );
    await extractor.extractFromMessage('u1', 'I prefer Cairo');
    await extractor.extractFromMessage('u1', 'Actually Cairo, yes');
    const destRows = repo.rows.filter(
      (r) => r.key === 'preferred_destination:cairo',
    );
    expect(destRows).toHaveLength(1);
    expect(repo.rows.filter((r) => r.type === 'conversation')).toHaveLength(1);
  });

  it('extraction failure does NOT fail the AI flow (returns [])', async () => {
    const { service } = memoryServiceWith();
    const extractor = new ConversationMemoryService(
      service,
      new StubExtractor(failingProvider),
    );
    // The service's own contract: never throw — degrade to [].
    await expect(
      extractor.extractFromMessage('u1', 'book me a flight to Cairo'),
    ).resolves.toEqual([]);
  });

  it('empty message or missing provider → no extraction, no throw', async () => {
    const { service } = memoryServiceWith();
    const noProvider = new ConversationMemoryService(service, null);
    await expect(noProvider.extractFromMessage('u1', '')).resolves.toEqual([]);
    await expect(noProvider.extractFromMessage('u1', 'hello')).resolves.toEqual([]);
  });
});

describe('RelevantMemorySelector — conversation-only, bounded subset', () => {
  function row(overrides: Partial<UserMemory>): UserMemory {
    return {
      id: `m-${Math.random().toString(36).slice(2, 8)}`,
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

  it('retrieves only conversation + ai_conversation rows (ignores behavioral/other sources)', async () => {
    const { service } = memoryServiceWith([
      row({ key: 'preferred_destination:cairo', value: { destination: 'Cairo' } }),
      // Phase 2B behavioral row with the SAME logical key: must be ignored.
      row({
        type: 'behavior',
        source: 'behavior_event',
        key: 'preferred_destination:cairo',
        value: { destination: 'Cairo' },
      }),
      // Explicit user preference row with a different source: ignored too.
      row({
        type: 'preference',
        source: 'user_explicit',
        key: 'preferred_budget',
        value: { min: 10, max: 20 },
      }),
    ]);
    const selector = new RelevantMemorySelector(service);
    const picked = await selector.selectRelevant('u1', 'planning a trip to Cairo');
    expect(picked).toHaveLength(1);
    expect(picked[0].type).toBe('conversation');
    expect(picked[0].source).toBe('ai_conversation');
  });

  it('respects expiration (expired rows hidden by the Phase 2A listing default)', async () => {
    const { service } = memoryServiceWith([
      row({
        key: 'preferred_destination:cairo',
        value: { destination: 'Cairo' },
        expiresAt: new Date(Date.now() - 86_400_000),
      }),
      row({
        key: 'preferred_destination:dubai',
        value: { destination: 'Dubai' },
        expiresAt: null,
      }),
    ]);
    const selector = new RelevantMemorySelector(service);
    const picked = await selector.selectRelevant('u1', 'Cairo or Dubai?');
    const keys = picked.map((m: UserMemory) => m.key);
    expect(keys).toContain('preferred_destination:dubai');
    expect(keys).not.toContain('preferred_destination:cairo');
  });

  it('respects ownership — another user’s memories are invisible', async () => {
    const { service } = memoryServiceWith([
      row({
        userId: 'u2',
        key: 'preferred_destination:paris',
        value: { destination: 'Paris' },
      }),
    ]);
    const selector = new RelevantMemorySelector(service);
    const picked = await selector.selectRelevant('u1', 'trip to Paris');
    expect(picked).toEqual([]);
  });

  it('returns a relevant subset (keyword overlap), capped — never a full dump', async () => {
    const seed: any[] = [];
    const destinations = ['Cairo', 'Dubai', 'Paris', 'Tokyo', 'Rome', 'London', 'Madrid'];
    destinations.forEach((d, i) => {
      seed.push(
        row({
          key: `preferred_destination:${d.toLowerCase()}`,
          value: { destination: d },
          updatedAt: new Date(Date.now() - (i + 1) * 60_000),
        }),
      );
    });
    const { service } = memoryServiceWith(seed);
    const selector = new RelevantMemorySelector(service);
    const picked = await selector.selectRelevant('u1', 'I want to go to Cairo and Dubai', 2);
    expect(picked.length).toBeLessThanOrEqual(2);
    const keys = picked.map((m: UserMemory) => m.key);
    expect(keys).toContain('preferred_destination:cairo');
    expect(keys).toContain('preferred_destination:dubai');
    expect(keys).not.toContain('preferred_destination:paris');
  });

  it('Arabic message with no token overlap → strict relevance returns nothing', async () => {
    const { service } = memoryServiceWith([
      row({ key: 'preferred_destination:cairo', value: { destination: 'Cairo' } }),
      row({ key: 'preferred_destination:dubai', value: { destination: 'Dubai' } }),
    ]);
    const selector = new RelevantMemorySelector(service);
    const picked = await selector.selectRelevant('u1', 'عايز أروح القاهرة');
    // Latin "Cairo/Dubai" facts do not overlap the Arabic message tokens —
    // strict relevance (Phase 2C-B) means NO memory travels, not a recent
    // fallback dump.
    expect(picked).toEqual([]);
  });

  it('failure inside the memory store degrades to [] (never throws)', async () => {
    const broken = {
      listForUser: () => {
        throw new Error('db down');
      },
    } as unknown as MemoryService;
    const selector = new RelevantMemorySelector(broken);
    await expect(selector.selectRelevant('u1', 'anything')).resolves.toEqual([]);
  });
});
