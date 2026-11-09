import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * P4-1 migration 0 — baseline for the two tables this phase extends.
 *
 * The production/development database already has `bookings` and `providers`
 * (created by TypeORM `synchronize`). This migration is `IF NOT EXISTS`, so
 * it is a strict no-op there. It exists so the P4-1 chain is reproducible
 * from a genuinely empty database with `synchronize: false` — which is what
 * the P4-1 migration test asserts.
 *
 * Column types/names mirror the TypeORM entities exactly (varchar(255),
 * real, jsonb, timestamptz, uuid defaults via gen_random_uuid()).
 */
export class P4BaseSchema1731000000000 implements MigrationInterface {
  name = 'P4BaseSchema1731000000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS bookings (
        id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
        "userId" varchar(255) NOT NULL,
        "searchId" varchar(255),
        "offerId" varchar(255) NOT NULL,
        "providerId" varchar(255) NOT NULL,
        "providerName" varchar(255) NOT NULL,
        type varchar(255) NOT NULL,
        status varchar(255) NOT NULL DEFAULT 'prepared',
        currency varchar(255) NOT NULL DEFAULT 'USD',
        "authoritativePrice" real NOT NULL DEFAULT 0,
        "previousPrice" real,
        "priceBreakdown" jsonb,
        "offerSnapshot" jsonb NOT NULL DEFAULT '{}',
        travelers jsonb NOT NULL DEFAULT '[]',
        "bookingReference" varchar(255),
        "providerMetadata" jsonb,
        "idempotencyKey" varchar(255),
        "expiresAt" timestamptz,
        "createdAt" timestamptz NOT NULL DEFAULT now(),
        "updatedAt" timestamptz NOT NULL DEFAULT now()
      )
    `);
    await queryRunner.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS idx_bookings_user_idempotency
        ON bookings ("userId", "idempotencyKey")
    `);

    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS providers (
        id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
        "providerKey" varchar(255) NOT NULL,
        name varchar(255) NOT NULL,
        config jsonb,
        "isActive" boolean NOT NULL DEFAULT true,
        vertical varchar(255),
        priority integer NOT NULL DEFAULT 0,
        "isFallback" boolean NOT NULL DEFAULT false,
        "healthStatus" varchar(255) DEFAULT 'unknown',
        "latencyMs" integer,
        "lastCheckedAt" timestamptz,
        "createdAt" timestamptz NOT NULL DEFAULT now(),
        "updatedAt" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT uq_providers_provider_key UNIQUE ("providerKey")
      )
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS providers`);
    await queryRunner.query(`DROP TABLE IF EXISTS bookings`);
  }
}
