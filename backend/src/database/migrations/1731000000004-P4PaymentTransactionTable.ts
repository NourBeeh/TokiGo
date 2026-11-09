import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * P4-1 migration 4 — `payment_transactions`.
 *
 * Customer and supplier money are recorded as two strictly separate legs:
 *
 *   CUSTOMER  → must reference a payment_attempts row; the composite FK
 *               (attemptId, bookingId) → payment_attempts(id, bookingId)
 *               makes a cross-booking customer transaction impossible.
 *   SUPPLIER  → must reference a provider_operations row; the composite FK
 *               (providerOperationId, bookingId) → provider_operations(id,
 *               bookingId) makes a cross-booking supplier settlement impossible.
 *
 * The CHECK `chk_payment_transactions_leg_links` makes the legs mutually
 * exclusive, so a supplier settlement can exist with no customer attempt, and
 * a customer transaction can never be recorded without its matching attempt.
 *
 * `idempotencyKey` is globally unique — one financial effect per key.
 */
export class P4PaymentTransactionTable1731000000004 implements MigrationInterface {
  name = 'P4PaymentTransactionTable1731000000004';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS payment_transactions (
        id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
        "bookingId" uuid NOT NULL,
        "attemptId" uuid,
        "providerOperationId" uuid,
        leg varchar(255) NOT NULL,
        type varchar(255) NOT NULL,
        status varchar(255) NOT NULL DEFAULT 'initiated',
        amount real NOT NULL,
        currency varchar(3) NOT NULL,
        "gatewayRef" varchar(255),
        "providerRef" varchar(255),
        "idempotencyKey" varchar(255) NOT NULL,
        metadata jsonb,
        "createdAt" timestamptz NOT NULL DEFAULT now(),
        "updatedAt" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT fk_payment_transactions_booking
          FOREIGN KEY ("bookingId") REFERENCES bookings(id),
        CONSTRAINT fk_payment_transactions_attempt
          FOREIGN KEY ("attemptId") REFERENCES payment_attempts(id),
        CONSTRAINT fk_payment_transactions_operation
          FOREIGN KEY ("providerOperationId") REFERENCES provider_operations(id),
        CONSTRAINT fk_payment_transactions_attempt_booking
          FOREIGN KEY ("attemptId", "bookingId")
          REFERENCES payment_attempts (id, "bookingId"),
        CONSTRAINT fk_payment_transactions_operation_booking
          FOREIGN KEY ("providerOperationId", "bookingId")
          REFERENCES provider_operations (id, "bookingId"),
        CONSTRAINT uq_payment_transactions_idempotency
          UNIQUE ("idempotencyKey"),
        CONSTRAINT chk_payment_transactions_leg CHECK (leg IN ('CUSTOMER', 'SUPPLIER')),
        CONSTRAINT chk_payment_transactions_leg_links CHECK (
          (leg = 'CUSTOMER' AND "attemptId" IS NOT NULL AND "providerOperationId" IS NULL)
          OR
          (leg = 'SUPPLIER' AND "providerOperationId" IS NOT NULL AND "attemptId" IS NULL)
        ),
        CONSTRAINT chk_payment_transactions_type CHECK (
          type IN ('authorize', 'capture', 'void', 'refund', 'adjustment')
        ),
        CONSTRAINT chk_payment_transactions_status CHECK (
          status IN ('initiated', 'submitted', 'succeeded', 'failed', 'unknown')
        ),
        CONSTRAINT chk_payment_transactions_amount CHECK (amount >= 0),
        CONSTRAINT chk_payment_transactions_currency CHECK (currency ~ '^[A-Z]{3}$')
      )
    `);
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS idx_payment_transactions_attempt
        ON payment_transactions ("attemptId", type, "createdAt")
    `);
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS idx_payment_transactions_booking
        ON payment_transactions ("bookingId")
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS payment_transactions`);
  }
}
