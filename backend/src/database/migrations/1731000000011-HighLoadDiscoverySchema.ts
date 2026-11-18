import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * High-load refactor (Phase 2) — additive schema for discovery, optimized
 * images and push notification delivery.
 *
 * Deliberately metadata-only:
 *  - `hotels` stores NO price, rate or availability column. Check-in/out dates
 *    are search parameters and are intentionally absent.
 *  - `hotel_images` stores only the CDN URL + encoding metadata, never binary
 *    data and never the provider's original URL as the permanent URL.
 *  - `device_tokens` stores FCM tokens encrypted at rest (hash for dedupe).
 *
 * All statements are idempotent (`IF NOT EXISTS`) so the migration is safe on
 * a database that TypeORM `synchronize` has already touched, matching the
 * existing P4 chain's convention.
 */
export class HighLoadDiscoverySchema1731000000011 implements MigrationInterface {
  name = 'HighLoadDiscoverySchema1731000000011';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // ---------------------------------------------------------------
    // Hotel metadata (Meilisearch source + PostgreSQL fallback search).
    // ---------------------------------------------------------------
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS hotels (
        id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
        "providerId" varchar(255) NOT NULL,
        "providerHotelId" varchar(255) NOT NULL,
        name varchar(255) NOT NULL,
        "nameLocal" varchar(255),
        city varchar(255) NOT NULL,
        "countryCode" varchar(2) NOT NULL,
        address text,
        description text,
        "descriptionLocal" text,
        facilities jsonb NOT NULL DEFAULT '[]',
        category varchar(255),
        latitude double precision,
        longitude double precision,
        "imageObjectKey" varchar(255),
        "isActive" boolean NOT NULL DEFAULT true,
        "isDeleted" boolean NOT NULL DEFAULT false,
        "lastSyncedAt" timestamptz,
        "createdAt" timestamptz NOT NULL DEFAULT now(),
        "updatedAt" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT uq_hotels_provider_hotel UNIQUE ("providerId", "providerHotelId")
      )
    `);

    // Discovery by city/country (never check-in dates — those are ephemeral).
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS idx_hotels_city_country
        ON hotels ("city", "countryCode")
        WHERE "isDeleted" = false
    `);
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS idx_hotels_active_city
        ON hotels ("isActive", "city")
        WHERE "isDeleted" = false
    `);
    // Facility filters are a JSONB set containment query.
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS idx_hotels_facilities_gin
        ON hotels USING GIN (facilities jsonb_path_ops)
    `);
    // PostgreSQL fallback full-text search when Meilisearch is unavailable.
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS idx_hotels_search_gin
        ON hotels USING GIN (
          to_tsvector(
            'simple',
            coalesce(name, '') || ' ' ||
            coalesce("nameLocal", '') || ' ' ||
            coalesce(city, '') || ' ' ||
            coalesce("countryCode", '') || ' ' ||
            coalesce(address, '') || ' ' ||
            coalesce(description, '')
          )
        )
    `);
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS idx_hotels_last_synced
        ON hotels ("lastSyncedAt")
        WHERE "isDeleted" = false
    `);

    // ---------------------------------------------------------------
    // Optimized images. One row per deterministic object key.
    // ---------------------------------------------------------------
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS hotel_images (
        id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
        "hotelId" uuid,
        "objectKey" varchar(512) NOT NULL,
        "cdnUrl" varchar(1024) NOT NULL,
        "sourceUrlHash" varchar(64),
        width integer,
        height integer,
        "contentType" varchar(255) NOT NULL DEFAULT 'image/webp',
        bytes integer,
        "cacheControl" varchar(255) NOT NULL DEFAULT 'public, max-age=31536000, immutable',
        "createdAt" timestamptz NOT NULL DEFAULT now(),
        "updatedAt" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT uq_hotel_images_object_key UNIQUE ("objectKey"),
        CONSTRAINT fk_hotel_images_hotel
          FOREIGN KEY ("hotelId") REFERENCES hotels(id) ON DELETE SET NULL
      )
    `);
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS idx_hotel_images_hotel
        ON hotel_images ("hotelId")
        WHERE "hotelId" IS NOT NULL
    `);

    // ---------------------------------------------------------------
    // Push device tokens (encrypted at rest).
    // ---------------------------------------------------------------
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS device_tokens (
        id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
        "userId" varchar(255) NOT NULL,
        "tokenHash" varchar(64) NOT NULL,
        "tokenEncrypted" text NOT NULL,
        platform varchar(32),
        locale varchar(16),
        "isValid" boolean NOT NULL DEFAULT true,
        "lastError" varchar(255),
        "lastUsedAt" timestamptz,
        "createdAt" timestamptz NOT NULL DEFAULT now(),
        "updatedAt" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT uq_device_tokens_hash UNIQUE ("tokenHash")
      )
    `);
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS idx_device_tokens_user
        ON device_tokens ("userId", "isValid")
    `);

    // ---------------------------------------------------------------
    // Operational indexes for reconciliation and list endpoints.
    // ---------------------------------------------------------------
    // Sweep ambiguous/stale attempts without scanning terminal rows.
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS idx_payment_attempts_open
        ON payment_attempts ("status", "createdAt")
        WHERE status IN ('created', 'processing', 'requires_action', 'pending', 'unknown')
    `);
    // A traveller's booking list is the most common booking query.
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS idx_bookings_user_status_created
        ON bookings ("userId", "status", "createdAt")
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX IF EXISTS idx_bookings_user_status_created`);
    await queryRunner.query(`DROP INDEX IF EXISTS idx_payment_attempts_open`);
    await queryRunner.query(`DROP INDEX IF EXISTS idx_device_tokens_user`);
    await queryRunner.query(`DROP TABLE IF EXISTS device_tokens`);
    await queryRunner.query(`DROP INDEX IF EXISTS idx_hotel_images_hotel`);
    await queryRunner.query(`DROP TABLE IF EXISTS hotel_images`);
    await queryRunner.query(`DROP INDEX IF EXISTS idx_hotels_last_synced`);
    await queryRunner.query(`DROP INDEX IF EXISTS idx_hotels_search_gin`);
    await queryRunner.query(`DROP INDEX IF EXISTS idx_hotels_facilities_gin`);
    await queryRunner.query(`DROP INDEX IF EXISTS idx_hotels_active_city`);
    await queryRunner.query(`DROP INDEX IF EXISTS idx_hotels_city_country`);
    await queryRunner.query(`DROP TABLE IF EXISTS hotels`);
  }
}
