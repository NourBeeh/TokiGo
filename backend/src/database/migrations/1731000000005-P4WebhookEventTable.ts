import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * P4-1 migration 5 — `webhook_events`.
 *
 * Durable replay protection keyed by `(provider, eventId)`: the same event id
 * from two providers is distinct, and a replayed event is rejected by the
 * primary key rather than by a process-local Set that dies on restart.
 *
 * `payloadHash` records the integrity hash of the raw payload. The `status`
 * column only records how far processing got — it is deliberately NOT a
 * payment state. Mapping a webhook to a successful payment is state-specific
 * validation that belongs to payment orchestration (P4-2+).
 *
 * The legacy `processed_webhooks` table is left untouched by THIS migration:
 * at P4-1 time the PaymentService still consulted it. P4-2 makes this table
 * the single authoritative replay store and retires the legacy one in
 * migration 1731000000008.
 */
export class P4WebhookEventTable1731000000005 implements MigrationInterface {
  name = 'P4WebhookEventTable1731000000005';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS webhook_events (
        provider varchar(255) NOT NULL,
        "eventId" varchar(255) NOT NULL,
        "eventType" varchar(255) NOT NULL,
        "payloadHash" varchar(255) NOT NULL,
        status varchar(255) NOT NULL DEFAULT 'received',
        outcome varchar(255),
        "receivedAt" timestamptz NOT NULL DEFAULT now(),
        "processedAt" timestamptz,
        "createdAt" timestamptz NOT NULL DEFAULT now(),
        "updatedAt" timestamptz NOT NULL DEFAULT now(),
        PRIMARY KEY (provider, "eventId"),
        CONSTRAINT chk_webhook_events_status CHECK (
          status IN ('received', 'processed', 'failed', 'ignored')
        )
      )
    `);
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS idx_webhook_events_received
        ON webhook_events ("receivedAt")
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS webhook_events`);
  }
}
