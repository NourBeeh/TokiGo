import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * P4-1 migration 2 — `provider_operations`.
 *
 * Durable record of every provider call that can move a booking. The provider
 * reference is unique per PROVIDER (`(providerId, providerRef)`), because the
 * same reference string may legitimately exist for two different providers.
 * A missing reference (pending call) is allowed and does not collide.
 */
export class P4ProviderOperationTable1731000000002 implements MigrationInterface {
  name = 'P4ProviderOperationTable1731000000002';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS provider_operations (
        id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
        "bookingId" uuid NOT NULL,
        "providerId" varchar(255) NOT NULL,
        operation varchar(255) NOT NULL,
        "providerRef" varchar(255),
        "idempotencyKey" varchar(255) NOT NULL,
        status varchar(255) NOT NULL DEFAULT 'pending',
        "requestMetadata" jsonb,
        "responseMetadata" jsonb,
        "startedAt" timestamptz,
        "completedAt" timestamptz,
        "createdAt" timestamptz NOT NULL DEFAULT now(),
        "updatedAt" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT fk_provider_operations_booking
          FOREIGN KEY ("bookingId") REFERENCES bookings(id),
        CONSTRAINT uq_provider_operations_id_booking
          UNIQUE (id, "bookingId"),
        CONSTRAINT uq_provider_operations_provider_idem
          UNIQUE ("providerId", "idempotencyKey"),
        CONSTRAINT chk_provider_operations_status CHECK (
          status IN ('pending', 'confirmed', 'failed', 'unknown', 'not_found')
        ),
        CONSTRAINT chk_provider_operations_type CHECK (
          operation IN ('revalidate', 'create_booking', 'cancel_booking', 'lookup')
        )
      )
    `);
    await queryRunner.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS uq_provider_operations_provider_ref
        ON provider_operations ("providerId", "providerRef")
        WHERE "providerRef" IS NOT NULL
    `);
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS idx_provider_operations_booking_op
        ON provider_operations ("bookingId", operation, "createdAt")
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS provider_operations`);
  }
}
