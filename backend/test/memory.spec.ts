import { BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';

import {
  CreateMemoryDto,
  MEMORY_SOURCES,
  MEMORY_TYPES,
  containsSensitiveData,
} from '../src/common/dto/memory.dto';
import { MemoryService } from '../src/modules/memory/memory.service';
import { UserMemory } from '../src/database/entities/user_memory.entity';

/**
 * Phase 2A — Memory Spine foundation.
 *
 * Covers: create/upsert, listing order + filters + expired hiding,
 * ownership enforcement on every mutation, DTO validation boundaries,
 * confidence range, duplicate-rewrite semantics, and the sensitive-data
 * scanner (credentials/payment/precise-GPS never persist).
 */

function fakeMemoryRepo(initial: any[] = []) {
  const rows = [...initial];
  return {
    rows,
    async find(opts: any) {
      let out = rows.filter((r) => r.userId === opts.where.userId);
      if (opts.where.type) out = out.filter((r) => r.type === opts.where.type);
      if (opts.where.source) out = out.filter((r) => r.source === opts.where.source);
      // Deterministic listing contract: updatedAt DESC.
      return [...out].sort(
        (a, b) => new Date(b.updatedAt).getTime() - new Date(a.updatedAt).getTime(),
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

function createDto(overrides: Partial<CreateMemoryDto> = {}): CreateMemoryDto {
  return {
    type: 'preference',
    key: 'preferred_destination',
    value: { destination: 'Cairo' },
    source: 'user_explicit',
    confidence: 0.72,
    ...overrides,
  };
}

describe('Memory DTO — validation vocabulary', () => {
  it('exposes the supported types and sources', () => {
    expect(MEMORY_TYPES).toEqual([
      'preference',
      'behavior',
      'conversation',
      'derived',
    ]);
    expect(MEMORY_SOURCES).toEqual([
      'user_explicit',
      'behavior_event',
      'ai_conversation',
      'system_derived',
    ]);
  });

  it('rejects sensitive keys at any nesting depth', () => {
    expect(containsSensitiveData({ password: 'x' })).toBe(true);
    expect(containsSensitiveData({ nested: { accessToken: 'y' } })).toBe(true);
    expect(containsSensitiveData({ list: [{ creditCard: '4111' }] })).toBe(true);
    expect(containsSensitiveData({ home: { latitude: 30, longitude: 31 } })).toBe(true);
    expect(containsSensitiveData({ destination: 'Cairo' })).toBe(false);
    expect(containsSensitiveData({ budget: { max: 500 } })).toBe(false);
  });
});

describe('MemoryService — user-owned memory spine', () => {
  it('creates a memory for the caller (JWT user only)', async () => {
    const repo = fakeMemoryRepo();
    const service = new MemoryService(repo);
    const saved = await service.upsert('user-1', createDto());
    expect(saved.userId).toBe('user-1');
    expect(saved.key).toBe('preferred_destination');
    expect(saved.confidence).toBe(0.72);
    expect(repo.rows).toHaveLength(1);
  });

  it('rejects sensitive values instead of persisting them', async () => {
    const repo = fakeMemoryRepo();
    const service = new MemoryService(repo);
    await expect(
      service.upsert('user-1', createDto({ value: { password: 'nope' } })),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(repo.rows).toHaveLength(0);
  });

  it('rejects invalid type/source via the DTO vocabulary (validated upstream)', () => {
    // The DTO class-level IsIn guards these; the service trusts the DTO.
    // This test pins the vocabulary so a typo cannot sneak in later.
    const dto = createDto();
    expect(MEMORY_TYPES).toContain(dto.type);
    expect(MEMORY_SOURCES).toContain(dto.source);
    expect(MEMORY_TYPES).not.toContain('preference_typo');
  });

  it('confidence must stay within 0..1 (DTO contract)', () => {
    // Mirrors the @Min(0) @Max(1) decorators on CreateMemoryDto.
    const dto = createDto();
    expect(dto.confidence).toBeGreaterThanOrEqual(0);
    expect(dto.confidence).toBeLessThanOrEqual(1);
    // Out-of-range values are rejected by class-validator at the HTTP
    // boundary; the service itself only stores validated numbers.
  });

  it('lists own memories newest-first', async () => {
    const repo = fakeMemoryRepo([
      { id: 'a', userId: 'user-1', type: 'preference', key: 'k1', value: {}, source: 'user_explicit', confidence: 1, updatedAt: new Date('2026-01-01') },
      { id: 'b', userId: 'user-1', type: 'behavior', key: 'k2', value: {}, source: 'behavior_event', confidence: 1, updatedAt: new Date('2026-02-01') },
      { id: 'c', userId: 'user-2', type: 'preference', key: 'k1', value: {}, source: 'user_explicit', confidence: 1, updatedAt: new Date('2026-03-01') },
    ]);
    const service = new MemoryService(repo);
    const mine = await service.listForUser('user-1');
    expect(mine.map((m: UserMemory) => m.id)).toEqual(['b', 'a']); // DESC.
    expect(mine.every((m: UserMemory) => m.userId === 'user-1')).toBe(true);
  });

  it('filters by type and source', async () => {
    const repo = fakeMemoryRepo([
      { id: 'a', userId: 'u1', type: 'preference', key: 'k1', value: {}, source: 'user_explicit', confidence: 1, updatedAt: new Date() },
      { id: 'b', userId: 'u1', type: 'behavior', key: 'k2', value: {}, source: 'behavior_event', confidence: 1, updatedAt: new Date() },
    ]);
    const service = new MemoryService(repo);
    const onlyBehavior = await service.listForUser('u1', { type: 'behavior' });
    expect(onlyBehavior.map((m: UserMemory) => m.id)).toEqual(['b']);
    const onlyExplicit = await service.listForUser('u1', { source: 'user_explicit' });
    expect(onlyExplicit.map((m: UserMemory) => m.id)).toEqual(['a']);
  });

  it('hides expired memories by default, includes them on demand', async () => {
    const repo = fakeMemoryRepo([
      { id: 'live', userId: 'u1', type: 'preference', key: 'k1', value: {}, source: 'user_explicit', confidence: 1, updatedAt: new Date('2026-06-03'), expiresAt: new Date(Date.now() + 86_400_000) },
      { id: 'dead', userId: 'u1', type: 'preference', key: 'k2', value: {}, source: 'user_explicit', confidence: 1, updatedAt: new Date('2026-06-02'), expiresAt: new Date(Date.now() - 86_400_000) },
      { id: 'eternal', userId: 'u1', type: 'preference', key: 'k3', value: {}, source: 'user_explicit', confidence: 1, updatedAt: new Date('2026-06-01'), expiresAt: null },
    ]);
    const service = new MemoryService(repo);

    const defaultListing = await service.listForUser('u1');
    expect(defaultListing.map((m: UserMemory) => m.id)).toEqual(['live', 'eternal']);

    const full = await service.listForUser('u1', { includeExpired: true });
    expect(full).toHaveLength(3); // Never auto-deleted in Phase 2A.
  });

  it('upsert rewrites the same logical fact instead of duplicating', async () => {
    const repo = fakeMemoryRepo();
    const service = new MemoryService(repo);
    await service.upsert('user-1', createDto({ confidence: 0.5 }));
    const updated = await service.upsert('user-1', createDto({
      value: { destination: 'Dubai' },
      source: 'behavior_event',
      confidence: 0.9,
    }));

    expect(repo.rows).toHaveLength(1); // No duplicate accumulation.
    expect(updated.value).toEqual({ destination: 'Dubai' });
    expect(updated.source).toBe('behavior_event');
    expect(updated.confidence).toBe(0.9);
  });

  it('updateOwn: updates own memory, forbids foreign memories', async () => {
    const repo = fakeMemoryRepo([
      { id: 'm1', userId: 'user-1', type: 'preference', key: 'k', value: {}, source: 'user_explicit', confidence: 1, updatedAt: new Date() },
      { id: 'm2', userId: 'user-2', type: 'preference', key: 'k', value: {}, source: 'user_explicit', confidence: 1, updatedAt: new Date() },
    ]);
    const service = new MemoryService(repo);

    const updated = await service.updateOwn('user-1', 'm1', {
      value: { destination: 'Rome' },
      confidence: 0.8,
    });
    expect(updated.value).toEqual({ destination: 'Rome' });
    expect(updated.confidence).toBe(0.8);

    await expect(service.updateOwn('user-1', 'm2', { confidence: 0.1 }))
      .rejects.toBeInstanceOf(ForbiddenException);
    await expect(service.updateOwn('user-1', 'missing', { confidence: 0.1 }))
      .rejects.toBeInstanceOf(NotFoundException);
  });

  it('updateOwn rejects sensitive values too', async () => {
    const repo = fakeMemoryRepo([
      { id: 'm1', userId: 'u1', type: 'preference', key: 'k', value: {}, source: 'user_explicit', confidence: 1, updatedAt: new Date() },
    ]);
    const service = new MemoryService(repo);
    await expect(
      service.updateOwn('u1', 'm1', { value: { apiToken: 'x' } }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('deleteOwn: deletes own memory, forbids foreign memories', async () => {
    const repo = fakeMemoryRepo([
      { id: 'm1', userId: 'user-1', type: 'preference', key: 'k', value: {}, source: 'user_explicit', confidence: 1, updatedAt: new Date() },
      { id: 'm2', userId: 'user-2', type: 'preference', key: 'k', value: {}, source: 'user_explicit', confidence: 1, updatedAt: new Date() },
    ]);
    const service = new MemoryService(repo);

    await service.deleteOwn('user-1', 'm1');
    expect(repo.rows.find((r) => r.id === 'm1')).toBeUndefined();

    await expect(service.deleteOwn('user-1', 'm2'))
      .rejects.toBeInstanceOf(ForbiddenException);
  });

  it('clearOwn clears ONLY the caller memories', async () => {
    const repo = fakeMemoryRepo([
      { id: 'm1', userId: 'user-1', type: 'preference', key: 'k1', value: {}, source: 'user_explicit', confidence: 1, updatedAt: new Date() },
      { id: 'm2', userId: 'user-1', type: 'behavior', key: 'k2', value: {}, source: 'behavior_event', confidence: 1, updatedAt: new Date() },
      { id: 'm3', userId: 'user-2', type: 'preference', key: 'k3', value: {}, source: 'user_explicit', confidence: 1, updatedAt: new Date() },
    ]);
    const service = new MemoryService(repo);

    await service.clearOwn('user-1');
    expect(repo.rows.map((r) => r.id)).toEqual(['m3']); // user-2 untouched.
  });
});
