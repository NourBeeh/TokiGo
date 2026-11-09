import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * P4-1 migration 6 — flight provider mutual exclusion.
 *
 * The admin requirement is "exactly one active flight provider is selected"
 * between `duffel-flight` and `nuitee-flight`. A partial unique index alone
 * cannot express that: it enforces AT MOST one, permits ZERO, and — worse —
 * it would simply fail on a database that already has both active.
 *
 * Resolution:
 *   1. `provider_selection` is a singleton selection record (PK + CHECK pin the
 *      key to 'flight'). ZERO rows = no provider selected (explicit, queryable,
 *      never a silent fallback). ONE row names the selected provider.
 *   2. The partial unique index on `providers` is the hard backstop that stops
 *      two real flight providers being active at once.
 *   3. The migration reconciles pre-existing rows to AT MOST one active real
 *      flight provider, keeping the currently effective one (lowest priority,
 *      then key) — it never promotes a fallback or a mock catalogue.
 *   4. The selection row is inserted ONLY when exactly one active real flight
 *      provider already exists. With zero active, the table stays empty and
 *      the system must report `provider_unavailable`.
 */
export class P4FlightProviderSelection1731000000006 implements MigrationInterface {
  name = 'P4FlightProviderSelection1731000000006';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS provider_selection (
        "selectionKey" varchar(255) NOT NULL,
        "providerKey" varchar(255) NOT NULL,
        "selectedAt" timestamptz NOT NULL DEFAULT now(),
        "selectedBy" varchar(255),
        "createdAt" timestamptz NOT NULL DEFAULT now(),
        "updatedAt" timestamptz NOT NULL DEFAULT now(),
        PRIMARY KEY ("selectionKey"),
        CONSTRAINT fk_provider_selection_provider
          FOREIGN KEY ("providerKey") REFERENCES providers ("providerKey"),
        CONSTRAINT chk_provider_selection_key CHECK ("selectionKey" = 'flight'),
        CONSTRAINT chk_provider_selection_real_flight
          CHECK ("providerKey" IN ('duffel-flight', 'nuitee-flight'))
      )
    `);

    // Reversible status backup. `originalIsActive` is the pre-migration state
    // (what down() restores); `migrationIsActive` is the EXACT state migration
    // 6 produces (what down() requires before it will restore anything).
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS p4_provider_status_backup (
        "providerKey" varchar(255) NOT NULL PRIMARY KEY,
        "originalIsActive" boolean NOT NULL,
        "migrationIsActive" boolean NOT NULL
      )
    `);
    await queryRunner.query(`
      INSERT INTO p4_provider_status_backup
        ("providerKey", "originalIsActive", "migrationIsActive")
      SELECT
        p."providerKey",
        p."isActive",
        (
          CASE
            -- Kept provider: migration 6 leaves it active.
            WHEN p.vertical = 'flight'
              AND p."isActive" = true
              AND p."providerKey" = (
                SELECT "providerKey"
                FROM providers
                WHERE vertical = 'flight'
                  AND "providerKey" IN ('duffel-flight', 'nuitee-flight')
                  AND "isActive" = true
                ORDER BY priority ASC, "providerKey" ASC
                LIMIT 1
              )
              THEN true
            -- Other active real flight providers: migration 6 disables them.
            WHEN p.vertical = 'flight' AND p."isActive" = true THEN false
            -- Untouched (already inactive, or not a flight row): stays as-is.
            ELSE p."isActive"
          END
        )
      FROM providers p
      WHERE p."providerKey" IN ('duffel-flight', 'nuitee-flight')
      ON CONFLICT ("providerKey") DO NOTHING
    `);

    // Reconcile to at most one active real flight provider. Keep the one that
    // is already effective (lowest priority, then key) and disable the rest.
    // This never promotes a fallback; it only removes a pre-existing violation.
    await queryRunner.query(`
      UPDATE providers
      SET "isActive" = false
      WHERE vertical = 'flight'
        AND "providerKey" IN ('duffel-flight', 'nuitee-flight')
        AND "isActive" = true
        AND "providerKey" NOT IN (
          SELECT "providerKey"
          FROM providers
          WHERE vertical = 'flight'
            AND "providerKey" IN ('duffel-flight', 'nuitee-flight')
            AND "isActive" = true
          ORDER BY priority ASC, "providerKey" ASC
          LIMIT 1
        )
    `);

    await queryRunner.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS uq_one_active_flight_provider
        ON providers (vertical)
        WHERE vertical = 'flight'
          AND "isActive" = true
          AND "providerKey" IN ('duffel-flight', 'nuitee-flight')
    `);

    // Select only what is already active. Zero active → zero rows → the
    // system detects "no provider selected" explicitly.
    await queryRunner.query(`
      INSERT INTO provider_selection ("selectionKey", "providerKey", "selectedBy")
      SELECT 'flight', "providerKey", 'p4-1-migration'
      FROM providers
      WHERE vertical = 'flight'
        AND "providerKey" IN ('duffel-flight', 'nuitee-flight')
        AND "isActive" = true
      ON CONFLICT ("selectionKey") DO NOTHING
    `);

    // A selection row must reference an active, real flight provider.
    await queryRunner.query(`
      CREATE OR REPLACE FUNCTION p4_validate_provider_selection()
      RETURNS trigger AS $$
      DECLARE
        v_providerKey varchar(255);
        v_vertical varchar(255);
        v_isActive boolean;
      BEGIN
        SELECT "providerKey", vertical, "isActive"
          INTO v_providerKey, v_vertical, v_isActive
          FROM providers WHERE "providerKey" = NEW."providerKey";
        IF NOT FOUND THEN
          RAISE EXCEPTION 'provider_selection: provider "%" does not exist', NEW."providerKey";
        END IF;
        IF v_vertical IS DISTINCT FROM 'flight' THEN
          RAISE EXCEPTION 'provider_selection: provider "%" is not a flight provider', NEW."providerKey";
        END IF;
        IF v_isActive IS DISTINCT FROM true THEN
          RAISE EXCEPTION 'provider_selection: provider "%" is not active', NEW."providerKey";
        END IF;
        IF v_providerKey NOT IN ('duffel-flight', 'nuitee-flight') THEN
          RAISE EXCEPTION 'provider_selection: provider "%" is not a selectable real flight provider', NEW."providerKey";
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql
    `);
    await queryRunner.query(`
      CREATE TRIGGER trg_provider_selection_validate
        BEFORE INSERT OR UPDATE ON provider_selection
        FOR EACH ROW EXECUTE FUNCTION p4_validate_provider_selection()
    `);

    // A selected provider's identity cannot be moved out from under the
    // selection. BEFORE UPDATE sees both OLD and NEW, so a statement that
    // changes several columns at once (or a transaction that tries to re-point
    // the selection first) cannot slip through: the row is protected when it
    // IS the selected provider (OLD key) OR would BECOME it (NEW key).
    // Unrelated columns are never blocked.
    await queryRunner.query(`
      CREATE OR REPLACE FUNCTION p4_protect_selected_provider()
      RETURNS trigger AS $$
      DECLARE
        v_protected boolean;
      BEGIN
        SELECT EXISTS (
          SELECT 1 FROM provider_selection
          WHERE "providerKey" IN (OLD."providerKey", NEW."providerKey")
        ) INTO v_protected;

        IF v_protected THEN
          IF NEW."providerKey" IS DISTINCT FROM OLD."providerKey" THEN
            RAISE EXCEPTION 'provider_selection: provider "%" is the selected flight provider (or the update would make it the selected one); its providerKey cannot be changed', OLD."providerKey";
          END IF;
          IF NEW.vertical IS DISTINCT FROM 'flight' THEN
            RAISE EXCEPTION 'provider_selection: provider "%" is the selected flight provider; its vertical cannot change away from flight', OLD."providerKey";
          END IF;
          IF NEW."isActive" IS DISTINCT FROM true THEN
            RAISE EXCEPTION 'provider_selection: provider "%" is the selected flight provider; it cannot be deactivated', OLD."providerKey";
          END IF;
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql
    `);
    await queryRunner.query(`
      CREATE TRIGGER trg_protect_selected_provider
        BEFORE UPDATE ON providers
        FOR EACH ROW EXECUTE FUNCTION p4_protect_selected_provider()
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    // Validate BEFORE any destructive operation. The whole down() runs inside
    // a transaction, so an abort leaves the triggers, index, backup table and
    // provider state exactly as they were. The backup alone does NOT prove the
    // current state is safe to restore — the live status must match the exact
    // post-migration state first.
    await queryRunner.query(`
      DO $$
      DECLARE
        v_missing text;
        v_mismatch text;
      BEGIN
        SELECT string_agg(b."providerKey", ', ' ORDER BY b."providerKey")
          INTO v_missing
          FROM p4_provider_status_backup b
          LEFT JOIN providers p ON p."providerKey" = b."providerKey"
         WHERE p."providerKey" IS NULL;
        IF v_missing IS NOT NULL THEN
          RAISE EXCEPTION 'provider_selection rollback aborted: required provider row(s) missing: %', v_missing;
        END IF;

        SELECT string_agg(b."providerKey", ', ' ORDER BY b."providerKey")
          INTO v_mismatch
          FROM p4_provider_status_backup b
          JOIN providers p ON p."providerKey" = b."providerKey"
         WHERE p."isActive" IS DISTINCT FROM b."migrationIsActive";
        IF v_mismatch IS NOT NULL THEN
          RAISE EXCEPTION 'provider_selection rollback aborted: provider status changed after migration 6 for: %; restore it manually or re-apply the migration instead of rolling back', v_mismatch;
        END IF;
      END
      $$;
    `);

    await queryRunner.query(`
      DROP TRIGGER IF EXISTS trg_protect_selected_provider ON providers
    `);
    await queryRunner.query(`
      DROP TRIGGER IF EXISTS trg_provider_selection_validate ON provider_selection
    `);
    await queryRunner.query(`
      DROP FUNCTION IF EXISTS p4_protect_selected_provider()
    `);
    await queryRunner.query(`
      DROP FUNCTION IF EXISTS p4_validate_provider_selection()
    `);
    await queryRunner.query(`
      DROP INDEX IF EXISTS uq_one_active_flight_provider
    `);
    // Restore exactly the provider status captured before the reconciliation.
    await queryRunner.query(`
      UPDATE providers p
      SET "isActive" = b."originalIsActive"
      FROM p4_provider_status_backup b
      WHERE p."providerKey" = b."providerKey"
    `);
    await queryRunner.query(`DROP TABLE IF EXISTS p4_provider_status_backup`);
    await queryRunner.query(`DROP TABLE IF EXISTS provider_selection`);
  }
}
