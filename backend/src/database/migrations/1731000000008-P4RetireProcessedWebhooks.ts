import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * P4-2 migration 8 — retire `processed_webhooks` as a WRITER, not as a table.
 *
 * CORRECTED IN P4-2R.
 *
 * The original version of this migration ran `DROP TABLE processed_webhooks`.
 * That discarded every historical deduplication record: after the drop, a
 * webhook id that had already been processed before P4-2 could be applied a
 * second time. P4-2R reverses that decision.
 *
 * The table is now RETAINED as an archive and compatibility source:
 *
 *  - nothing is dropped, so every historical row survives;
 *  - `PaymentService.handleWebhook` checks it before applying any effect
 *    (see `processed_webhook.entity.ts`);
 *  - new events are written to it as well, with `ON CONFLICT DO NOTHING`, so it
 *    cannot drift away from `webhook_events`;
 *  - migration 9 (`P4RestoreProcessedWebhooksArchive`) recreates the table for
 *    the databases that already executed the ORIGINAL drop, where the rows are
 *    unrecoverable by DDL. Those databases get an empty archive; the loss is
 *    documented in `docs/p4-2r-report-*.md`.
 *
 * Because this migration is already recorded as applied in the databases that
 * ran it, editing `up()` does not re-execute it there — that is exactly why
 * migration 9 exists. For a database that has never applied P4-2, `up()` is a
 * no-op and the table (with its rows) is simply carried forward.
 *
 * `down()` is a no-op: there is nothing to un-retire. Reverting to a state
 * where the table is dropped again would repeat the data loss this correction
 * exists to prevent.
 */
export class P4RetireProcessedWebhooks1731000000008 implements MigrationInterface {
  name = 'P4RetireProcessedWebhooks1731000000008';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // Intentionally a no-op: the legacy table is retained as an archive.
    // See the class comment and migration 1731000000009.
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    // Intentionally a no-op: dropping the archive again would destroy the
    // historical replay records this correction exists to protect.
  }
}
