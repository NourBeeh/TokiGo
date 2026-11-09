import 'reflect-metadata';
import { join } from 'path';
import { DataSource } from 'typeorm';

import { Provider } from '../src/database/entities/provider.entity';
import { RegistrySyncService } from '../src/modules/providers/registry.sync.service';

jest.setTimeout(60_000);

/**
 * P4-1R — fresh DEVELOPMENT initialization.
 *
 * P4-1 originally declared the flight-provider partial unique index on the
 * `Provider` entity. Development runs `synchronize`, which created the index,
 * and `RegistrySyncService.seedDefaults` then failed when it seeded a second
 * active flight provider. The index is now migration-managed only, so
 * development initialization must work again.
 *
 * This test actually boots the schema through `synchronize: true` (the real
 * development path) and runs the real `seedDefaults`. It is skipped unless
 * P4_TEST_DB_URL is set, so `npm test` stays database-free.
 */
const TEST_DB_URL = process.env.P4_TEST_DB_URL;
const describeDb = TEST_DB_URL ? describe : describe.skip;

describeDb('P4-1R development initialization (synchronize + seedDefaults)', () => {
  let ds: DataSource;

  beforeAll(async () => {
    // Drop through a plain connection first — the synchronize DataSource has
    // nothing to connect to until the schema exists.
    const admin = new DataSource({ type: 'postgres', url: TEST_DB_URL });
    await admin.initialize();
    await admin.query('DROP SCHEMA IF EXISTS public CASCADE; CREATE SCHEMA public;');
    await admin.destroy();

    ds = new DataSource({
      type: 'postgres',
      url: TEST_DB_URL,
      entities: [join(__dirname, '..', 'src', '**', '*.entity.{ts,js}')],
      synchronize: true,
    });
    // Start from a genuinely empty database; synchronize builds the dev schema.
    await ds.initialize();
  });

  afterAll(async () => {
    if (ds?.isInitialized) await ds.destroy();
  });

  it('synchronizes the development schema and seeds every default provider', async () => {
    const sync = new RegistrySyncService(
      ds.getRepository(Provider),
      {
        setFlightProviders: () => undefined,
        setHotelProviders: () => undefined,
        setCarProviders: () => undefined,
      } as any,
      { get: () => undefined } as any,
    );

    // This threw a unique-violation before the entity index was removed.
    await expect(sync.seedDefaults()).resolves.toBeUndefined();

    const rows = await ds.getRepository(Provider).find();
    expect(rows).toHaveLength(RegistrySyncService.DEFAULTS.length);
  });

  it('does NOT create the flight-provider partial unique index during synchronize', async () => {
    const idx = await ds.query(
      `SELECT 1 FROM pg_indexes
       WHERE schemaname = 'public'
         AND indexname = 'uq_one_active_flight_provider'`,
    );
    expect(idx).toHaveLength(0);
  });

  it('still allows two active flight providers in the development schema', async () => {
    // seedDefaults already inserted duffel-flight + nuitee-flight + mock-flight
    // as ACTIVE flight providers — no premature unique constraint rejected the
    // second one. Development may seed both before an admin selects one;
    // production enforces the invariant through the migration.
    const rows = await ds.query(
      `SELECT COUNT(*)::int AS n FROM providers
       WHERE vertical = 'flight' AND "isActive" = true`,
    );
    expect(rows[0].n).toBe(3);
  });
});
