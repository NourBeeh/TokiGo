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

  @CreateDateColumn()
  createdAt!: Date;

  @UpdateDateColumn()
  updatedAt!: Date;
}
