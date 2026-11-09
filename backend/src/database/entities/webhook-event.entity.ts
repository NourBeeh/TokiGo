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
 */
export const WEBHOOK_EVENT_STATUSES = ['received', 'processed', 'failed', 'ignored'] as const;
export type WebhookEventStatus = (typeof WEBHOOK_EVENT_STATUSES)[number];

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

  /** received | processed | failed | ignored. */
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
