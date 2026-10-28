import { describe, it, expect } from '@jest/globals';

import { MemoryService } from '../src/modules/memory/memory.service';
import { ExplicitPreferenceSignalService } from '../src/modules/memory/explicit_preference_signal.service';
import { DerivedPreferenceProfileService } from '../src/modules/memory/derived_preference_profile.service';
import { UserMemory } from '../src/database/entities/user_memory.entity';

/**
 * PH-7 — Explicit Preference Signal regression suite.
 *
 * Proves the explicit conversation → Home-ranking adapter is:
 * - batch + user-scoped (ONE listing per build; no cross-user leakage);
 * - latest-value-wins per kind with NO score inflation;
 * - safe against expired / wrong-type / wrong-source / malformed / sensitive
 *   rows (all ignored) and never crashes Home;
 * - opt-out aware (no lookup at all) and failure-isolated;
 * - ISOLATED: DerivedPreferenceProfile stays behavioural-only and the
 *   /ai/rerank whitelist stays unchanged.
 */

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

let seq = 0;
function convRow(overrides: Partial<UserMemory>): UserMemory {
  seq += 1;
  return {
    id: `cm-${seq}`,
    userId: 'u1',
    type: 'conversation',
    key: 'preferred_destination:cairo',
    value: { destination: 'Cairo' },
    source: 'ai_conversation',
    confidence: 1,
    expiresAt: null,
    createdAt: new Date(1_000_000 + seq),
    updatedAt: new Date(1_000_000 + seq),
    ...overrides,
  } as UserMemory;
}

function service(repo: any) {
  return new ExplicitPreferenceSignalService(new MemoryService(repo));
}

describe('PH-7: ExplicitPreferenceSignalService — basic signal', () => {
  it('explicit destination → signal carries the destination', async () => {
    const repo = fakeMemoryRepo([
      convRow({ key: 'preferred_destination:dubai', value: { destination: 'Dubai' } }),
    ]);
    const signal = await service(repo).buildForUser('u1');
    expect(signal?.destination).toBe('Dubai');
  });

  it('explicit budget max → signal carries the max', async () => {
    const repo = fakeMemoryRepo([
      convRow({ key: 'preferred_budget', value: { max: 5000 } }),
    ]);
    const signal = await service(repo).buildForUser('u1');
    expect(signal?.budget).toEqual({ max: 5000 });
  });

  it('explicit budget min/max → correct range handling', async () => {
    const repo = fakeMemoryRepo([
      convRow({ key: 'preferred_budget', value: { min: 1000, max: 5000 } }),
    ]);
    const signal = await service(repo).buildForUser('u1');
    expect(signal?.budget).toEqual({ min: 1000, max: 5000 });
  });

  it('missing budget bound is never treated as zero', async () => {
    const repo = fakeMemoryRepo([
      convRow({ key: 'preferred_budget', value: { max: 5000 } }),
    ]);
    const signal = await service(repo).buildForUser('u1');
    expect(signal?.budget).not.toHaveProperty('min');
    expect(signal?.budget?.max).toBe(5000);
  });

  it('Phase 4B: the budget currency travels with the signal', async () => {
    const repo = fakeMemoryRepo([
      convRow({
        key: 'preferred_budget',
        value: { min: 1000, max: 5000, currency: 'EGP' },
      }),
    ]);
    const signal = await service(repo).buildForUser('u1');
    expect(signal?.budget).toEqual({ min: 1000, max: 5000, currency: 'EGP' });
  });

  it('Phase 4B: an unsupported currency is dropped, the budget survives', async () => {
    const repo = fakeMemoryRepo([
      convRow({
        key: 'preferred_budget',
        value: { min: 1000, max: 5000, currency: 'XYZ' },
      }),
    ]);
    const signal = await service(repo).buildForUser('u1');
    expect(signal?.budget).toEqual({ min: 1000, max: 5000 });
  });

  it('explicit travel style is carried (documented deferral) but nothing else', async () => {
    const repo = fakeMemoryRepo([
      convRow({ key: 'preferred_travel_style', value: { styles: ['beach', 'family'] } }),
    ]);
    const signal = await service(repo).buildForUser('u1');
    expect(signal?.travelStyles).toEqual(['beach', 'family']);
    expect(signal?.destination).toBeUndefined();
    expect(signal?.budget).toBeUndefined();
  });

  it('no explicit memories → null (existing ranking unchanged)', async () => {
    const repo = fakeMemoryRepo([]);
    expect(await service(repo).buildForUser('u1')).toBeNull();
  });

  it('buildForUserSafe returns null when personalization is enabled but empty', async () => {
    const repo = fakeMemoryRepo([]);
    expect(await service(repo).buildForUserSafe('u1', true)).toBeNull();
  });
});

describe('PH-7: multiple memories — latest wins, no inflation', () => {
  it('the most recent destination wins on conflict', async () => {
    const repo = fakeMemoryRepo([
      convRow({
        key: 'preferred_destination:dubai',
        value: { destination: 'Dubai' },
        updatedAt: new Date(2_000_000),
      }),
      convRow({
        key: 'preferred_destination:cairo',
        value: { destination: 'Cairo' },
        updatedAt: new Date(1_000_000),
      }),
    ]);
    const signal = await service(repo).buildForUser('u1');
    expect(signal?.destination).toBe('Dubai');
  });

  it('repeated identical facts cannot inflate (bounded: one value per kind)', async () => {
    const repo = fakeMemoryRepo([
      convRow({ key: 'preferred_destination:dubai', value: { destination: 'Dubai' } }),
      convRow({ key: 'preferred_destination:dubai', value: { destination: 'Dubai' } }),
      convRow({ key: 'preferred_budget', value: { max: 5000 } }),
      convRow({ key: 'preferred_budget', value: { max: 5000 } }),
    ]);
    const signal = await service(repo).buildForUser('u1');
    expect(signal?.destination).toBe('Dubai');
    expect(signal?.budget).toEqual({ max: 5000 });
    // Bounded shape — exactly three optional keys at most.
    expect(Object.keys(signal!).sort()).toEqual(['budget', 'destination']);
  });

  it('different memory kinds → bounded contribution (one per kind)', async () => {
    const repo = fakeMemoryRepo([
      convRow({ key: 'preferred_destination:dubai', value: { destination: 'Dubai' } }),
      convRow({ key: 'preferred_budget', value: { min: 100, max: 900 } }),
      convRow({ key: 'preferred_travel_style', value: { styles: ['adventure'] } }),
    ]);
    const signal = await service(repo).buildForUser('u1');
    expect(signal).toEqual({
      destination: 'Dubai',
      budget: { min: 100, max: 900 },
      travelStyles: ['adventure'],
    });
  });
});

describe('PH-7: safety — invalid rows are ignored', () => {
  it('expired memory → ignored (empty signal)', async () => {
    const repo = fakeMemoryRepo([
      convRow({
        key: 'preferred_destination:dubai',
        value: { destination: 'Dubai' },
        expiresAt: new Date(Date.now() - 60_000),
      }),
    ]);
    expect(await service(repo).buildForUser('u1')).toBeNull();
  });

  it("another user's memory → ignored (ownership)", async () => {
    const repo = fakeMemoryRepo([
      convRow({
        userId: 'u2',
        key: 'preferred_destination:dubai',
        value: { destination: 'Dubai' },
      }),
    ]);
    expect(await service(repo).buildForUser('u1')).toBeNull();
  });

  it('wrong type / wrong source → ignored', async () => {
    const repo = fakeMemoryRepo([
      convRow({ type: 'behavior', source: 'behavior_event', key: 'preferred_destination:dubai' }),
      convRow({ source: 'system_derived', key: 'preferred_destination:dubai' }),
    ]);
    expect(await service(repo).buildForUser('u1')).toBeNull();
  });

  it('malformed memory → ignored safely', async () => {
    const repo = fakeMemoryRepo([
      convRow({ key: 'preferred_destination:dubai', value: { destination: 123 } }),
      convRow({ key: 'preferred_budget', value: { max: 'lots' } }),
      convRow({ key: 'preferred_destination:dubai', value: { nonsense: true } }),
    ]);
    expect(await service(repo).buildForUser('u1')).toBeNull();
  });

  it('sensitive memory value → ignored', async () => {
    const repo = fakeMemoryRepo([
      convRow({
        key: 'preferred_destination:dubai',
        value: { destination: 'Dubai', password: 'hunter2' },
      }),
    ]);
    expect(await service(repo).buildForUser('u1')).toBeNull();
  });

  it('unknown key shape → ignored', async () => {
    const repo = fakeMemoryRepo([
      convRow({ key: 'random_key', value: { destination: 'Dubai' } }),
    ]);
    expect(await service(repo).buildForUser('u1')).toBeNull();
  });
});

describe('PH-7: opt-out + failure isolation', () => {
  it('personalization disabled → null AND no memory lookup', async () => {
    const repo = fakeMemoryRepo([
      convRow({ key: 'preferred_destination:dubai', value: { destination: 'Dubai' } }),
    ]);
    let calls = 0;
    const mem = new MemoryService(repo);
    const spy = { listForUser: (u: string, o: any) => (calls++, mem.listForUser(u, o)) };
    const svc = new ExplicitPreferenceSignalService(spy as any);
    const signal = await svc.buildForUserSafe('u1', false);
    expect(signal).toBeNull();
    expect(calls).toBe(0);
  });

  it('memory listing failure → degrades to null, never throws', async () => {
    const broken = {
      listForUser: async () => {
        throw new Error('db down');
      },
    };
    const svc = new ExplicitPreferenceSignalService(broken as any);
    await expect(svc.buildForUserSafe('u1', true)).resolves.toBeNull();
  });
});

describe('PH-7: isolation regressions', () => {
  it('DerivedPreferenceProfile stays behavioural-only', async () => {
    const repo = fakeMemoryRepo([
      convRow({ key: 'preferred_destination:cairo', value: { destination: 'Cairo' } }),
      convRow({ key: 'preferred_budget', value: { min: 10, max: 20 } }),
      {
        ...convRow({}),
        type: 'behavior',
        key: 'hotel_search:paris',
        value: { title: 'Paris Hotel', city: 'Paris' },
        source: 'behavior_event',
      },
    ]);
    const profile = await new DerivedPreferenceProfileService(
      new MemoryService(repo),
    ).buildForUser('u1', {
      userId: 'u1',
      preferences: {},
      derived: {},
      personalizationEnabled: true,
      updatedAt: new Date(),
    } as any);
    expect(profile.topDestinations).toEqual([]);
    expect(profile.budgetRange).toBeUndefined();
  });

  it('/ai/rerank whitelist is unchanged (explicit keys rejected)', async () => {
    const { contextIsSafe } = await import('../src/common/dto/ai.rerank.dto');
    expect(contextIsSafe({ explicitPreferences: { destination: 'Dubai' } })).toBe(false);
    expect(contextIsSafe({ preferred_destination: 'Dubai' })).toBe(false);
    expect(contextIsSafe({ userState: 'authenticated', countryCode: 'EG' })).toBe(true);
  });
});
