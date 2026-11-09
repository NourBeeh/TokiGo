import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * P4-1 migration 3 — booking payment/recovery extensions.
 *
 * Adds the consumed-attempt reference, customer payment status, confirmation
 * lease metadata, the legacy/unverified flag and an optimistic-concurrency
 * version. All columns are nullable/defaulted, so this is a safe additive
 * change on a live table.
 *
 * Backfill: every booking that existed before P4-1 has no verifiable payment
 * proof. Those rows are marked `legacy_unverified` / `paymentStatus =
 * 'legacy_unverified'`. NO payment evidence is fabricated and no fake
 * transaction is created. New rows default to `legacyUnverified = false` /
 * `paymentStatus = 'unverified'`.
 *
 * Cross-booking/cross-user protection is enforced by two composite FKs:
 *   bookings("paymentAttemptId", id)          → payment_attempts(id, "bookingId")
 *   bookings("paymentAttemptId", "userId")    → payment_attempts(id, "userId")
 * so a consumed attempt MUST belong to this booking and this user.
 *
 * Ownership integrity (P4-1R): `payment_attempts("bookingId", "userId")`
 * references `bookings(id, "userId")` via a new unique constraint on the
 * bookings side. Every attempt is therefore provably owned by the booking's
 * owner — a user cannot create an attempt against somebody else's booking.
 * Because CUSTOMER transactions must match the attempt's booking (composite
 * FK) and the attempt must match the booking's owner, a CUSTOMER transaction
 * can no longer reference another user's attempt.
 */
export class P4BookingPaymentColumns1731000000003 implements MigrationInterface {
  name = 'P4BookingPaymentColumns1731000000003';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE bookings
        ADD COLUMN IF NOT EXISTS "paymentAttemptId" uuid,
        ADD COLUMN IF NOT EXISTS "paymentStatus" varchar(255) NOT NULL DEFAULT 'unverified',
        ADD COLUMN IF NOT EXISTS "consumedAt" timestamptz,
        ADD COLUMN IF NOT EXISTS "confirmingSince" timestamptz,
        ADD COLUMN IF NOT EXISTS "confirmingOwner" varchar(255),
        ADD COLUMN IF NOT EXISTS "legacyUnverified" boolean NOT NULL DEFAULT false,
        ADD COLUMN IF NOT EXISTS "version" integer NOT NULL DEFAULT 0
    `);

    // Existing rows have no payment proof → legacy/unverified, never "paid".
    await queryRunner.query(`
      UPDATE bookings
      SET "legacyUnverified" = true,
          "paymentStatus" = 'legacy_unverified'
      WHERE "paymentAttemptId" IS NULL
    `);

    // One attempt cannot be consumed by two bookings.
    await queryRunner.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS uq_bookings_payment_attempt
        ON bookings ("paymentAttemptId")
        WHERE "paymentAttemptId" IS NOT NULL
    `);
    // Recovery sweep for stale confirmation leases.
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS idx_bookings_status_confirming_since
        ON bookings (status, "confirmingSince")
    `);

    // A consumed attempt must belong to this booking AND this user.
    await queryRunner.query(`
      ALTER TABLE bookings
        ADD CONSTRAINT fk_bookings_payment_attempt_booking
        FOREIGN KEY ("paymentAttemptId", id)
        REFERENCES payment_attempts (id, "bookingId")
    `);
    await queryRunner.query(`
      ALTER TABLE bookings
        ADD CONSTRAINT fk_bookings_payment_attempt_user
        FOREIGN KEY ("paymentAttemptId", "userId")
        REFERENCES payment_attempts (id, "userId")
    `);

    // Ownership integrity: an attempt's (bookingId, userId) must match the
    // booking row's owner. Requires a unique constraint on the referenced
    // columns; `id` is already the primary key, so (id, "userId") is unique.
    await queryRunner.query(`
      ALTER TABLE bookings
        ADD CONSTRAINT uq_bookings_id_user UNIQUE (id, "userId")
    `);
    await queryRunner.query(`
      ALTER TABLE payment_attempts
        ADD CONSTRAINT fk_payment_attempts_booking_user
        FOREIGN KEY ("bookingId", "userId")
        REFERENCES bookings (id, "userId")
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE payment_attempts
        DROP CONSTRAINT IF EXISTS fk_payment_attempts_booking_user
    `);
    await queryRunner.query(`
      ALTER TABLE bookings DROP CONSTRAINT IF EXISTS uq_bookings_id_user
    `);
    await queryRunner.query(`
      ALTER TABLE bookings DROP CONSTRAINT IF EXISTS fk_bookings_payment_attempt_user
    `);
    await queryRunner.query(`
      ALTER TABLE bookings DROP CONSTRAINT IF EXISTS fk_bookings_payment_attempt_booking
    `);
    await queryRunner.query(`
      DROP INDEX IF EXISTS idx_bookings_status_confirming_since
    `);
    await queryRunner.query(`
      DROP INDEX IF EXISTS uq_bookings_payment_attempt
    `);
    await queryRunner.query(`
      ALTER TABLE bookings
        DROP COLUMN IF EXISTS "version",
        DROP COLUMN IF EXISTS "legacyUnverified",
        DROP COLUMN IF EXISTS "confirmingOwner",
        DROP COLUMN IF EXISTS "confirmingSince",
        DROP COLUMN IF EXISTS "consumedAt",
        DROP COLUMN IF EXISTS "paymentStatus",
        DROP COLUMN IF EXISTS "paymentAttemptId"
    `);
  }
}
