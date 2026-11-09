import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * P4-2R migration 9 — guarantee the `processed_webhooks` archive exists.
 *
 * WHY THIS MIGRATION EXISTS
 * The ORIGINAL migration 8 dropped `processed_webhooks`. Any database that
 * executed that version has already lost the historical rows — editing
 * migration 8's `up()` cannot replay it, because TypeORM records migrations by
 * name and never re-runs an applied one.
 *
 * This migration is the safety net for exactly that case:
 *
 *  - `CREATE TABLE IF NOT EXISTS` — on a database that still has the table
 *    (never ran P4-2, or ran the corrected migration 8) this is a no-op and
 *    every historical row is untouched;
 *  - on a database that ran the ORIGINAL drop it recreates the table EMPTY.
 *    The rows are gone for good; no DDL can bring them back. This is the
 *    documented, unavoidable limitation of the original P4-2 change.
 *
 * The table is deliberately kept in the same shape the legacy entity maps:
 * `id` as the primary key (the original identity — a bare event id, no provider
 * column) and `processedAt` as a creation timestamp with a default, so both the
 * entity and raw SQL inserts work.
 *
 * `down()` is a no-op: dropping the archive again would recreate the data loss
 * this correction exists to prevent.
 */
export class P4RestoreProcessedWebhooksArchive1731000000009
  implements MigrationInterface
{
  name = 'P4RestoreProcessedWebhooksArchive1731000000009';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS processed_webhooks (
        id varchar(255) NOT NULL PRIMARY KEY,
        "processedAt" timestamptz NOT NULL DEFAULT now()
      )
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    // Intentionally a no-op — see the class comment.
  }
}
