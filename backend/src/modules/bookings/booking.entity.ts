import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';

/**
 * Booking foundation (Phase 4A).
 *
 * The persisted, JWT-scoped booking record. It is the ONLY source of booking
 * truth: the client's Hive snapshot is never trusted as a final price, and
 * `authoritativePrice` always originates from a provider-side revalidation
 * performed at prepare/create time — never from the request body.
 *
 * Provider snapshot (`offerSnapshot`) is mandatory to persist because some
 * providers hand back single-use handoff ids (Nuitee `prebookId` /
 * `transactionId`) that are NOT recoverable if the response is lost. Losing
 * them would strand a payable quote — so they live in this row, never in
 * Flutter, and are never returned raw to the client.
 *
 * Idempotency: logical uniqueness on (userId, idempotencyKey) guarantees a
 * retried create can never produce a second booking. A null key (prepare
 * stage) is allowed and does not collide (Postgres treats NULLs as distinct).
 *
 * No payment secrets or provider credentials are ever stored here (spec
 * non-negotiable) — payment is a later phase.
 */
export const BOOKING_STATUSES = [
  'prepared',
  'revalidated',
  'confirming',
  'confirmed',
  'failed',
  'cancelled',
  'expired',
] as const;

export type BookingStatus = (typeof BOOKING_STATUSES)[number];

@Entity('bookings')
@Index('idx_bookings_user_idempotency', ['userId', 'idempotencyKey'], {
  unique: true,
})
@Index('uq_bookings_payment_attempt', ['paymentAttemptId'], {
  unique: true,
  where: `"paymentAttemptId" IS NOT NULL`,
})
@Index('idx_bookings_status_confirming_since', ['status', 'confirmingSince'])
export class Booking {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  /** Owning user — ALWAYS derived from the JWT, never from the request body. */
  @Column()
  userId!: string;

  @Column({ type: 'varchar', nullable: true })
  searchId?: string | null;

  @Column()
  offerId!: string;

  /** Provider identity is mandatory — an offer without one cannot be booked. */
  @Column()
  providerId!: string;

  @Column()
  providerName!: string;

  /** Vertical: flight | hotel | car | package. */
  @Column()
  type!: string;

  @Column({ type: 'varchar', default: 'prepared' })
  status!: BookingStatus;

  @Column({ type: 'varchar', default: 'USD' })
  currency!: string;

  /** Provider-side authoritative amount (never a client-supplied price). */
  @Column({ type: 'real', default: 0 })
  authoritativePrice!: number;

  /** Previous authoritative amount when a revalidation moved the price. */
  @Column({ type: 'real', nullable: true })
  previousPrice?: number | null;

  @Column({ type: 'jsonb', nullable: true })
  priceBreakdown?: Record<string, any> | null;

  /**
   * Provider handoff snapshot (single-use ids, raw offer facts). Mandatory in
   * practice for providers with prebook handoff ids. Never returned raw.
   */
  @Column({ type: 'jsonb', default: () => "'{}'" })
  offerSnapshot!: Record<string, any>;

  @Column({ type: 'jsonb', default: () => "'[]'" })
  travelers!: any[];

  /** Provider confirmation reference (PNR / confirmation number). */
  @Column({ type: 'varchar', nullable: true })
  bookingReference?: string | null;

  @Column({ type: 'jsonb', nullable: true })
  providerMetadata?: Record<string, any> | null;

  /** Client-generated idempotency key (unique per user). */
  @Column({ type: 'varchar', nullable: true })
  idempotencyKey?: string | null;

  /** Quote expiry when the provider communicates one. */
  @Column({ type: 'timestamptz', nullable: true })
  expiresAt?: Date | null;

  // ------------------------------------------------------------------
  // P4-1 durable payment / recovery extensions.
  //
  // `paymentAttemptId` is the SINGLE successful customer attempt consumed by
  // this booking. The column being single-valued already guarantees a booking
  // cannot consume two attempts; the partial unique index guarantees one
  // attempt cannot be consumed by two bookings; composite FKs (migration)
  // guarantee the attempt belongs to this booking AND this user.
  // ------------------------------------------------------------------

  /** The consumed customer payment attempt (nullable until payment proof). */
  @Column({ type: 'uuid', nullable: true })
  paymentAttemptId?: string | null;

  /**
   * Customer payment status: unverified | legacy_unverified | pending |
   * verified | failed | refunded | partially_refunded. Derived from the
   * CUSTOMER leg only — never from supplier settlement.
   */
  @Column({ type: 'varchar', default: 'unverified' })
  paymentStatus!: string;

  /** When the consumed attempt was attached to this booking. */
  @Column({ type: 'timestamptz', nullable: true })
  consumedAt?: Date | null;

  /** Confirmation lease: set when a provider confirmation starts. */
  @Column({ type: 'timestamptz', nullable: true })
  confirmingSince?: Date | null;

  /** Confirmation lease owner (instance id) for recovery diagnostics. */
  @Column({ type: 'varchar', nullable: true })
  confirmingOwner?: string | null;

  /**
   * Pre-P4-1 bookings have no verifiable payment proof. They are marked
   * legacy/unverified by the migration and must never be treated as paid.
   * New bookings default to false.
   */
  @Column({ default: false })
  legacyUnverified!: boolean;

  /** Optimistic concurrency version for booking state transitions. */
  @Column({ type: 'int', default: 0 })
  version!: number;

  @CreateDateColumn()
  createdAt!: Date;

  @UpdateDateColumn()
  updatedAt!: Date;
}
