import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';

import {
  PAYMENT_ATTEMPT_STATUSES,
  PaymentAttemptStatus,
} from '../../modules/payments/payment-attempt.state';

export { PAYMENT_ATTEMPT_STATUSES };
export type { PaymentAttemptStatus };

/**
 * A single customer payment attempt (P4-1 durable schema, P4-2 state model).
 *
 * One booking may have MANY attempts (a decline must not block a retry), and
 * every attempt carries its OWN idempotency key. The uniqueness that matters
 * is `(userId, idempotencyKey)` — a retried request can never create a second
 * attempt for the same logical operation, no matter which booking it targets.
 *
 * There is deliberately NO unique `(bookingId, userId)` constraint: that would
 * make a second attempt for the same booking impossible.
 *
 * Consumption is recorded from the `bookings` side (`bookings.paymentAttemptId`)
 * so a single partial unique index there enforces both:
 *   - one attempt cannot be consumed by two bookings;
 *   - a booking cannot consume two attempts.
 * The composite foreign keys declared in the migration additionally enforce
 * that a consumed attempt belongs to the same booking AND the same user.
 *
 * Ownership integrity: the composite FK
 *   payment_attempts("bookingId", "userId") → bookings(id, "userId")
 * guarantees every attempt belongs to the booking's owner. There is therefore
 * no path to create an attempt for another user's booking.
 *
 * Amount/currency come from the checkout request and are validated server-side
 * against the booking (the currency MUST match `bookings.currency`, the amount
 * MUST be positive). The booking's provider-revalidated price is the floor the
 * client builds on, but checkout may add legitimate add-ons on top of it, so
 * the charged amount is the client-quoted total rather than the raw offer
 * price.
 */
@Entity('payment_attempts')
@Index('uq_payment_attempts_user_idempotency', ['userId', 'idempotencyKey'], {
  unique: true,
})
@Index('uq_payment_attempts_id_booking', ['id', 'bookingId'], { unique: true })
@Index('uq_payment_attempts_id_user', ['id', 'userId'], { unique: true })
@Index('idx_payment_attempts_booking', ['bookingId'])
@Index('idx_payment_attempts_user_booking', ['userId', 'bookingId'])
@Index('uq_payment_attempts_gateway_ref', ['gatewayId', 'gatewayRef'], {
  unique: true,
  where: `"gatewayRef" IS NOT NULL`,
})
export class PaymentAttempt {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  /** The booking this attempt pays for. */
  @Column()
  bookingId!: string;

  /** Owning user — always derived from the JWT, never from the request body. */
  @Column()
  userId!: string;

  /** 1-based attempt number within the booking (diagnostics/ordering only). */
  @Column({ type: 'int' })
  attemptNo!: number;

  /** Client-generated idempotency key; unique per user across all bookings. */
  @Column({ type: 'varchar' })
  idempotencyKey!: string;

  /** Charged amount (client-quoted checkout total, validated server-side). */
  @Column({ type: 'real' })
  amount!: number;

  /** ISO-4217, e.g. EGP / USD. Must equal `bookings.currency`. */
  @Column({ type: 'varchar', length: 3 })
  currency!: string;

  /** See {@link PaymentAttemptStatus} for the state machine. */
  @Column({ type: 'varchar', default: 'created' })
  status!: PaymentAttemptStatus;

  /** Gateway that processed the attempt (e.g. mock-eg-gate). */
  @Column({ type: 'varchar', nullable: true })
  gatewayId?: string | null;

  /** Gateway's own reference for this attempt. */
  @Column({ type: 'varchar', nullable: true })
  gatewayRef?: string | null;

  /** Payment method used (CARD_SUCCESS / CARD_3DS / WALLET ...). */
  @Column({ type: 'varchar', nullable: true })
  method?: string | null;

  /**
   * Normalised failure code for `failed` / `unknown`. Drawn from a fixed
   * vocabulary only — never the raw provider message, which can carry request
   * ids or other operational detail.
   */
  @Column({ type: 'varchar', nullable: true })
  failureCode?: string | null;

  /** Set when a booking consumes this attempt. */
  @Column({ type: 'timestamptz', nullable: true })
  consumedAt?: Date | null;

  @CreateDateColumn()
  createdAt!: Date;

  @UpdateDateColumn()
  updatedAt!: Date;
}
