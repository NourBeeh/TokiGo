import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';

/**
 * FCM device token (high-load refactor, Phase 2).
 *
 * The raw push token is encrypted at rest with AES-256-GCM; `tokenHash`
 * (SHA-256) is the unique/dedupe identity so a token is never stored or
 * indexed in clear. Invalid/expired tokens are flagged by the sender instead
 * of being deleted outright, preserving auditability.
 */
@Entity('device_tokens')
@Index('uq_device_tokens_hash', ['tokenHash'], { unique: true })
@Index('idx_device_tokens_user', ['userId', 'isValid'])
export class DeviceToken {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  /** Owning user — always derived from the JWT, never from a request body. */
  @Column({ type: 'varchar' })
  userId!: string;

  @Column({ type: 'varchar', length: 64 })
  tokenHash!: string;

  @Column({ type: 'text' })
  tokenEncrypted!: string;

  @Column({ type: 'varchar', length: 32, nullable: true })
  platform?: string | null;

  @Column({ type: 'varchar', length: 16, nullable: true })
  locale?: string | null;

  @Column({ default: true })
  isValid!: boolean;

  /** Normalised FCM error code (e.g. UNREGISTERED), never the raw payload. */
  @Column({ type: 'varchar', length: 255, nullable: true })
  lastError?: string | null;

  @Column({ type: 'timestamptz', nullable: true })
  lastUsedAt?: Date | null;

  @CreateDateColumn()
  createdAt!: Date;

  @UpdateDateColumn()
  updatedAt!: Date;
}
