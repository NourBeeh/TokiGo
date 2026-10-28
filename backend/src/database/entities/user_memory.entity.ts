import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';

/**
 * User Memory Spine (Phase 2A — Foundation).
 *
 * One structured fact about a user — NOT a conversation transcript store:
 * each record is a small, typed `key → value` fact with provenance (source)
 * and a validated confidence. Everything flows from the JWT-authenticated
 * user; the client can never supply or query another user's memories.
 *
 * Logical uniqueness is enforced at the DATABASE level on
 * (userId, type, key): re-recording the same fact updates it instead of
 * piling duplicates (upsert semantics live in MemoryService).
 *
 * Supported types:   preference | behavior | conversation | derived
 * Supported sources: user_explicit | behavior_event | ai_conversation |
 *                    system_derived
 * (Validated at the DTO boundary via MEMORY_TYPES / MEMORY_SOURCES.)
 */
@Entity('user_memories')
@Index('idx_user_memories_user_type_key', ['userId', 'type', 'key'], {
  unique: true,
})
export class UserMemory {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  /** Owning user — ALWAYS derived from the JWT, never from the request body. */
  @Column()
  userId!: string;

  /** Fact category (see MEMORY_TYPES in common/dto/memory.dto.ts). */
  @Column()
  type!: string;

  /** Stable fact key, e.g. `preferred_destination`, `budget_max`. */
  @Column()
  key!: string;

  /** Structured fact value ONLY (jsonb) — transcripts are rejected upstream. */
  @Column({ type: 'jsonb' })
  value!: Record<string, any> | string | number | boolean;

  /** Provenance (see MEMORY_SOURCES in common/dto/memory.dto.ts). */
  @Column()
  source!: string;

  /** 0.0 <= confidence <= 1.0 — validated at the DTO boundary. */
  @Column({ type: 'real', default: 1 })
  confidence!: number;

  /** Optional expiry — expired records stay persisted but are hidden from
   * the default GET listing until includeExpired is requested. */
  @Column({ type: 'timestamp', nullable: true })
  expiresAt?: Date | null;

  @CreateDateColumn()
  createdAt!: Date;

  @UpdateDateColumn()
  updatedAt!: Date;
}
