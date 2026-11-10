import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryColumn,
  UpdateDateColumn,
} from 'typeorm';

/**
 * Durable webhook event record (P4-1) — replay protection with integrity.
 *
 * Replaces the thin in-memory `processed_webhooks` set as the durable target.
 * The primary key is `(provider, eventId)`, so the same event id from two
 * different providers is distinct, and a replayed event is rejected by the
 * database itself rather than by a process-local Set that dies on restart.
 *
 * `payloadHash` stores a hash of the raw payload for integrity/audit. The
 * processing `status` records how far the event got; it is deliberately NOT a
 * payment state — marking an arbitrary webhook as a successful payment is a
 * state-specific validation that belongs to payment orchestration (P4-2+).
 *
 * P4-2R2 — three distinguishable outcomes:
 *
 *   received   claimed, no effect attempted yet (in flight)
 *   retryable  TRANSIENT failure — not resolved, redelivery retries it, and it
 *              is NEVER written to the legacy archive
 *   processed  the payment transition and ledger effect committed
 *   failed     PERMANENT rejection — a confirmed contradiction; archived
 *   ignored    retained for pre-P4-2R2 rows; no longer written
 */
export const WEBHOOK_EVENT_STATUSES = [
  'received',
  'retryable',
  'processed',
  'failed',
  'ignored',
] as const;
export type WebhookEventStatus = (typeof WEBHOOK_EVENT_STATUSES)[number];

/**
 * Statuses that mean "this event is settled; a redelivery must not touch it".
 * `retryable` and `received` are deliberately absent.
 */
export const WEBHOOK_EVENT_FINAL_STATUSES = ['processed', 'failed', 'ignored'] as const;

/**
 * Statuses that mean "this event may be attempted again".
 * A `retryable` event keeps its diagnostic `outcome` so an operator can see why
 * it has not settled, but it is NOT archived as processed.
 */
export const WEBHOOK_EVENT_RETRYABLE_STATUSES = ['received', 'retryable'] as const;

@Entity('webhook_events')
export class WebhookEvent {
  /** Gateway/provider that emitted the event, e.g. 'mock-eg-gate'. */
  @PrimaryColumn({ type: 'varchar' })
  provider!: string;

  /** Provider's own event id. */
  @PrimaryColumn({ type: 'varchar' })
  eventId!: string;

  /** payment.succeeded | payment.failed | payment.refunded | ... */
  @Column({ type: 'varchar' })
  eventType!: string;

  /** SHA-256 of the raw payload (integrity/audit, not a secret). */
  @Column({ type: 'varchar' })
  payloadHash!: string;

  /** received | retryable | processed | failed | ignored. */
  @Column({ type: 'varchar', default: 'received' })
  status!: WebhookEventStatus;

  /** Optional outcome detail, e.g. the payment/attempt the event resolved to. */
  @Column({ type: 'varchar', nullable: true })
  outcome?: string | null;

  @Column({ type: 'timestamptz', default: () => 'now()' })
  receivedAt!: Date;

  @Column({ type: 'timestamptz', nullable: true })
  processedAt?: Date | null;

  @CreateDateColumn()
  createdAt!: Date;

  @UpdateDateColumn()
  updatedAt!: Date;
}
