import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * P4-1 migration 1 — `payment_attempts`.
 *
 * One booking → many attempts, each with its own idempotency key. Idempotency
 * is unique per USER (not per booking), so a retried request can never create
 * a second attempt for the same logical payment even if the client points it
 * at a different booking. There is deliberately no unique `(bookingId,
 * userId)` constraint.
 *
 * The two extra unique constraints `(id, bookingId)` / `(id, userId)` exist
 * ONLY so the composite foreign keys from `bookings` and `payment_transactions`
 * can enforce that a consumed attempt belongs to the same booking and user.
 */
export class P4PaymentAttemptTable1731000000001 implements MigrationInterface {
  name = 'P4PaymentAttemptTable1731000000001';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS payment_attempts (
        id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
        "bookingId" uuid NOT NULL,
        "userId" varchar(255) NOT NULL,
        "attemptNo" integer NOT NULL,
        "idempotencyKey" varchar(255) NOT NULL,
        amount real NOT NULL,
        currency varchar(3) NOT NULL,
        status varchar(255) NOT NULL DEFAULT 'created',
        "gatewayId" varchar(255),
        "gatewayRef" varchar(255),
        method varchar(255),
        "failureCode" varchar(255),
        "consumedAt" timestamptz,
        "createdAt" timestamptz NOT NULL DEFAULT now(),
        "updatedAt" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT fk_payment_attempts_booking
          FOREIGN KEY ("bookingId") REFERENCES bookings(id),
        CONSTRAINT uq_payment_attempts_user_idempotency
          UNIQUE ("userId", "idempotencyKey"),
        CONSTRAINT uq_payment_attempts_id_booking
          UNIQUE (id, "bookingId"),
        CONSTRAINT uq_payment_attempts_id_user
          UNIQUE (id, "userId"),
        CONSTRAINT chk_payment_attempts_amount CHECK (amount >= 0),
        CONSTRAINT chk_payment_attempts_currency CHECK (currency ~ '^[A-Z]{3}$'),
        CONSTRAINT chk_payment_attempts_status CHECK (
          status IN (
            'created', 'requires_confirmation', 'pending', 'succeeded',
            'failed', 'unknown', 'consumed', 'voided', 'refunded',
            'partially_refunded'
          )
        )
      )
    `);
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS idx_payment_attempts_booking
        ON payment_attempts ("bookingId")
    `);
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS idx_payment_attempts_user_booking
        ON payment_attempts ("userId", "bookingId")
    `);
    await queryRunner.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS uq_payment_attempts_gateway_ref
        ON payment_attempts ("gatewayId", "gatewayRef")
        WHERE "gatewayRef" IS NOT NULL
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS payment_attempts`);
  }
}
