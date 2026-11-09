import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';

/**
 * Durable provider operation record (P4-1).
 *
 * Every provider call that can move a booking (revalidate, create, cancel,
 * read-only lookup) is recorded here so a lost/ambiguous response can be
 * reconciled WITHOUT a blind retry. The provider reference is unique per
 * provider — the same reference may legitimately exist for two different
 * providers, so the uniqueness scope is `(providerId, providerRef)`, not the
 * reference alone.
 *
 * A supplier payment is recorded as a `PaymentTransaction` with
 * `leg = 'SUPPLIER'` linked to one of these operations; it is never tied to a
 * customer `PaymentAttempt`.
 */
export const PROVIDER_OPERATION_STATUSES = [
  'pending',
  'confirmed',
  'failed',
  'unknown',
  'not_found',
] as const;

export type ProviderOperationStatus = (typeof PROVIDER_OPERATION_STATUSES)[number];

export const PROVIDER_OPERATION_TYPES = [
  'revalidate',
  'create_booking',
  'cancel_booking',
  'lookup',
] as const;

export type ProviderOperationType = (typeof PROVIDER_OPERATION_TYPES)[number];

@Entity('provider_operations')
@Index('uq_provider_operations_id_booking', ['id', 'bookingId'], {
  unique: true,
})
@Index('uq_provider_operations_provider_idem', ['providerId', 'idempotencyKey'], {
  unique: true,
})
@Index('idx_provider_operations_booking_op', ['bookingId', 'operation', 'createdAt'])
@Index('uq_provider_operations_provider_ref', ['providerId', 'providerRef'], {
  unique: true,
  where: `"providerRef" IS NOT NULL`,
})
export class ProviderOperation {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column()
  bookingId!: string;

  /** Stable provider key, e.g. 'duffel-flight' / 'nuitee-flight'. */
  @Column({ type: 'varchar' })
  providerId!: string;

  /** revalidate | create_booking | cancel_booking | lookup. */
  @Column({ type: 'varchar' })
  operation!: ProviderOperationType;

  /** Provider-side reference (order id / booking id). Unique per provider. */
  @Column({ type: 'varchar', nullable: true })
  providerRef?: string | null;

  /** Idempotency key for this provider call (unique per provider). */
  @Column({ type: 'varchar' })
  idempotencyKey!: string;

  /** pending | confirmed | failed | unknown | not_found. */
  @Column({ type: 'varchar', default: 'pending' })
  status!: ProviderOperationStatus;

  /** Request metadata (payload summary / ids). Never secrets. */
  @Column({ type: 'jsonb', nullable: true })
  requestMetadata?: Record<string, any> | null;

  /** Response metadata (status/reference/amount). Never secrets. */
  @Column({ type: 'jsonb', nullable: true })
  responseMetadata?: Record<string, any> | null;

  @Column({ type: 'timestamptz', nullable: true })
  startedAt?: Date | null;

  @Column({ type: 'timestamptz', nullable: true })
  completedAt?: Date | null;

  @CreateDateColumn()
  createdAt!: Date;

  @UpdateDateColumn()
  updatedAt!: Date;
}
