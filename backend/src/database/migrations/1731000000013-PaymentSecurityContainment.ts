import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Phase 3C.1 — payment security containment.
 *
 * Adds the durable facts required to prove that a booking was paid for the
 * EXACT accepted commercial state:
 *
 *  - `bookings.priceVersion` — the accepted provider/offer/amount/currency/
 *    terms version. A payment can only be created for, and consumed by, this
 *    version. It is null whenever no price is currently accepted.
 *  - `payment_attempts.priceVersion` — the version the attempt was charged for.
 *  - `payment_attempts.verifiedAt` — set only when the SERVER observed an
 *    authoritative `succeeded` transition (confirm or signed webhook). A
 *    client-declared success never sets it.
 *
 * The columns are nullable and NO backfill is fabricated: existing attempts
 * have no verifiable server evidence, so they remain unverified and cannot
 * authorize a booking or a refund. New rows are populated by the application.
 */
export class PaymentSecurityContainment1731000000013
  implements MigrationInterface
{
  name = 'PaymentSecurityContainment1731000000013';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE bookings
        ADD COLUMN IF NOT EXISTS "priceVersion" varchar(255)
    `);
    await queryRunner.query(`
      ALTER TABLE payment_attempts
        ADD COLUMN IF NOT EXISTS "priceVersion" varchar(255),
        ADD COLUMN IF NOT EXISTS "verifiedAt" timestamptz
    `);

    // Attempt selection is always scoped to one booking and one accepted
    // price version.
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS idx_payment_attempts_booking_price_version
        ON payment_attempts ("bookingId", "priceVersion")
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      DROP INDEX IF EXISTS idx_payment_attempts_booking_price_version
    `);
    await queryRunner.query(`
      ALTER TABLE payment_attempts
        DROP COLUMN IF EXISTS "verifiedAt",
        DROP COLUMN IF EXISTS "priceVersion"
    `);
    await queryRunner.query(`
      ALTER TABLE bookings
        DROP COLUMN IF EXISTS "priceVersion"
    `);
  }
}
