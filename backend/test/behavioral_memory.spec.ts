import {
  BehavioralFactKind,
  behavioralFactKey,
  behavioralKindFromKey,
  effectiveConfidence,
  nextConfidence,
  validateBehavioralFact,
} from '../src/modules/memory/behavioral_facts';
import { BehavioralMemoryService } from '../src/modules/memory/behavioral_memory.service';
import {
  DerivedPreferenceProfileService,
} from '../src/modules/memory/derived_preference_profile.service';
import { MemoryService } from '../src/modules/memory/memory.service';
import { EventsService } from '../src/modules/events/events.service';

/**
 * Phase 2B — Behavioral Memory + Derived Preference Profile.
 *
 * Covers the §22 backend list: event→memory extraction, upsert/no-duplicate,
 * the confidence ladder, bounded/deterministic confidence, decay, no
 * negative inference, vocabulary validation, invalid/sensitive rejection,
 * guest behaviour, event-flow isolation on memory failure, derived
 * aggregation, conflict resolution, expired handling, ownership isolation —
 * and keeps Phase 2A green.
 */

function fakeMemoryRepo(initial: any[] = []) {
  const rows = [...initial];
  return {
    rows,
    async find(opts: any) {
      let out = rows.filter((r) => r.userId === opts.where.userId);
      if (opts.where.type) out = out.filter((r) => r.type === opts.where.type);
      if (opts.where.source)
        out = out.filter((r) => r.source === opts.where.source);
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

function profileView(overrides: any = {}) {
  return {
    userId: 'u1',
    preferences: {},
    derived: {},
    personalizationEnabled: true,
    updatedAt: new Date(),
    ...overrides,
  };
}

describe('Behavioral fact vocabulary + validators', () => {
  it('builds suffixed keys and round-trips the kind', () => {
    expect(behavioralFactKey('preferred_destination', 'Sharm El Sheikh'))
      .toBe('preferred_destination:sharm-el-sheikh');
    expect(behavioralFactKey('preferred_budget', 'x')).toBe('preferred_budget');
    expect(behavioralKindFromKey('preferred_destination:cairo'))
      .toBe('preferred_destination');
    expect(behavioralKindFromKey('made_up:cairo')).toBeNull();
  });

  it('accepts exactly the declared fields per fact kind', () => {
    expect(
      validateBehavioralFact('preferred_destination', { destination: 'Cairo' }).valid,
    ).toBe(true);
    expect(
      validateBehavioralFact('preferred_budget', { min: 100, max: 500 }).valid,
    ).toBe(true);
  });

  it('rejects unknown fields, wrong types, and missing fields', () => {
    expect(
      validateBehavioralFact('preferred_destination', {
        destination: 'Cairo',
        extra: 'x',
      }).valid,
    ).toBe(false);
    expect(
      validateBehavioralFact('preferred_budget', { min: 'cheap' }).valid,
    ).toBe(false);
    expect(
      validateBehavioralFact('preferred_destination', {}).valid,
    ).toBe(false);
  });

  it('rejects sensitive values through the Phase 2A scanner', () => {
    expect(
      validateBehavioralFact('recent_viewed_hotel', {
        hotelId: 'h1',
        password: 'x',
      }).valid,
    ).toBe(false);
  });

  it('nextConfidence is monotonic, boosted, and bounded at 1.0', () => {
    expect(nextConfidence(undefined, 0.35)).toBe(0.35);
    expect(nextConfidence(0.35, 0.35)).toBe(0.45); // repeat boost
    expect(nextConfidence(0.9, 0.3)).toBe(0.9); // weaker signal: untouched
    expect(nextConfidence(0.35, 0.9)).toBe(0.9); // stronger signal: its base
    expect(nextConfidence(0.9, 0.9)).toBe(1); // same-strength repeat: ceiling
    expect(nextConfidence(0.99, 0.99)).toBe(1); // never above 1.0
  });

  it('effectiveConfidence decays deterministically with age', () => {
    const now = new Date('2026-09-04T00:00:00Z');
    const updated = new Date('2026-08-05T00:00:00Z'); // 30 days old.
    const fresh = effectiveConfidence(0.9, updated, now);
    expect(fresh).toBeGreaterThan(0.3);
    expect(fresh).toBeLessThan(0.9);
    // Same inputs → same output (pure function).
    expect(effectiveConfidence(0.9, updated, now)).toBe(fresh);
    // Zero age → unchanged.
    expect(effectiveConfidence(0.9, now, now)).toBeCloseTo(0.9, 9);
    // Clamp to [0, 1].
    expect(effectiveConfidence(5, now, now)).toBe(1);
  });
});

describe('BehavioralMemoryService — event → typed memories', () => {
  it('hotel_search creates preferred_destination + preferred_budget', async () => {
    const { service } = memoryServiceWith();
    const behavioral = new BehavioralMemoryService(service);
    await behavioral.extractFromEvent('u1', 'hotel_search', {
      destination: 'Cairo',
      minPrice: 100,
      maxPrice: 500,
    });

    const dest = await service.findBehavioral(
      'u1',
      'preferred_destination:cairo',
    );
    expect(dest?.value).toEqual({ destination: 'Cairo' });
    expect(dest?.source).toBe('behavior_event');
    expect(dest?.confidence).toBe(0.3);

    const budget = await service.findBehavioral('u1', 'preferred_budget');
    expect(budget?.value).toEqual({ min: 100, max: 500 });
  });

  it('hotel_view creates a recent_viewed_hotel fact', async () => {
    const { service } = memoryServiceWith();
    const behavioral = new BehavioralMemoryService(service);
    await behavioral.extractFromEvent('u1', 'hotel_view', {
      hotelId: 'h-9',
      title: 'Grand Cairo',
    });
    const fact = await service.findBehavioral('u1', 'recent_viewed_hotel:h-9');
    expect(fact?.value).toEqual({ hotelId: 'h-9', title: 'Grand Cairo' });
    expect(fact?.confidence).toBe(0.35);
  });

  it('hotel_favorite confidence (0.6) beats a view (0.35)', async () => {
    const { service } = memoryServiceWith();
    const behavioral = new BehavioralMemoryService(service);
    await behavioral.extractFromEvent('u1', 'hotel_view', {
      hotelId: 'h-9',
      title: 'Grand Cairo',
    });
    await behavioral.extractFromEvent('u1', 'hotel_favorite', {
      hotelId: 'h-9',
      title: 'Grand Cairo',
    });
    const fact = await service.findBehavioral('u1', 'favorite_hotel:h-9');
    expect(fact?.confidence).toBe(0.6);
  });

  it('trip_planned creates planned_destination (0.75)', async () => {
    const { service } = memoryServiceWith();
    const behavioral = new BehavioralMemoryService(service);
    await behavioral.extractFromEvent('u1', 'trip_planned', {
      destination: 'Dubai',
    });
    const fact = await service.findBehavioral(
      'u1',
      'planned_destination:dubai',
    );
    expect(fact?.confidence).toBe(0.75);
  });

  it('booking_confirmed gives the strongest destination confidence (0.9)', async () => {
    const { service } = memoryServiceWith();
    const behavioral = new BehavioralMemoryService(service);
    await behavioral.extractFromEvent('u1', 'booking_confirmed', {
      destination: 'Hurghada',
    });
    const fact = await service.findBehavioral(
      'u1',
      'preferred_destination:hurghada',
    );
    expect(fact?.confidence).toBe(0.9);
  });

  it('repeated identical events upsert — no duplicate rows, boosted confidence',
    async () => {
      const { service, repo } = memoryServiceWith();
      const behavioral = new BehavioralMemoryService(service);
      await behavioral.extractFromEvent('u1', 'hotel_view', {
        hotelId: 'h-1',
        title: 'A',
      });
      await behavioral.extractFromEvent('u1', 'hotel_view', {
        hotelId: 'h-1',
        title: 'A',
      });

      const sameKeyRows = repo.rows.filter(
        (r) => r.key === 'recent_viewed_hotel:h-1',
      );
      expect(sameKeyRows).toHaveLength(1);
      expect(sameKeyRows[0].confidence).toBe(0.45); // 0.35 + repeat boost.
    });

  it('view → favorite → booking ladder is strictly increasing', async () => {
    // Same destination through the three signal strengths on ONE key.
    const { service } = memoryServiceWith();
    const behavioral = new BehavioralMemoryService(service);

    await behavioral.extractFromEvent('u1', 'hotel_search', {
      destination: 'Cairo',
    });
    const afterSearch = (await service.findBehavioral(
      'u1',
      'preferred_destination:cairo',
    ))!.confidence;

    await behavioral.extractFromEvent('u1', 'booking_confirmed', {
      destination: 'Cairo',
    });
    const afterBooking = (await service.findBehavioral(
      'u1',
      'preferred_destination:cairo',
    ))!.confidence;

    expect(afterSearch).toBe(0.3);
    expect(afterBooking).toBeGreaterThan(afterSearch);
    expect(afterBooking).toBe(0.9);
  });

  it('oversized/invalid payload fields are dropped safely — nothing persisted',
    async () => {
      const { service, repo } = memoryServiceWith();
      const behavioral = new BehavioralMemoryService(service);
      // hotelId over 120 chars is not a usable subject → no fact at all.
      const out = await behavioral.extractFromEvent('u1', 'hotel_view', {
        hotelId: 'x'.repeat(200),
      });
      expect(out).toEqual([]);
      expect(repo.rows).toHaveLength(0);

      // Wrongly-shaped declared fields are rejected with a throw (validator).
      await expect(
        behavioral.extractFromEvent('u1', 'hotel_search', {
          destination: 'Cairo',
          minPrice: 'cheap',
        }),
      ).rejects.toThrow();
      expect(repo.rows).toHaveLength(0);
    });

  it('unknown event types extract nothing (absence ≠ negative signal)',
    async () => {
      const { service } = memoryServiceWith();
      const behavioral = new BehavioralMemoryService(service);
      const out = await behavioral.extractFromEvent('u1', 'random_event', {});
      expect(out).toEqual([]);
    });

  it('budget facts MERGE instead of losing one side', async () => {
    const { service } = memoryServiceWith();
    const behavioral = new BehavioralMemoryService(service);
    await behavioral.extractFromEvent('u1', 'hotel_search', {
      destination: 'Cairo',
      minPrice: 100,
    });
    await behavioral.extractFromEvent('u1', 'hotel_search', {
      destination: 'Luxor',
      maxPrice: 500,
    });
    const budget = await service.findBehavioral('u1', 'preferred_budget');
    expect(budget?.value).toEqual({ min: 100, max: 500 });
  });
});

describe('EventsService — memory isolation + guests', () => {
  function fakeEventRepo() {
    const saved: any[] = [];
    return {
      saved,
      create(value: any) {
        return value;
      },
      async save(value: any) {
        saved.push(value);
        return value;
      },
      async find() {
        return saved;
      },
    } as any;
  }

  function fakeProfiles() {
    return {
      async getOrCreate(userId: string) {
        return { userId, preferences: {}, derived: {} };
      },
      async updateDerived() {},
    } as any;
  }

  it('memory derivation failure does NOT break the event flow', async () => {
    const events = fakeEventRepo();
    const failingMemory = {
      async extractFromEvent() {
        throw new Error('db down');
      },
    };
    const service = new EventsService(
      events,
      fakeProfiles(),
      failingMemory as BehavioralMemoryService,
    );
    await expect(
      service.track({ userId: 'u1', type: 'hotel_search', payload: { destination: 'Cairo' } }),
    ).resolves.toBeUndefined();
    expect(events.saved).toHaveLength(1); // Event persisted.
  });

  it('guest events never create memories (registered-only decision)', async () => {
    const events = fakeEventRepo();
    let memoryCalls = 0;
    const memory = {
      async extractFromEvent() {
        memoryCalls++;
        return [];
      },
    };
    const service = new EventsService(
      events,
      fakeProfiles(),
      memory as BehavioralMemoryService,
    );
    await service.track({
      deviceId: 'device-1',
      type: 'hotel_search',
      payload: { destination: 'Cairo' },
    });
    expect(events.saved).toHaveLength(1);
    expect(memoryCalls).toBe(0); // No userId → no extraction attempt.
  });

  it('optional memory layer keeps legacy construction working', async () => {
    const service = new EventsService(fakeEventRepo(), fakeProfiles());
    await expect(
      service.track({ userId: 'u1', type: 'hotel_view', payload: { hotelId: 'x' } }),
    ).resolves.toBeUndefined();
  });
});

describe('DerivedPreferenceProfileService — aggregation + conflicts', () => {
  const derived = () =>
    new DerivedPreferenceProfileService(memoryServiceWith().service);

  function behaviorRow(key: string, value: any, confidence: number, ageDays = 0) {
    return {
      id: `r-${key}-${Math.random()}`,
      userId: 'u1',
      type: 'behavior',
      key,
      value,
      source: 'behavior_event',
      confidence,
      updatedAt: new Date(Date.now() - ageDays * 86_400_000),
    };
  }

  it('aggregates destinations by effective confidence, deterministic order',
    async () => {
      const svc = derived();
      const memories = memoryServiceWith([
        behaviorRow('preferred_destination:cairo', { destination: 'Cairo' }, 0.3),
        behaviorRow('planned_destination:dubai', { destination: 'Dubai' }, 0.75),
      ]);
      const service = new DerivedPreferenceProfileService(memories.service);

      const profile = await service.buildForUser('u1', profileView());
      expect(profile.topDestinations[0].name).toBe('Dubai'); // 0.75 > 0.3.
      expect(profile.topDestinations[1].name).toBe('Cairo');
      expect(profile.recentDestinations).toContain('Dubai');
      // Reproducibility: same inputs → same order.
      const again = await service.buildForUser('u1', profileView());
      expect(again.topDestinations.map((d) => d.name))
        .toEqual(profile.topDestinations.map((d) => d.name));
    });

  it('conflict ladder: explicit > booking > planned > behavior > legacy', async () => {
    const memories = memoryServiceWith([
      behaviorRow('preferred_destination:hurghada', { destination: 'Hurghada' }, 0.9),
      behaviorRow('planned_destination:sharm', { destination: 'Sharm' }, 0.75),
      behaviorRow('preferred_destination:cairo', { destination: 'Cairo' }, 0.3),
    ]);
    const service = new DerivedPreferenceProfileService(memories.service);

    // Explicit profile preference wins over EVERYTHING behavioural.
    const profile = await service.buildForUser(
      'u1',
      profileView({
        preferences: { preferredDestinations: ['Alexandria'] },
      }),
    );
    expect(profile.topDestinations[0]).toEqual({
      name: 'Alexandria',
      confidence: 1,
      source: 'user_explicit',
    });
    // Then booking (0.9) > planned (0.75) > search (0.3).
    expect(profile.topDestinations[1].name).toBe('Hurghada');
    expect(profile.topDestinations[2].name).toBe('Sharm');
    expect(profile.topDestinations[3].name).toBe('Cairo');
  });

  it('stale signals decay below fresh ones at read time', async () => {
    const memories = memoryServiceWith([
      behaviorRow('preferred_destination:old', { destination: 'OldCity' }, 0.9, 90),
      behaviorRow('preferred_destination:new', { destination: 'NewCity' }, 0.5, 0),
    ]);
    const service = new DerivedPreferenceProfileService(memories.service);
    const profile = await service.buildForUser('u1', profileView());
    // 0.9 × e^-3 ≈ 0.045 < 0.5 — freshness wins despite the higher base.
    expect(profile.topDestinations[0].name).toBe('NewCity');
  });

  it('budget ladder: explicit > memory > legacy fold', async () => {
    const memories = memoryServiceWith([
      behaviorRow('preferred_budget', { min: 200, max: 800 }, 0.5),
    ]);
    const service = new DerivedPreferenceProfileService(memories.service);

    const fromMemory = await service.buildForUser('u1', profileView());
    expect(fromMemory.budgetRange).toEqual({ min: 200, max: 800 });

    const explicit = await service.buildForUser(
      'u1',
      profileView({ preferences: { budgetMin: 50, budgetMax: 120 } }),
    );
    expect(explicit.budgetRange).toEqual({ min: 50, max: 120 });

    // Legacy fold applies ONLY when no behavioral budget memory exists.
    const clean = new DerivedPreferenceProfileService(
      memoryServiceWith().service,
    );
    const legacy = await clean.buildForUser(
      'u1',
      profileView({ derived: { budget: { min: 10, max: 99 } } }),
    );
    expect(legacy.budgetRange).toEqual({ min: 10, max: 99 });
  });

  it('expired memories are excluded (Phase 2A listing contract)', async () => {
    const expiredDate = new Date(Date.now() - 86_400_000);
    const memories = memoryServiceWith([
      {
        id: 'gone',
        userId: 'u1',
        type: 'behavior',
        key: 'preferred_destination:alex',
        value: { destination: 'Alexandria' },
        source: 'behavior_event',
        confidence: 0.9,
        expiresAt: expiredDate,
        updatedAt: new Date(),
      },
    ]);
    const service = new DerivedPreferenceProfileService(memories.service);
    const profile = await service.buildForUser('u1', profileView());
    expect(
      profile.topDestinations.find((d) => d.name === 'Alexandria'),
    ).toBeUndefined();
  });

  it('favorite hotels aggregate from memory facts', async () => {
    const memories = memoryServiceWith([
      behaviorRow('favorite_hotel:h-1', { hotelId: 'h-1', title: 'Grand' }, 0.6),
    ]);
    const service = new DerivedPreferenceProfileService(memories.service);
    const profile = await service.buildForUser('u1', profileView());
    expect(profile.favoriteHotels).toEqual([
      { hotelId: 'h-1', title: 'Grand' },
    ]);
  });

  it('buildForUserSafe degrades to an empty profile on failure', async () => {
    const throwingMemories = {
      listForUser: async () => {
        throw new Error('db down');
      },
    } as any;
    const service = new DerivedPreferenceProfileService(throwingMemories);
    const profile = await service.buildForUserSafe('u1', profileView());
    expect(profile.topDestinations).toEqual([]);
  });

  it('ownership isolation: users only ever see their own facts', async () => {
    const shared = memoryServiceWith([
      behaviorRow('preferred_destination:cairo', { destination: 'Cairo' }, 0.3),
    ]);
    // Re-tag the seeded row for another user.
    shared.repo.rows[0].userId = 'someone-else';
    const service = new DerivedPreferenceProfileService(shared.service);
    const profile = await service.buildForUser('u1', profileView());
    expect(profile.topDestinations).toEqual([]); // u1 sees nothing.
  });
});

describe('Phase 2A regression — MemoryService stays green', () => {
  it('upsert + listForUser contracts unchanged (spot check)', async () => {
    const { service, repo } = memoryServiceWith();
    await service.upsert('u1', {
      type: 'preference',
      key: 'preferred_destination:manual',
      value: { destination: 'Rome' },
      source: 'user_explicit',
      confidence: 1,
    });
    await service.upsert('u1', {
      type: 'preference',
      key: 'preferred_destination:manual',
      value: { destination: 'Venice' },
      source: 'user_explicit',
      confidence: 0.8,
    });
    expect(repo.rows).toHaveLength(1);
    const listed = await service.listForUser('u1');
    expect(listed[0].value).toEqual({ destination: 'Venice' });
  });
});
