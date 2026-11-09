import 'reflect-metadata';
import { join } from 'path';
import { DataSource, QueryFailedError } from 'typeorm';

// Schema/migration work against a real database can exceed Jest's 5s default,
// especially when several suites rebuild the schema in one run.
jest.setTimeout(60_000);

/**
 * P4-1 durable schema + constraint tests.
 *
 * These run against a REAL PostgreSQL database — the constraint behaviour
 * (partial unique indexes, composite foreign keys, CHECK constraints) cannot
 * be proven by mocks. They are skipped unless P4_TEST_DB_URL is set, so the
 * normal `npm test` suite stays database-free.
 *
 * Run with:
 *   P4_TEST_DB_URL=postgres://postgres:postgres@127.0.0.1:5433/tokigo_p4_test \
 *     npx jest test/p4.schema.spec.ts
 */

const TEST_DB_URL = process.env.P4_TEST_DB_URL;
const describeDb = TEST_DB_URL ? describe : describe.skip;

/** Postgres error codes we assert on. */
const PG_UNIQUE = '23505';
const PG_FK = '23503';
const PG_CHECK = '23514';

function pgCode(error: unknown): string | undefined {
  const e = error as any;
  return e?.code ?? e?.driverError?.code ?? e?.cause?.code;
}

async function expectPgError(
  fn: () => Promise<unknown>,
  code: string,
  label: string,
): Promise<void> {
  try {
    await fn();
  } catch (error) {
    expect(pgCode(error)).toBe(code);
    return;
  }
  throw new Error(`Expected ${label} to be rejected with ${code}, but it succeeded.`);
}

async function insertBooking(
  ds: DataSource,
  overrides: Record<string, unknown> = {},
): Promise<string> {
  const row = {
    userId: 'user-1',
    offerId: 'offer-1',
    providerId: 'duffel-flight',
    providerName: 'Duffel Flights',
    type: 'flight',
    status: 'prepared',
    currency: 'USD',
    authoritativePrice: 100,
    ...overrides,
  };
  const result = await ds.query(
    `INSERT INTO bookings (
       "userId", "offerId", "providerId", "providerName", type, status,
       currency, "authoritativePrice"
     ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING id`,
    [
      row.userId,
      row.offerId,
      row.providerId,
      row.providerName,
      row.type,
      row.status,
      row.currency,
      row.authoritativePrice,
    ],
  );
  return result[0].id as string;
}

async function insertAttempt(
  ds: DataSource,
  overrides: Record<string, unknown> = {},
): Promise<string> {
  const row = {
    bookingId: 'booking-1',
    userId: 'user-1',
    attemptNo: 1,
    idempotencyKey: 'idem-1',
    amount: 100,
    currency: 'USD',
    status: 'succeeded',
    ...overrides,
  };
  const result = await ds.query(
    `INSERT INTO payment_attempts (
       "bookingId", "userId", "attemptNo", "idempotencyKey", amount, currency, status
     ) VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING id`,
    [
      row.bookingId,
      row.userId,
      row.attemptNo,
      row.idempotencyKey,
      row.amount,
      row.currency,
      row.status,
    ],
  );
  return result[0].id as string;
}

async function insertOperation(
  ds: DataSource,
  overrides: Record<string, unknown> = {},
): Promise<string> {
  const row = {
    bookingId: 'booking-1',
    providerId: 'duffel-flight',
    operation: 'create_booking',
    providerRef: 'ord_1',
    idempotencyKey: 'op-1',
    status: 'confirmed',
    ...overrides,
  };
  const result = await ds.query(
    `INSERT INTO provider_operations (
       "bookingId", "providerId", operation, "providerRef", "idempotencyKey", status
     ) VALUES ($1,$2,$3,$4,$5,$6) RETURNING id`,
    [
      row.bookingId,
      row.providerId,
      row.operation,
      row.providerRef,
      row.idempotencyKey,
      row.status,
    ],
  );
  return result[0].id as string;
}

async function insertTransaction(
  ds: DataSource,
  overrides: Record<string, unknown> = {},
): Promise<string> {
  const row = {
    bookingId: 'booking-1',
    attemptId: null,
    providerOperationId: null,
    leg: 'CUSTOMER',
    type: 'capture',
    status: 'succeeded',
    amount: 100,
    currency: 'USD',
    idempotencyKey: 'txn-1',
    ...overrides,
  };
  const result = await ds.query(
    `INSERT INTO payment_transactions (
       "bookingId", "attemptId", "providerOperationId", leg, type, status,
       amount, currency, "idempotencyKey"
     ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING id`,
    [
      row.bookingId,
      row.attemptId,
      row.providerOperationId,
      row.leg,
      row.type,
      row.status,
      row.amount,
      row.currency,
      row.idempotencyKey,
    ],
  );
  return result[0].id as string;
}

async function insertProvider(
  ds: DataSource,
  overrides: Record<string, unknown> = {},
): Promise<void> {
  const row = {
    providerKey: 'duffel-flight',
    name: 'Duffel Flights',
    vertical: 'flight',
    priority: 1,
    isFallback: false,
    isActive: true,
    ...overrides,
  };
  await ds.query(
    `INSERT INTO providers ("providerKey", name, vertical, priority, "isFallback", "isActive")
     VALUES ($1,$2,$3,$4,$5,$6)`,
    [
      row.providerKey,
      row.name,
      row.vertical,
      row.priority,
      row.isFallback,
      row.isActive,
    ],
  );
}

async function insertSelection(ds: DataSource, providerKey: string): Promise<void> {
  await ds.query(
    `INSERT INTO provider_selection ("selectionKey", "providerKey", "selectedBy")
     VALUES ('flight', $1, 'test')`,
    [providerKey],
  );
}

/** Rejection without a specific SQLSTATE — used for trigger-raised exceptions. */
async function expectRejected(fn: () => Promise<unknown>, label: string): Promise<void> {
  try {
    await fn();
  } catch {
    return;
  }
  throw new Error(`Expected ${label} to be rejected, but it succeeded.`);
}

async function tableExists(ds: DataSource, table: string): Promise<boolean> {
  const rows = await ds.query(
    `SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = $1`,
    [table],
  );
  return rows.length > 0;
}

describeDb('P4-1 durable payment schema (PostgreSQL)', () => {
  let ds: DataSource;

  beforeAll(async () => {
    ds = new DataSource({
      type: 'postgres',
      url: TEST_DB_URL,
      entities: [join(__dirname, '..', 'src', '**', '*.entity.{ts,js}')],
      migrations: [
        join(__dirname, '..', 'src', 'database', 'migrations', '*.{ts,js}'),
      ],
      migrationsTableName: 'migrations',
      synchronize: false,
    });
    await ds.initialize();
    // Start from a genuinely empty database, then apply migrations only.
    await ds.query('DROP SCHEMA IF EXISTS public CASCADE; CREATE SCHEMA public;');
    await ds.runMigrations();
  });

  afterAll(async () => {
    if (ds?.isInitialized) await ds.destroy();
  });

  beforeEach(async () => {
    await ds.query(
      `TRUNCATE bookings, payment_attempts, payment_transactions,
         provider_operations, webhook_events, provider_selection, providers
       RESTART IDENTITY CASCADE`,
    );
  });

  it('1. migrations apply on a clean database with synchronize:false', async () => {
    for (const table of [
      'bookings',
      'providers',
      'payment_attempts',
      'payment_transactions',
      'provider_operations',
      'webhook_events',
      'provider_selection',
      'migrations',
    ]) {
      expect(await tableExists(ds, table)).toBe(true);
    }
    const executed = await ds.query(
      `SELECT COUNT(*)::int AS n FROM migrations`,
    );
    // P4-1: 7 migrations. P4-2 adds 1731000000007 (attempt status states) and
    // 1731000000008 (retire the legacy webhook table).
    expect(executed[0].n).toBe(10);
  });

  it('1b. the migration (not the entity) creates the flight-provider exclusion index', async () => {
    const idx = await ds.query(
      `SELECT indexdef FROM pg_indexes
       WHERE schemaname = 'public' AND indexname = 'uq_one_active_flight_provider'`,
    );
    expect(idx).toHaveLength(1);
    expect(idx[0].indexdef).toContain('"isActive" = true');
    expect(idx[0].indexdef).toContain('duffel-flight');
    expect(idx[0].indexdef).toContain('nuitee-flight');
  });

  it('3. multiple payment attempts can belong to one booking', async () => {
    const bookingId = await insertBooking(ds);
    await insertAttempt(ds, { bookingId, attemptNo: 1, idempotencyKey: 'k-1' });
    await insertAttempt(ds, { bookingId, attemptNo: 2, idempotencyKey: 'k-2' });
    await insertAttempt(ds, {
      bookingId,
      attemptNo: 3,
      idempotencyKey: 'k-3',
      status: 'failed',
      failureCode: 'CARD_DECLINED',
    });
    const rows = await ds.query(
      `SELECT COUNT(*)::int AS n FROM payment_attempts WHERE "bookingId" = $1`,
      [bookingId],
    );
    expect(rows[0].n).toBe(3);
  });

  it('4. duplicate idempotency keys are rejected (per user, not per booking)', async () => {
    const bookingA = await insertBooking(ds, { offerId: 'offer-a' });
    const bookingB = await insertBooking(ds, { offerId: 'offer-b' });
    await insertAttempt(ds, { bookingId: bookingA, idempotencyKey: 'same-key' });
    // Same user, same key, DIFFERENT booking → still a violation.
    await expectPgError(
      () =>
        insertAttempt(ds, {
          bookingId: bookingB,
          idempotencyKey: 'same-key',
        }),
      PG_UNIQUE,
      'duplicate (userId, idempotencyKey)',
    );
    // A different user with the same key is fine — on a booking they own.
    const bookingC = await insertBooking(ds, {
      offerId: 'offer-c',
      userId: 'user-2',
    });
    await insertAttempt(ds, {
      bookingId: bookingC,
      userId: 'user-2',
      idempotencyKey: 'same-key',
    });
  });

  it('5. one payment attempt cannot be consumed by two bookings', async () => {
    const bookingA = await insertBooking(ds, { offerId: 'offer-a' });
    const bookingB = await insertBooking(ds, { offerId: 'offer-b' });
    const attemptId = await insertAttempt(ds, { bookingId: bookingA });

    await ds.query(
      `UPDATE bookings SET "paymentAttemptId" = $1 WHERE id = $2`,
      [attemptId, bookingA],
    );
    await expectPgError(
      () =>
        ds.query(
          `UPDATE bookings SET "paymentAttemptId" = $1 WHERE id = $2`,
          [attemptId, bookingB],
        ),
      PG_UNIQUE,
      'second booking consuming the same attempt',
    );
  });

  it('6. a booking stores exactly one consumed attempt (no second consumption)', async () => {
    const bookingId = await insertBooking(ds);
    const attemptA = await insertAttempt(ds, {
      bookingId,
      attemptNo: 1,
      idempotencyKey: 'a',
    });
    const attemptB = await insertAttempt(ds, {
      bookingId,
      attemptNo: 2,
      idempotencyKey: 'b',
    });

    await ds.query(
      `UPDATE bookings SET "paymentAttemptId" = $1 WHERE id = $2`,
      [attemptA, bookingId],
    );

    // The column is scalar: a booking row can never hold two attempts at once.
    const column = await ds.query(
      `SELECT data_type FROM information_schema.columns
       WHERE table_schema='public' AND table_name='bookings'
         AND column_name='paymentAttemptId'`,
    );
    expect(column).toHaveLength(1);
    expect(column[0].data_type).toBe('uuid');

    const row = await ds.query(
      `SELECT "paymentAttemptId" FROM bookings WHERE id = $1`,
      [bookingId],
    );
    expect(row[0].paymentAttemptId).toBe(attemptA);

    // Overwriting is a replacement, not a second consumption: exactly one
    // attempt remains consumed by this booking.
    await ds.query(
      `UPDATE bookings SET "paymentAttemptId" = $1 WHERE id = $2`,
      [attemptB, bookingId],
    );
    const after = await ds.query(
      `SELECT "paymentAttemptId" FROM bookings WHERE id = $1`,
      [bookingId],
    );
    expect(after[0].paymentAttemptId).toBe(attemptB);
    const consumedByA = await ds.query(
      `SELECT COUNT(*)::int AS n FROM bookings WHERE "paymentAttemptId" = $1`,
      [attemptA],
    );
    expect(consumedByA[0].n).toBe(0);
  });

  it('7a. cross-booking consumed attempt is rejected (composite FK)', async () => {
    const bookingA = await insertBooking(ds, { offerId: 'offer-a' });
    const bookingB = await insertBooking(ds, { offerId: 'offer-b' });
    const attemptId = await insertAttempt(ds, { bookingId: bookingA });

    await expectPgError(
      () =>
        ds.query(
          `UPDATE bookings SET "paymentAttemptId" = $1 WHERE id = $2`,
          [attemptId, bookingB],
        ),
      PG_FK,
      'cross-booking consumed attempt',
    );
  });

  it('7b. cross-user consumed attempt is rejected (composite FK)', async () => {
    const bookingA = await insertBooking(ds, { userId: 'user-1', offerId: 'offer-a' });
    const bookingB = await insertBooking(ds, { userId: 'user-2', offerId: 'offer-b' });
    // A legitimate attempt on user-2's own booking...
    const attemptId = await insertAttempt(ds, {
      bookingId: bookingB,
      userId: 'user-2',
    });
    // ...cannot be consumed by user-1's booking.
    await expectPgError(
      () =>
        ds.query(
          `UPDATE bookings SET "paymentAttemptId" = $1 WHERE id = $2`,
          [attemptId, bookingA],
        ),
      PG_FK,
      'cross-user consumed attempt',
    );
  });

  it('7c. cross-booking CUSTOMER transaction is rejected (composite FK)', async () => {
    const bookingA = await insertBooking(ds, { offerId: 'offer-a' });
    const bookingB = await insertBooking(ds, { offerId: 'offer-b' });
    const attemptId = await insertAttempt(ds, { bookingId: bookingA });

    await expectPgError(
      () =>
        insertTransaction(ds, {
          bookingId: bookingB,
          attemptId,
          leg: 'CUSTOMER',
          idempotencyKey: 'txn-cross',
        }),
      PG_FK,
      'cross-booking customer transaction',
    );
  });

  it('7d. cross-booking SUPPLIER transaction is rejected (composite FK)', async () => {
    const bookingA = await insertBooking(ds, { offerId: 'offer-a' });
    const bookingB = await insertBooking(ds, { offerId: 'offer-b' });
    const operationId = await insertOperation(ds, { bookingId: bookingA });

    await expectPgError(
      () =>
        insertTransaction(ds, {
          bookingId: bookingB,
          providerOperationId: operationId,
          leg: 'SUPPLIER',
          type: 'capture',
          idempotencyKey: 'txn-cross-supplier',
        }),
      PG_FK,
      'cross-booking supplier transaction',
    );
  });

  it('2a. an attempt can be created for the booking owner', async () => {
    const bookingId = await insertBooking(ds, { userId: 'owner-1' });
    await insertAttempt(ds, {
      bookingId,
      userId: 'owner-1',
      idempotencyKey: 'own-1',
    });
    const rows = await ds.query(
      `SELECT COUNT(*)::int AS n FROM payment_attempts WHERE "bookingId" = $1 AND "userId" = $2`,
      [bookingId, 'owner-1'],
    );
    expect(rows[0].n).toBe(1);
  });

  it('2b. an attempt for another user\'s booking is rejected (ownership FK)', async () => {
    const bookingId = await insertBooking(ds, { userId: 'owner-1' });
    await expectPgError(
      () =>
        insertAttempt(ds, {
          bookingId,
          userId: 'attacker-2',
          idempotencyKey: 'own-2',
        }),
      PG_FK,
      'attempt with a different userId',
    );
  });

  it('2c. a CUSTOMER transaction cannot reference another user\'s attempt', async () => {
    const bookingA = await insertBooking(ds, { userId: 'owner-1', offerId: 'offer-a' });
    const bookingB = await insertBooking(ds, { userId: 'owner-2', offerId: 'offer-b' });
    const attemptId = await insertAttempt(ds, {
      bookingId: bookingA,
      userId: 'owner-1',
    });
    await expectPgError(
      () =>
        insertTransaction(ds, {
          bookingId: bookingB,
          attemptId,
          leg: 'CUSTOMER',
          idempotencyKey: 'txn-ownership',
        }),
      PG_FK,
      'customer transaction referencing another user\'s attempt',
    );
  });

  it('2d. multiple attempts for the same booking and owner are preserved', async () => {
    const bookingId = await insertBooking(ds, { userId: 'owner-1' });
    await insertAttempt(ds, {
      bookingId,
      userId: 'owner-1',
      attemptNo: 1,
      idempotencyKey: 'multi-1',
    });
    await insertAttempt(ds, {
      bookingId,
      userId: 'owner-1',
      attemptNo: 2,
      idempotencyKey: 'multi-2',
      status: 'failed',
      failureCode: 'CARD_DECLINED',
    });
    const rows = await ds.query(
      `SELECT COUNT(*)::int AS n FROM payment_attempts
       WHERE "bookingId" = $1 AND "userId" = $2`,
      [bookingId, 'owner-1'],
    );
    expect(rows[0].n).toBe(2);
  });

  it('3a. selecting Duffel succeeds', async () => {
    await insertProvider(ds, { providerKey: 'duffel-flight', name: 'Duffel Flights' });
    await insertSelection(ds, 'duffel-flight');
    const rows = await ds.query(
      `SELECT "providerKey" FROM provider_selection WHERE "selectionKey" = 'flight'`,
    );
    expect(rows).toHaveLength(1);
    expect(rows[0].providerKey).toBe('duffel-flight');
  });

  it('3b. selecting Nuitee succeeds', async () => {
    await insertProvider(ds, {
      providerKey: 'nuitee-flight',
      name: 'Nuitee Flights',
      priority: 2,
      isFallback: true,
    });
    await insertSelection(ds, 'nuitee-flight');
    const rows = await ds.query(
      `SELECT "providerKey" FROM provider_selection WHERE "selectionKey" = 'flight'`,
    );
    expect(rows).toHaveLength(1);
    expect(rows[0].providerKey).toBe('nuitee-flight');
  });

  it('3c. rejecting mock-flight as a selection', async () => {
    await insertProvider(ds, {
      providerKey: 'mock-flight',
      name: 'Mock Flights',
      priority: 3,
      isFallback: true,
    });
    await expectRejected(
      () => insertSelection(ds, 'mock-flight'),
      'mock-flight selection',
    );
  });

  it('3d. rejecting an inactive provider as a selection', async () => {
    await insertProvider(ds, {
      providerKey: 'duffel-flight',
      name: 'Duffel Flights',
      isActive: false,
    });
    await expectRejected(
      () => insertSelection(ds, 'duffel-flight'),
      'inactive provider selection',
    );
  });

  it('3e. rejecting a non-flight provider as a selection', async () => {
    await insertProvider(ds, {
      providerKey: 'nuitee',
      name: 'Nuitee Hotels',
      vertical: 'hotel',
    });
    await expectRejected(
      () => insertSelection(ds, 'nuitee'),
      'non-flight provider selection',
    );
  });

  it('3f. the selected provider cannot be silently deactivated', async () => {
    await insertProvider(ds, { providerKey: 'duffel-flight', name: 'Duffel Flights' });
    await insertSelection(ds, 'duffel-flight');
    await expectRejected(
      () =>
        ds.query(
          `UPDATE providers SET "isActive" = false WHERE "providerKey" = 'duffel-flight'`,
        ),
      'deactivating the selected provider',
    );
    // Clearing the selection first makes the deactivation legal again.
    await ds.query(`DELETE FROM provider_selection WHERE "selectionKey" = 'flight'`);
    await ds.query(
      `UPDATE providers SET "isActive" = false WHERE "providerKey" = 'duffel-flight'`,
    );
  });

  it('3g. changing the selected provider vertical away from flight is rejected', async () => {
    await insertProvider(ds, { providerKey: 'duffel-flight', name: 'Duffel Flights' });
    await insertSelection(ds, 'duffel-flight');
    await expectRejected(
      () =>
        ds.query(
          `UPDATE providers SET vertical = 'hotel' WHERE "providerKey" = 'duffel-flight'`,
        ),
      'vertical change on the selected provider',
    );
    const rows = await ds.query(
      `SELECT vertical FROM providers WHERE "providerKey" = 'duffel-flight'`,
    );
    expect(rows[0].vertical).toBe('flight');
  });

  it('3h. changing the selected provider providerKey is rejected', async () => {
    await insertProvider(ds, { providerKey: 'duffel-flight', name: 'Duffel Flights' });
    await insertSelection(ds, 'duffel-flight');
    await expectRejected(
      () =>
        ds.query(
          `UPDATE providers SET "providerKey" = 'duffel-flight-renamed' WHERE "providerKey" = 'duffel-flight'`,
        ),
      'providerKey change on the selected provider',
    );
    const rows = await ds.query(
      `SELECT COUNT(*)::int AS n FROM providers WHERE "providerKey" = 'duffel-flight'`,
    );
    expect(rows[0].n).toBe(1);
  });

  it('3i. a multi-column update touching protected fields is rejected', async () => {
    await insertProvider(ds, { providerKey: 'duffel-flight', name: 'Duffel Flights' });
    await insertSelection(ds, 'duffel-flight');
    await expectRejected(
      () =>
        ds.query(
          `UPDATE providers
           SET vertical = 'hotel', "isActive" = false, name = 'Renamed'
           WHERE "providerKey" = 'duffel-flight'`,
        ),
      'multi-column update on the selected provider',
    );
  });

  it('3j. updating unrelated fields on the selected provider is allowed', async () => {
    await insertProvider(ds, { providerKey: 'duffel-flight', name: 'Duffel Flights' });
    await insertSelection(ds, 'duffel-flight');
    await ds.query(
      `UPDATE providers
       SET name = 'Duffel Flights Renamed', priority = 9, "healthStatus" = 'healthy'
       WHERE "providerKey" = 'duffel-flight'`,
    );
    const rows = await ds.query(
      `SELECT name, priority, "healthStatus" FROM providers WHERE "providerKey" = 'duffel-flight'`,
    );
    expect(rows[0]).toMatchObject({
      name: 'Duffel Flights Renamed',
      priority: 9,
      healthStatus: 'healthy',
    });
  });

  it('3k. after clearing the selection, protected changes are allowed', async () => {
    await insertProvider(ds, { providerKey: 'duffel-flight', name: 'Duffel Flights' });
    await insertSelection(ds, 'duffel-flight');
    await ds.query(`DELETE FROM provider_selection WHERE "selectionKey" = 'flight'`);

    // No longer selected: vertical, key and active state may change.
    await ds.query(
      `UPDATE providers SET vertical = 'hotel' WHERE "providerKey" = 'duffel-flight'`,
    );
    await ds.query(
      `UPDATE providers SET "providerKey" = 'duffel-hotel' WHERE "providerKey" = 'duffel-flight'`,
    );
    await ds.query(
      `UPDATE providers SET "isActive" = false WHERE "providerKey" = 'duffel-hotel'`,
    );
    const rows = await ds.query(
      `SELECT "providerKey", vertical, "isActive" FROM providers WHERE "providerKey" = 'duffel-hotel'`,
    );
    expect(rows).toHaveLength(1);
    expect(rows[0].vertical).toBe('hotel');
    expect(rows[0].isActive).toBe(false);
  });

  it('8. two active flight providers cannot coexist', async () => {
    await ds.query(
      `INSERT INTO providers ("providerKey", name, vertical, priority, "isFallback", "isActive")
       VALUES ('duffel-flight', 'Duffel Flights', 'flight', 1, false, true)`,
    );
    await expectPgError(
      () =>
        ds.query(
          `INSERT INTO providers ("providerKey", name, vertical, priority, "isFallback", "isActive")
           VALUES ('nuitee-flight', 'Nuitee Flights', 'flight', 2, true, true)`,
        ),
      PG_UNIQUE,
      'second active real flight provider',
    );
    // The same provider key may exist inactive, and a fallback flight provider
    // is outside the invariant.
    await ds.query(
      `INSERT INTO providers ("providerKey", name, vertical, priority, "isFallback", "isActive")
       VALUES ('mock-flight', 'Mock Flights', 'flight', 3, true, true)`,
    );
  });

  it('9. zero active flight providers is detected explicitly', async () => {
    await ds.query(
      `INSERT INTO providers ("providerKey", name, vertical, priority, "isFallback", "isActive")
       VALUES ('duffel-flight', 'Duffel Flights', 'flight', 1, false, false),
              ('nuitee-flight', 'Nuitee Flights', 'flight', 2, true, false)`,
    );
    // The detection query used by the selection service: no row → no provider.
    const selected = await ds.query(
      `SELECT "providerKey" FROM provider_selection WHERE "selectionKey" = 'flight'`,
    );
    expect(selected).toHaveLength(0);
    const active = await ds.query(
      `SELECT "providerKey" FROM providers
       WHERE vertical = 'flight' AND "isActive" = true
         AND "providerKey" IN ('duffel-flight', 'nuitee-flight')`,
    );
    expect(active).toHaveLength(0);
  });

  it('10. supplier transactions can exist without a customer attempt', async () => {
    const bookingId = await insertBooking(ds);
    const operationId = await insertOperation(ds, { bookingId });
    await insertTransaction(ds, {
      bookingId,
      providerOperationId: operationId,
      leg: 'SUPPLIER',
      type: 'capture',
      amount: 90,
      currency: 'USD',
      idempotencyKey: 'supplier-1',
    });
    const rows = await ds.query(
      `SELECT leg, "attemptId", "providerOperationId" FROM payment_transactions
       WHERE "idempotencyKey" = 'supplier-1'`,
    );
    expect(rows).toHaveLength(1);
    expect(rows[0].leg).toBe('SUPPLIER');
    expect(rows[0].attemptId).toBeNull();
    expect(rows[0].providerOperationId).toBe(operationId);
  });

  it('11a. customer transactions require a matching attempt (CHECK)', async () => {
    const bookingId = await insertBooking(ds);
    await expectPgError(
      () =>
        insertTransaction(ds, {
          bookingId,
          leg: 'CUSTOMER',
          attemptId: null,
          idempotencyKey: 'customer-no-attempt',
        }),
      PG_CHECK,
      'customer transaction without an attempt',
    );
  });

  it('11b. a supplier transaction cannot be tied to a customer attempt (CHECK)', async () => {
    const bookingId = await insertBooking(ds);
    const operationId = await insertOperation(ds, { bookingId });
    const attemptId = await insertAttempt(ds, { bookingId });
    await expectPgError(
      () =>
        insertTransaction(ds, {
          bookingId,
          leg: 'SUPPLIER',
          attemptId,
          providerOperationId: operationId,
          idempotencyKey: 'supplier-with-attempt',
        }),
      PG_CHECK,
      'supplier transaction carrying a customer attempt',
    );
  });

  it('11c. duplicate transaction idempotency keys are rejected', async () => {
    const bookingId = await insertBooking(ds);
    const attemptId = await insertAttempt(ds, { bookingId });
    await insertTransaction(ds, {
      bookingId,
      attemptId,
      leg: 'CUSTOMER',
      idempotencyKey: 'dup-txn',
    });
    await expectPgError(
      () =>
        insertTransaction(ds, {
          bookingId,
          attemptId,
          leg: 'CUSTOMER',
          idempotencyKey: 'dup-txn',
        }),
      PG_UNIQUE,
      'duplicate transaction idempotency key',
    );
  });

  it('12. migration rollback removes the P4 tables (and re-apply restores them)', async () => {
    // Revert the whole chain, one migration at a time (9 as of P4-2).
    for (let i = 0; i < 10; i++) {
      await ds.undoLastMigration();
    }
    for (const table of [
      'payment_attempts',
      'payment_transactions',
      'provider_operations',
      'webhook_events',
      'provider_selection',
    ]) {
      expect(await tableExists(ds, table)).toBe(false);
    }
    // Re-apply and confirm the schema is back.
    await ds.runMigrations();
    for (const table of [
      'payment_attempts',
      'payment_transactions',
      'provider_operations',
      'webhook_events',
      'provider_selection',
    ]) {
      expect(await tableExists(ds, table)).toBe(true);
    }
  });
});

describeDb('P4-1 backfill of pre-existing bookings (PostgreSQL)', () => {
  let ds: DataSource;

  beforeAll(async () => {
    ds = new DataSource({
      type: 'postgres',
      url: TEST_DB_URL,
      entities: [join(__dirname, '..', 'src', '**', '*.entity.{ts,js}')],
      migrations: [
        join(__dirname, '..', 'src', 'database', 'migrations', '*.{ts,js}'),
      ],
      migrationsTableName: 'migrations',
      synchronize: false,
    });
    await ds.initialize();
  });

  afterAll(async () => {
    if (ds?.isInitialized) await ds.destroy();
  });

  it('2. existing bookings are backfilled as legacy/unverified, never paid', async () => {
    // Rebuild a database that looks like the pre-P4-1 production schema.
    await ds.query('DROP SCHEMA IF EXISTS public CASCADE; CREATE SCHEMA public;');
    await ds.query(`
      CREATE TABLE bookings (
        id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
        "userId" varchar(255) NOT NULL,
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
    await ds.query(`
      INSERT INTO bookings ("userId", "offerId", "providerId", "providerName", type, status)
      VALUES ('legacy-user', 'legacy-offer', 'duffel-flight', 'Duffel Flights', 'flight', 'confirmed')
    `);

    // Apply the P4-1 chain on top of the legacy schema.
    await ds.runMigrations();

    const rows = await ds.query(
      `SELECT "paymentStatus", "legacyUnverified", "paymentAttemptId"
       FROM bookings WHERE "userId" = 'legacy-user'`,
    );
    expect(rows).toHaveLength(1);
    expect(rows[0].paymentStatus).toBe('legacy_unverified');
    expect(rows[0].legacyUnverified).toBe(true);
    expect(rows[0].paymentAttemptId).toBeNull();

    // No fake payment evidence was created.
    const attempts = await ds.query(`SELECT COUNT(*)::int AS n FROM payment_attempts`);
    const txns = await ds.query(`SELECT COUNT(*)::int AS n FROM payment_transactions`);
    expect(attempts[0].n).toBe(0);
    expect(txns[0].n).toBe(0);
  });
});

describeDb('P4-1R migration 6 rollback safety (PostgreSQL)', () => {
  let ds: DataSource;
  const MIGRATION_6 = 'P4FlightProviderSelection1731000000006';

  beforeAll(async () => {
    ds = new DataSource({
      type: 'postgres',
      url: TEST_DB_URL,
      entities: [join(__dirname, '..', 'src', '**', '*.entity.{ts,js}')],
      migrations: [
        join(__dirname, '..', 'src', 'database', 'migrations', '*.{ts,js}'),
      ],
      migrationsTableName: 'migrations',
      synchronize: false,
    });
    await ds.initialize();
    await ds.query('DROP SCHEMA IF EXISTS public CASCADE; CREATE SCHEMA public;');
    await ds.runMigrations();
  });

  afterAll(async () => {
    if (ds?.isInitialized) await ds.destroy();
  });

  async function migration6Applied(): Promise<boolean> {
    const rows = await ds.query(`SELECT 1 FROM migrations WHERE name = $1`, [
      MIGRATION_6,
    ]);
    return rows.length > 0;
  }

  /** Return to the pre-migration-6 state with an empty providers table. */
  async function resetToPreMigration6(): Promise<void> {
    // Full reset: some tests deliberately leave a provider status changed, and
    // migration 6 now (correctly) refuses to roll back over it. Rebuilding the
    // schema is the only state-independent way to get back to a known point.
    await ds.query('DROP SCHEMA IF EXISTS public CASCADE; CREATE SCHEMA public;');
    await ds.runMigrations();
    // P4-2/P4-2R added migrations 7, 8 and 9 after 6, so four reverts are
    // needed to reach the pre-migration-6 state.
    for (let i = 0; i < 4; i++) {
      await ds.undoLastMigration();
    }
    await ds.query(`TRUNCATE providers CASCADE`);
  }

  /**
   * Revert migration 6 specifically. P4-2/P4-2R appended migrations 7, 8
   * and 9 after it, so `undoLastMigration()` alone would revert migration 9
   * instead.
   */
  async function revertMigration6(): Promise<void> {
    for (let i = 0; i < 4; i++) {
      await ds.undoLastMigration();
    }
  }

  async function seedTwoActiveFlightProviders(): Promise<void> {
    await ds.query(`
      INSERT INTO providers ("providerKey", name, vertical, priority, "isFallback", "isActive")
      VALUES ('duffel-flight', 'Duffel Flights', 'flight', 1, false, true),
             ('nuitee-flight', 'Nuitee Flights', 'flight', 2, true, true)
    `);
  }

  it('4a. up with one active provider selects it', async () => {
    await resetToPreMigration6();
    await ds.query(`
      INSERT INTO providers ("providerKey", name, vertical, priority, "isFallback", "isActive")
      VALUES ('duffel-flight', 'Duffel Flights', 'flight', 1, false, true)
    `);

    await ds.runMigrations();

    const selection = await ds.query(
      `SELECT "providerKey" FROM provider_selection WHERE "selectionKey" = 'flight'`,
    );
    expect(selection).toHaveLength(1);
    expect(selection[0].providerKey).toBe('duffel-flight');
    const provider = await ds.query(
      `SELECT "isActive" FROM providers WHERE "providerKey" = 'duffel-flight'`,
    );
    expect(provider[0].isActive).toBe(true);
  });

  it('4b. up with two active real flight providers keeps one and disables the other', async () => {
    await resetToPreMigration6();
    await seedTwoActiveFlightProviders();

    await ds.runMigrations();

    const selection = await ds.query(
      `SELECT "providerKey" FROM provider_selection WHERE "selectionKey" = 'flight'`,
    );
    expect(selection).toHaveLength(1);
    expect(selection[0].providerKey).toBe('duffel-flight');
    const statuses = await ds.query(
      `SELECT "providerKey", "isActive" FROM providers ORDER BY "providerKey"`,
    );
    expect(statuses).toEqual([
      { providerKey: 'duffel-flight', isActive: true },
      { providerKey: 'nuitee-flight', isActive: false },
    ]);
  });

  it('4c. down restores the original provider configuration', async () => {
    await resetToPreMigration6();
    await seedTwoActiveFlightProviders();
    await ds.runMigrations();

    // Sanity: the reconciliation disabled one provider.
    const during = await ds.query(
      `SELECT "isActive" FROM providers WHERE "providerKey" = 'nuitee-flight'`,
    );
    expect(during[0].isActive).toBe(false);

    await revertMigration6();

    const statuses = await ds.query(
      `SELECT "providerKey", "isActive" FROM providers ORDER BY "providerKey"`,
    );
    expect(statuses).toEqual([
      { providerKey: 'duffel-flight', isActive: true },
      { providerKey: 'nuitee-flight', isActive: true },
    ]);
    expect(await tableExists(ds, 'p4_provider_status_backup')).toBe(false);
    expect(await tableExists(ds, 'provider_selection')).toBe(false);
  });

  it('4d. migration re-run is deterministic', async () => {
    await resetToPreMigration6();
    await seedTwoActiveFlightProviders();
    await ds.runMigrations();
    const first = await ds.query(
      `SELECT "providerKey", "isActive" FROM providers ORDER BY "providerKey"`,
    );

    await revertMigration6();
    await ds.runMigrations();
    const second = await ds.query(
      `SELECT "providerKey", "isActive" FROM providers ORDER BY "providerKey"`,
    );

    expect(second).toEqual(first);
    expect(second).toEqual([
      { providerKey: 'duffel-flight', isActive: true },
      { providerKey: 'nuitee-flight', isActive: false },
    ]);
  });

  it('4e. rollback restores a single originally-active provider', async () => {
    await resetToPreMigration6();
    await ds.query(`
      INSERT INTO providers ("providerKey", name, vertical, priority, "isFallback", "isActive")
      VALUES ('duffel-flight', 'Duffel Flights', 'flight', 1, false, true),
             ('nuitee-flight', 'Nuitee Flights', 'flight', 2, true, false)
    `);
    await ds.runMigrations();

    const selection = await ds.query(
      `SELECT "providerKey" FROM provider_selection WHERE "selectionKey" = 'flight'`,
    );
    expect(selection[0].providerKey).toBe('duffel-flight');

    await revertMigration6();

    const statuses = await ds.query(
      `SELECT "providerKey", "isActive" FROM providers ORDER BY "providerKey"`,
    );
    expect(statuses).toEqual([
      { providerKey: 'duffel-flight', isActive: true },
      { providerKey: 'nuitee-flight', isActive: false },
    ]);
  });

  it('4f. a status changed after migration 6 aborts rollback without overwriting', async () => {
    await resetToPreMigration6();
    await seedTwoActiveFlightProviders();
    await ds.runMigrations();

    // Simulate a legitimate post-migration admin change: clear the selection,
    // deactivate the selected provider, activate the other.
    await ds.query(`DELETE FROM provider_selection WHERE "selectionKey" = 'flight'`);
    await ds.query(
      `UPDATE providers SET "isActive" = false WHERE "providerKey" = 'duffel-flight'`,
    );
    await ds.query(
      `UPDATE providers SET "isActive" = true WHERE "providerKey" = 'nuitee-flight'`,
    );
    const before = await ds.query(
      `SELECT "providerKey", "isActive" FROM providers ORDER BY "providerKey"`,
    );

    await expectRejected(
      () => revertMigration6(),
      'rollback after a post-migration status change',
    );

    const after = await ds.query(
      `SELECT "providerKey", "isActive" FROM providers ORDER BY "providerKey"`,
    );
    expect(after).toEqual(before);
  });

  it('4g. a missing required provider row aborts rollback safely', async () => {
    await resetToPreMigration6();
    await seedTwoActiveFlightProviders();
    await ds.runMigrations();

    // nuitee-flight is inactive and not selected, so it can be deleted.
    await ds.query(`DELETE FROM providers WHERE "providerKey" = 'nuitee-flight'`);

    await expectRejected(
      () => revertMigration6(),
      'rollback with a missing provider row',
    );
  });

  it('4h. a failed rollback leaves migration-6 objects and backup data intact', async () => {
    await resetToPreMigration6();
    await seedTwoActiveFlightProviders();
    await ds.runMigrations();
    await ds.query(`DELETE FROM provider_selection WHERE "selectionKey" = 'flight'`);
    await ds.query(
      `UPDATE providers SET "isActive" = false WHERE "providerKey" = 'duffel-flight'`,
    );
    await ds.query(
      `UPDATE providers SET "isActive" = true WHERE "providerKey" = 'nuitee-flight'`,
    );

    await expectRejected(() => revertMigration6(), 'rollback');

    // The migration is still recorded as applied and nothing was torn down.
    expect(await migration6Applied()).toBe(true);
    expect(await tableExists(ds, 'p4_provider_status_backup')).toBe(true);
    expect(await tableExists(ds, 'provider_selection')).toBe(true);
    const trigger = await ds.query(
      `SELECT 1 FROM pg_trigger WHERE tgname = 'trg_protect_selected_provider'`,
    );
    expect(trigger).toHaveLength(1);
    const idx = await ds.query(
      `SELECT 1 FROM pg_indexes WHERE indexname = 'uq_one_active_flight_provider'`,
    );
    expect(idx).toHaveLength(1);
    const backup = await ds.query(
      `SELECT COUNT(*)::int AS n FROM p4_provider_status_backup`,
    );
    expect(backup[0].n).toBe(2);
  });

  it('4i. successful rollback followed by reapplication is deterministic', async () => {
    await resetToPreMigration6();
    await seedTwoActiveFlightProviders();
    await ds.runMigrations();
    const applied = await ds.query(
      `SELECT "providerKey", "isActive" FROM providers ORDER BY "providerKey"`,
    );

    await revertMigration6();
    const restored = await ds.query(
      `SELECT "providerKey", "isActive" FROM providers ORDER BY "providerKey"`,
    );
    expect(restored).toEqual([
      { providerKey: 'duffel-flight', isActive: true },
      { providerKey: 'nuitee-flight', isActive: true },
    ]);

    await ds.runMigrations();
    const reapplied = await ds.query(
      `SELECT "providerKey", "isActive" FROM providers ORDER BY "providerKey"`,
    );
    expect(reapplied).toEqual(applied);
  });
});
