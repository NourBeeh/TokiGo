import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';

/**
 * Durable financial transaction (P4-1).
 *
 * Two strictly separate legs:
 *   CUSTOMER — the traveller paying TokiGo. MUST reference a
 *              `payment_attempts` row (and that attempt's booking must equal
 *              this row's booking, enforced by a composite FK).
 *   SUPPLIER — TokiGo paying the travel supplier. MUST reference a
 *              `provider_operations` row (and that operation's booking must
 *              equal this row's booking, enforced by a composite FK). It is
 *              NEVER tied to a customer attempt.
 *
 * The CHECK constraint `chk_payment_transactions_leg_links` makes the two
 * legs mutually exclusive, and the composite foreign keys make a cross-booking
 * reference impossible. A supplier settlement can therefore exist with no
 * customer attempt at all, while a customer transaction can never be recorded
 * without its matching attempt.
 *
 * `idempotencyKey` is globally unique: one financial effect per key, which is
 * what makes a refund/void retry safe.
 */
export const PAYMENT_TRANSACTION_LEGS = ['CUSTOMER', 'SUPPLIER'] as const;
export type PaymentTransactionLeg = (typeof PAYMENT_TRANSACTION_LEGS)[number];

export const PAYMENT_TRANSACTION_TYPES = [
  'authorize',
  'capture',
  'void',
  'refund',
  'adjustment',
] as const;
export type PaymentTransactionType = (typeof PAYMENT_TRANSACTION_TYPES)[number];

export const PAYMENT_TRANSACTION_STATUSES = [
  'initiated',
  'submitted',
  'succeeded',
  'failed',
  'unknown',
] as const;
export type PaymentTransactionStatus = (typeof PAYMENT_TRANSACTION_STATUSES)[number];

@Entity('payment_transactions')
@Index('uq_payment_transactions_idempotency', ['idempotencyKey'], { unique: true })
@Index('idx_payment_transactions_attempt', ['attemptId', 'type', 'createdAt'])
@Index('idx_payment_transactions_booking', ['bookingId'])
export class PaymentTransaction {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  /** The booking this financial movement belongs to (mandatory). */
  @Column()
  bookingId!: string;

  /** CUSTOMER leg only — the attempt being settled. Null for SUPPLIER. */
  @Column({ type: 'uuid', nullable: true })
  attemptId?: string | null;

  /** SUPPLIER leg only — the supplier operation being settled. Null for CUSTOMER. */
  @Column({ type: 'uuid', nullable: true })
  providerOperationId?: string | null;

  /** CUSTOMER | SUPPLIER. */
  @Column({ type: 'varchar' })
  leg!: PaymentTransactionLeg;

  /** authorize | capture | void | refund | adjustment. */
  @Column({ type: 'varchar' })
  type!: PaymentTransactionType;

  /** initiated | submitted | succeeded | failed | unknown. */
  @Column({ type: 'varchar', default: 'initiated' })
  status!: PaymentTransactionStatus;

  @Column({ type: 'real' })
  amount!: number;

  @Column({ type: 'varchar', length: 3 })
  currency!: string;

  /** Gateway reference (customer leg). */
  @Column({ type: 'varchar', nullable: true })
  gatewayRef?: string | null;

  /** Provider reference (supplier leg). */
  @Column({ type: 'varchar', nullable: true })
  providerRef?: string | null;

  /** One financial effect per key. */
  @Column({ type: 'varchar' })
  idempotencyKey!: string;

  @Column({ type: 'jsonb', nullable: true })
  metadata?: Record<string, any> | null;

  @CreateDateColumn()
  createdAt!: Date;

  @UpdateDateColumn()
  updatedAt!: Date;
}
