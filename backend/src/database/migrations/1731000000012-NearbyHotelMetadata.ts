import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Nearby Stays (R1/R2) — additive hotel metadata for geographic discovery.
 *
 * `hotels` already carried latitude/longitude; this adds the guest rating and
 * review count the nearby ranking needs, plus a coordinate index so a radius
 * query can prefilter with a latitude bounding box before the haversine
 * calculation. The columns are nullable and metadata-only: no price, rate,
 * availability or date is ever stored here.
 *
 * PostGIS is NOT required. The repository uses a pure-SQL haversine over the
 * existing double-precision coordinates, so this migration is safe on the
 * stock `postgres:16` image `docker-compose.yml` provisions. Every statement
 * is idempotent, matching the existing P4 chain's convention.
 */
export class NearbyHotelMetadata1731000000012 implements MigrationInterface {
  name = 'NearbyHotelMetadata1731000000012';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE hotels
        ADD COLUMN IF NOT EXISTS rating double precision,
        ADD COLUMN IF NOT EXISTS "reviewCount" integer,
        ADD COLUMN IF NOT EXISTS "imageUrl" varchar(1024)
    `);

    // Bounding-box prefilter for radius searches. A plain btree composite
    // serves the latitude range; the exact haversine filter follows in SQL.
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS idx_hotels_coordinates
        ON hotels (latitude, longitude)
        WHERE "isDeleted" = false AND latitude IS NOT NULL AND longitude IS NOT NULL
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX IF EXISTS idx_hotels_coordinates`);
    await queryRunner.query(`
      ALTER TABLE hotels
        DROP COLUMN IF EXISTS "reviewCount",
        DROP COLUMN IF EXISTS rating,
        DROP COLUMN IF EXISTS "imageUrl"
    `);
  }
}
