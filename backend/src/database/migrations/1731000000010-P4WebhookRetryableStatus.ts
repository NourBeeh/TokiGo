import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * P4-2R2 migration 10 — add the `retryable` outcome to `webhook_events`.
 *
 * WHY
 * The P4-2/P4-2R handler used only four statuses, and every non-success path
 * ended in `failed` or `ignored` — both of which `claimWebhookEvent` treats as a
 * hard duplicate. That made a TRANSIENT failure permanently consumed:
 *
 *   - a gateway lookup that timed out,
 *   - an event that arrived before its payment/attempt association existed,
 *   - a database transaction failure while applying the effect
 *
 * all ended up archived in `processed_webhooks` and blocked forever, so the
 * payment could never settle and the event could never be retried.
 *
 * `retryable` is the explicit third outcome the spec asks for. It is the ONLY
 * new value: `received` still means "claimed, in flight", `processed` still
 * means "the financial effect committed", `failed` now means "permanently
 * rejected — confirmed contradiction", and `ignored` is retained for existing
 * rows but no longer written.
 *
 * This is the smallest change that makes the three states distinguishable; no
 * other column or table changes.
 *
 * `down()` translates `retryable` back to `received` before narrowing the
 * constraint, so a rollback loses no information.
 */
export class P4WebhookRetryableStatus1731000000010 implements MigrationInterface {
  name = 'P4WebhookRetryableStatus1731000000010';

  private static readonly CONSTRAINT = 'chk_webhook_events_status';
  private static readonly OLD_SET = ['received', 'processed', 'failed', 'ignored'];
  private static readonly NEW_SET = ['received', 'retryable', 'processed', 'failed', 'ignored'];

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE webhook_events
      DROP CONSTRAINT IF EXISTS chk_webhook_events_status
    `);
    await queryRunner.query(`
      ALTER TABLE webhook_events
      ADD CONSTRAINT chk_webhook_events_status CHECK (
        status IN (${P4WebhookRetryableStatus1731000000010.NEW_SET.map(s => `'${s}'`).join(', ')})
      )
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    // `retryable` is just "received with a recorded reason" — translate back so
    // the narrowed constraint is still satisfied.
    await queryRunner.query(`
      UPDATE webhook_events SET status = 'received' WHERE status = 'retryable'
    `);
    await queryRunner.query(`
      ALTER TABLE webhook_events
      DROP CONSTRAINT IF EXISTS chk_webhook_events_status
    `);
    await queryRunner.query(`
      ALTER TABLE webhook_events
      ADD CONSTRAINT chk_webhook_events_status CHECK (
        status IN (${P4WebhookRetryableStatus1731000000010.OLD_SET.map(s => `'${s}'`).join(', ')})
      )
    `);
  }
}
