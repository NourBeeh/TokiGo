import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';

import { UserMemory } from '../../database/entities/user_memory.entity';
import {
  CreateMemoryDto,
  UpdateMemoryDto,
  containsControlCharacters,
  containsSensitiveData,
} from '../../common/dto/memory.dto';

/**
 * Memory Spine service (Phase 2A — Foundation).
 *
 * User-owned facts with provenance and confidence. Every method takes the
 * caller's userId from the JWT — there is no code path where a client can
 * read, mutate, or clear another user's memories.
 *
 * Behaviour contracts (documented + tested):
 * - Listing is deterministic: `updatedAt DESC`, optional type/source
 *   filters, and EXPIRED records hidden by default (includeExpired to see
 *   them; nothing is ever auto-deleted in 2A).
 * - Recording the same logical fact (userId+type+key) UPDATES the existing
 *   row (value/source/confidence/expiresAt/updatedAt) instead of creating
 *   a duplicate. The DB backs this with a unique index.
 * - The value tree must be structured facts: any sensitive key
 *   (credentials/payment/precise location) at any depth is rejected.
 */
@Injectable()
export class MemoryService {
  private readonly logger = new Logger(MemoryService.name);

  constructor(
    @InjectRepository(UserMemory)
    private readonly memories: Repository<UserMemory>,
  ) {}

  /** Lists the caller's memories, newest first, expired hidden by default. */
  async listForUser(
    userId: string,
    opts: { type?: string; source?: string; includeExpired?: boolean } = {},
  ): Promise<UserMemory[]> {
    const rows = await this.memories.find({
      where: {
        userId,
        ...(opts.type ? { type: opts.type } : {}),
        ...(opts.source ? { source: opts.source } : {}),
      },
      order: { updatedAt: 'DESC' },
    });
    if (opts.includeExpired) return rows;
    const now = Date.now();
    return rows.filter((r) => {
      const expiry = r.expiresAt ? new Date(r.expiresAt).getTime() : null;
      return expiry === null || expiry > now;
    });
  }

  /**
   * Finds one behavioral memory row by its exact key (Phase 2B read helper
   * for extraction/dedup). Expired rows are still returned — the caller
   * decides semantics; nothing is auto-deleted.
   */
  async findBehavioral(userId: string, key: string): Promise<UserMemory | null> {
    try {
      const rows = await this.memories.find({
        where: { userId, type: 'behavior', key },
      });
      return rows[0] ?? null;
    } catch (error) {
      this.logger.warn(`findBehavioral failed (${key}): ${(error as Error).message}`);
      return null;
    }
  }

  /**
   * Creates the fact or updates the existing row for the same logical
   * memory (userId+type+key) — no duplicate accumulation.
   */
  async upsert(userId: string, dto: CreateMemoryDto): Promise<UserMemory> {
    if (containsSensitiveData(dto.value)) {
      throw new BadRequestException(
        'Memory value contains forbidden (sensitive) keys.',
      );
    }
    // Phase 2D — single-line strings only (prompt line-forgery guard).
    if (containsControlCharacters(dto.value)) {
      throw new BadRequestException(
        'Memory value must not contain control characters.',
      );
    }
    const existing = await this.memories.findOne({
      where: { userId, type: dto.type, key: dto.key },
    });
    if (existing) {
      existing.value = dto.value;
      existing.source = dto.source;
      if (dto.confidence !== undefined) {
        existing.confidence = dto.confidence;
      }
      existing.expiresAt = dto.expiresAt ? new Date(dto.expiresAt) : null;
      return this.memories.save(existing);
    }
    const created = this.memories.create({
      userId,
      type: dto.type,
      key: dto.key,
      value: dto.value,
      source: dto.source,
      confidence: dto.confidence ?? 1,
      expiresAt: dto.expiresAt ? new Date(dto.expiresAt) : null,
    });
    return this.memories.save(created);
  }

  /** Updates a memory owned by [userId]; foreign records are Forbidden. */
  async updateOwn(
    userId: string,
    id: string,
    dto: UpdateMemoryDto,
  ): Promise<UserMemory> {
    if (dto.value !== undefined && containsSensitiveData(dto.value)) {
      throw new BadRequestException(
        'Memory value contains forbidden (sensitive) keys.',
      );
    }
    // Phase 2D — single-line strings only (prompt line-forgery guard).
    if (dto.value !== undefined && containsControlCharacters(dto.value)) {
      throw new BadRequestException(
        'Memory value must not contain control characters.',
      );
    }
    const memory = await this.memories.findOne({ where: { id } });
    if (!memory) throw new NotFoundException('Memory not found.');
    if (memory.userId !== userId) {
      throw new ForbiddenException('Not your memory.');
    }
    if (dto.value !== undefined) memory.value = dto.value;
    if (dto.source !== undefined) memory.source = dto.source;
    if (dto.confidence !== undefined) memory.confidence = dto.confidence;
    if (dto.expiresAt !== undefined) {
      memory.expiresAt = dto.expiresAt ? new Date(dto.expiresAt) : null;
    }
    return this.memories.save(memory);
  }

  /** Deletes one memory owned by [userId]; foreign records are Forbidden. */
  async deleteOwn(userId: string, id: string): Promise<void> {
    const memory = await this.memories.findOne({ where: { id } });
    if (!memory) throw new NotFoundException('Memory not found.');
    if (memory.userId !== userId) {
      throw new ForbiddenException('Not your memory.');
    }
    await this.memories.delete({ id });
  }

  /** Clears EVERY memory owned by [userId] — and only those. */
  async clearOwn(userId: string): Promise<void> {
    await this.memories.delete({ userId });
  }
}
