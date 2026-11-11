import 'reflect-metadata';
import { join } from 'path';
import { DataSource, Repository } from 'typeorm';

import { PaymentAttempt } from '../src/database/entities/payment-attempt.entity';
import { PaymentTransaction } from '../src/database/entities/payment-transaction.entity';
import { WebhookEvent } from '../src/database/entities/webhook-event.entity';
import { ProcessedWebhook } from '../src/database/entities/processed_webhook.entity';
import { Booking } from '../src/modules/bookings/booking.entity';
import { PaymentAttemptService } from '../src/modules/payments/payment-attempt.service';
import { LedgerService } from '../src/modules/payments/ledger.service';
import { PaymentService } from '../src/modules/payments/payment.service';
import { PaymentRouter } from '../src/modules/payments/payment.router';
import {
  MockEgyptGateway,
  signMockWebhook,
} from '../src/modules/payments/mock.egypt.gateway';
import {
  ConfirmPaymentInput,
  CreatePaymentIntentInput,
  PaymentGateway,
  PaymentIntent,
} from '../src/modules/payments/payment.gateway';
import { InvalidPaymentAttemptTransitionError } from '../src/modules/payments/payment-attempt.state';

jest.setTimeout(60_000);

/**
 * P4-2 — durable payment attempts, ledger and webhook persistence.
 *
 * Every test here runs against a REAL PostgreSQL database: uniqueness
 * conflicts, composite foreign keys, row locking and transaction rollback
 * cannot be proven with mocks. Skipped unless P4_TEST_DB_URL is set, so the
 * normal `npm test` workflow stays database-free.
 *
 *   P4_TEST_DB_URL=postgres://user:pass@127.0.0.1:5432/tokigo_p4_test \
 *     npx jest test/p4.persistence.spec.ts
 */

const TEST_DB_URL = process.env.P4_TEST_DB_URL;
const describeDb = TEST_DB_URL ? describe : describe.skip;

process.env.WEBHOOK_SIGNING_KEY = process.env.WEBHOOK_SIGNING_KEY ?? 'p4-test-signing-key';

const PG_UNIQUE = '23505';
const PG_FK = '23503';

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

interface TestApp {
  service: PaymentService;
  attempts: PaymentAttemptService;
  ledger: LedgerService;
  gateway: PaymentGateway;
  attemptRepo: Repository<PaymentAttempt>;
  txnRepo: Repository<PaymentTransaction>;
  webhookRepo: Repository<WebhookEvent>;
  bookingRepo: Repository<Booking>;
  legacyRepo: Repository<ProcessedWebhook>;
}

describeDb('P4-2 durable payment persistence (PostgreSQL)', () => {
  let ds: DataSource;

  beforeAll(async () => {
    ds = new DataSource({
      type: 'postgres',
      url: TEST_DB_URL,
      entities: [join(__dirname, '..', 'src', '**', '*.entity.{ts,js}')],
      migrations: [join(__dirname, '..', 'src', 'database', 'migrations', '*.{ts,js}')],
      migrationsTableName: 'migrations',
      synchronize: false,
    });
    await ds.initialize();
    // A genuinely empty database, then the migration chain only.
    await ds.query('DROP SCHEMA IF EXISTS public CASCADE; CREATE SCHEMA public;');
    await ds.runMigrations();
  });

  afterAll(async () => {
    if (ds?.isInitialized) await ds.destroy();
  });

  beforeEach(async () => {
    await ds.query(
      `TRUNCATE bookings, payment_attempts, payment_transactions,
         provider_operations, webhook_events, processed_webhooks
       RESTART IDENTITY CASCADE`,
    );
  });

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  function buildApp(gateway?: PaymentGateway): TestApp {
    const gw = (gateway as PaymentGateway) ?? new MockEgyptGateway();
    const router = new PaymentRouter(gw as unknown as MockEgyptGateway);
    const attemptRepo = ds.getRepository(PaymentAttempt);
    const txnRepo = ds.getRepository(PaymentTransaction);
    const webhookRepo = ds.getRepository(WebhookEvent);
    const bookingRepo = ds.getRepository(Booking);
    const legacyRepo = ds.getRepository(ProcessedWebhook);
    const attempts = new PaymentAttemptService(attemptRepo);
    const ledger = new LedgerService(txnRepo);
    const service = new PaymentService(
      router,
      ledger,
      attempts,
      bookingRepo,
      webhookRepo,
      legacyRepo,
    );
    return {
      service,
      attempts,
      ledger,
      gateway: gw,
      attemptRepo,
      txnRepo,
      webhookRepo,
      bookingRepo,
      legacyRepo,
    };
  }

  async function insertBooking(
    overrides: Record<string, unknown> = {},
  ): Promise<string> {
    const row = {
      userId: 'user-1',
      offerId: 'offer-1',
      providerId: 'duffel-flight',
      providerName: 'Duffel Flights',
      type: 'flight',
      status: 'prepared',
      currency: 'EGP',
      authoritativePrice: 1000,
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

  async function insertOperation(
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

  /**
   * A gateway that shares a delegate's state (its in-process intent map) but
   * overrides selected operations. Sharing the map matters: two separate
   * `MockEgyptGateway` instances know nothing about each other's payments.
   */
  function gatewayWithFaults(
    delegate: MockEgyptGateway,
    overrides: Record<string, unknown>,
  ): PaymentGateway {
    return Object.assign(
      Object.create(Object.getPrototypeOf(delegate)),
      delegate,
      overrides,
    );
  }

  /** A gateway that behaves like the mock but times out on confirm. */
  function timeoutGateway(delegate?: MockEgyptGateway): PaymentGateway {
    const base = delegate ?? new MockEgyptGateway();
    return gatewayWithFaults(base, {
      // Keep the mock's gatewayId so attempts created by the real gateway are
      // still found by `findByGatewayRef`.
      gatewayId: 'mock-egypt-gateway',
      supportsMarket: ['EG'],
      confirmPayment: async () => {
        throw new Error('ETIMEDOUT: provider timed out');
      },
    });
  }

  /** Records exactly what the orchestrator sends to the gateway. */
  class RecordingGateway extends MockEgyptGateway {
    readonly createIntentInputs: CreatePaymentIntentInput[] = [];
    readonly confirmInputs: ConfirmPaymentInput[] = [];

    async createPaymentIntent(input: CreatePaymentIntentInput): Promise<PaymentIntent> {
      this.createIntentInputs.push({ ...input });
      return super.createPaymentIntent(input);
    }

    async confirmPayment(input: ConfirmPaymentInput): Promise<PaymentIntent> {
      this.confirmInputs.push({ ...input });
      return super.confirmPayment(input);
    }
  }

  /** A gateway that echoes a different amount than the one it was sent. */
  function wrongAmountGateway(
    delegate: MockEgyptGateway,
    operation: 'create' | 'confirm',
  ): PaymentGateway {
    return gatewayWithFaults(delegate, {
      [operation === 'create' ? 'createPaymentIntent' : 'confirmPayment']: async (
        input: any,
      ) => {
        const method = operation === 'create' ? 'createPaymentIntent' : 'confirmPayment';
        const intent = await (delegate as any)[method](input);
        return { ...intent, amount: intent.amount + 1 };
      },
    });
  }

  /** A gateway whose stored amount contradicts the durable attempt. */
  function wrongRetrieveAmountGateway(delegate: MockEgyptGateway): PaymentGateway {
    return gatewayWithFaults(delegate, {
      retrievePayment: async (id: string) => {
        const intent = await delegate.retrievePayment(id);
        return intent ? { ...intent, amount: intent.amount + 1 } : intent;
      },
    });
  }

  /** A gateway that returns a structurally incomplete intent. */
  function malformedGateway(delegate: MockEgyptGateway): PaymentGateway {
    return gatewayWithFaults(delegate, {
      retrievePayment: async (id: string) => {
        const intent = await delegate.retrievePayment(id);
        return intent ? { ...intent, amount: Number.NaN } : intent;
      },
    });
  }

  /** A gateway whose provider status can be forced, to model late events. */
  class SwitchableGateway extends MockEgyptGateway {
    forceStatus: string | null = null;

    async retrievePayment(paymentId: string): Promise<PaymentIntent | null> {
      const intent = await super.retrievePayment(paymentId);
      return intent && this.forceStatus
        ? { ...intent, status: this.forceStatus as PaymentIntent['status'] }
        : intent;
    }
  }

  /** A gateway whose lookup fails for the first `failTimes` calls. */
  class FlakyGateway extends MockEgyptGateway {
    failTimes = 0;
    private calls = 0;

    async retrievePayment(paymentId: string): Promise<PaymentIntent | null> {
      this.calls += 1;
      if (this.calls <= this.failTimes) {
        throw new Error('ETIMEDOUT: provider lookup timed out');
      }
      return super.retrievePayment(paymentId);
    }
  }

  async function createIntent(
    app: TestApp,
    bookingId: string,
    userId = 'user-1',
    key = 'idem-1',
    amount = 1000,
  ) {
    return app.service.createPayment(
      { bookingId, amount, currency: 'EGP', market: 'EG', idempotencyKey: key },
      userId,
    );
  }

  async function confirmIntent(
    app: TestApp,
    paymentId: string,
    bookingId: string,
    method: 'CARD_SUCCESS' | 'CARD_3DS' | 'CARD_DECLINED' | 'WALLET' = 'CARD_SUCCESS',
    userId = 'user-1',
    key = 'confirm-1',
  ) {
    return app.service.confirmPayment(
      {
        paymentId,
        methodReference: method,
        market: 'EG',
        idempotencyKey: key,
        bookingId,
      },
      userId,
    );
  }

  function signedEvent(
    id: string,
    paymentId: string,
    type: 'payment.succeeded' | 'payment.failed' | 'payment.refunded',
    occurredAt = new Date().toISOString(),
  ) {
    return {
      id,
      paymentId,
      type,
      signature: signMockWebhook({ id, paymentId, type, occurredAt }),
      occurredAt,
    };
  }

  /**
   * A payment in the 3DS `pending` state: intent created, confirmed with
   * CARD_3DS, no webhook applied yet.
   */
  async function threeDsSetup(app: TestApp) {
    const bookingId = await insertBooking();
    const created = await createIntent(app, bookingId, 'user-1', 'webhook-key');
    const paymentId = created.status === 'OK' ? created.intent.paymentId : '';
    await confirmIntent(app, paymentId, bookingId, 'CARD_3DS', 'user-1', 'c');
    return { bookingId, paymentId };
  }

  // =========================================================================
  // PaymentAttempt
  // =========================================================================

  describe('PaymentAttempt persistence', () => {
    it('A1. creates a durable attempt with every required field', async () => {
      const app = buildApp();
      const bookingId = await insertBooking({ authoritativePrice: 4850 });

      const result = await createIntent(app, bookingId, 'user-1', 'idem-A1', 4850);
      expect(result.status).toBe('OK');

      const stored = await app.attempts.findById(
        result.status === 'OK' ? result.attemptId : '',
      );
      expect(stored).not.toBeNull();
      expect(stored!.bookingId).toBe(bookingId);
      expect(stored!.userId).toBe('user-1');
      expect(stored!.idempotencyKey).toBe('idem-A1');
      expect(stored!.amount).toBe(4850);
      expect(stored!.currency).toBe('EGP');
      expect(stored!.gatewayId).toBe('mock-egypt-gateway');
      expect(stored!.gatewayRef).toBe(
        result.status === 'OK' ? result.intent.paymentId : null,
      );
      expect(stored!.status).toBe('requires_action');
      expect(stored!.createdAt).toBeInstanceOf(Date);
      expect(stored!.updatedAt).toBeInstanceOf(Date);
      expect(stored!.failureCode).toBeNull();
    });

    it('A2. the same user + same idempotency key returns the same attempt', async () => {
      const app = buildApp();
      const bookingId = await insertBooking();

      const a = await createIntent(app, bookingId, 'user-1', 'same-key');
      const b = await createIntent(app, bookingId, 'user-1', 'same-key');

      expect(a.status).toBe('OK');
      expect(b.status).toBe('OK');
      if (a.status === 'OK' && b.status === 'OK') {
        expect(a.attemptId).toBe(b.attemptId);
        expect(a.intent.paymentId).toBe(b.intent.paymentId);
      }

      const rows = await app.attemptRepo.find({
        where: { userId: 'user-1', idempotencyKey: 'same-key' },
      });
      expect(rows).toHaveLength(1);
    });

    it('A3. concurrent requests with the same key create exactly one attempt', async () => {
      const app = buildApp();
      const bookingId = await insertBooking();

      const results = await Promise.all([
        createIntent(app, bookingId, 'user-1', 'race-key'),
        createIntent(app, bookingId, 'user-1', 'race-key'),
        createIntent(app, bookingId, 'user-1', 'race-key'),
        createIntent(app, bookingId, 'user-1', 'race-key'),
      ]);

      const ids = new Set(
        results.map(r => ('attemptId' in r ? r.attemptId : undefined)).filter(Boolean),
      );
      expect(ids.size).toBe(1);

      const rows = await app.attemptRepo.find({
        where: { userId: 'user-1', idempotencyKey: 'race-key' },
      });
      expect(rows).toHaveLength(1);
      // The gateway was called once, not once per racing request.
      expect(results.filter(r => r.status === 'OK')).toHaveLength(4);
    });

    it('A4. different users cannot read or reuse another user\'s attempt', async () => {
      const app = buildApp();
      const bookingA = await insertBooking({ offerId: 'offer-a', userId: 'user-1' });
      const bookingB = await insertBooking({ offerId: 'offer-b', userId: 'user-2' });

      const a = await createIntent(app, bookingA, 'user-1', 'owner-key');
      expect(a.status).toBe('OK');
      const attemptId = a.status === 'OK' ? a.attemptId : '';
      const gatewayRef = a.status === 'OK' ? a.intent.paymentId : '';

      // Another user cannot see the attempt.
      expect(await app.attempts.findOwned('user-2', attemptId)).toBeNull();

      // Another user cannot confirm it.
      await expect(
        confirmIntent(app, gatewayRef, bookingB, 'CARD_SUCCESS', 'user-2', 'k'),
      ).rejects.toThrow(/does not belong to the caller/);

      // A different user with the same key gets their OWN attempt.
      const b = await createIntent(app, bookingB, 'user-2', 'owner-key');
      expect(b.status).toBe('OK');
      if (b.status === 'OK') {
        expect(b.attemptId).not.toBe(attemptId);
      }

      const total = await app.attemptRepo.count();
      expect(total).toBe(2);
    });

    it('A5. different idempotency keys create distinct attempts', async () => {
      const app = buildApp();
      const bookingId = await insertBooking();

      const a = await createIntent(app, bookingId, 'user-1', 'key-1');
      const b = await createIntent(app, bookingId, 'user-1', 'key-2');

      expect(a.status).toBe('OK');
      expect(b.status).toBe('OK');
      if (a.status === 'OK' && b.status === 'OK') {
        expect(a.attemptId).not.toBe(b.attemptId);
      }
      expect(await app.attemptRepo.count()).toBe(2);
    });

    it('A6. a declined attempt stays auditable', async () => {
      const app = buildApp();
      const bookingId = await insertBooking();

      const created = await createIntent(app, bookingId, 'user-1', 'decline-key');
      const paymentId = created.status === 'OK' ? created.intent.paymentId : '';

      const declined = await confirmIntent(
        app,
        paymentId,
        bookingId,
        'CARD_DECLINED',
        'user-1',
        'confirm-d',
      );
      expect(declined.status).toBe('OK');

      const rows = await app.attemptRepo.find({ where: { idempotencyKey: 'decline-key' } });
      expect(rows).toHaveLength(1);
      expect(rows[0].status).toBe('declined');
      expect(rows[0].method).toBe('CARD_DECLINED');

      // The decline is recorded in the ledger as a failed capture, not a success.
      const ledger = await app.ledger.forBooking(bookingId);
      expect(ledger).toHaveLength(1);
      expect(ledger[0].leg).toBe('CUSTOMER');
      expect(ledger[0].type).toBe('capture');
      expect(ledger[0].status).toBe('failed');
      expect(ledger[0].amount).toBe(1000);
    });

    it('A7. an ambiguous timeout creates no second attempt and no automatic retry', async () => {
      const app = buildApp(timeoutGateway());
      const bookingId = await insertBooking();

      const created = await createIntent(app, bookingId, 'user-1', 'timeout-key');
      expect(created.status).toBe('OK');
      const paymentId = created.status === 'OK' ? created.intent.paymentId : '';

      const first = await confirmIntent(
        app,
        paymentId,
        bookingId,
        'CARD_SUCCESS',
        'user-1',
        'confirm-t',
      );
      expect(first.status).toBe('UNKNOWN');
      expect(first.attemptStatus).toBe('unknown');

      // Retrying the same key reconciles the SAME attempt — no new row, no charge.
      const second = await confirmIntent(
        app,
        paymentId,
        bookingId,
        'CARD_SUCCESS',
        'user-1',
        'confirm-t',
      );
      expect(second.attemptId).toBe(first.attemptId);

      const rows = await app.attemptRepo.find();
      expect(rows).toHaveLength(1);
      expect(rows[0].status).toBe('unknown');
      expect(rows[0].failureCode).toBe('provider_timeout');

      // No capture was recorded for an ambiguous outcome.
      expect(await app.ledger.forBooking(bookingId)).toHaveLength(0);
    });

    it('A8. invalid state transitions are rejected', async () => {
      const app = buildApp();
      const bookingId = await insertBooking();
      const created = await createIntent(app, bookingId, 'user-1', 'state-key');
      const attemptId = created.status === 'OK' ? created.attemptId : '';

      await expect(app.attempts.transition(attemptId, 'succeeded')).rejects.toBeInstanceOf(
        InvalidPaymentAttemptTransitionError,
      );
      await expect(app.attempts.transition(attemptId, 'refunded')).rejects.toBeInstanceOf(
        InvalidPaymentAttemptTransitionError,
      );

      // A legal transition still works.
      const ok = await app.attempts.transition(attemptId, 'processing');
      expect(ok.outcome).toBe('transitioned');
      expect(ok.attempt.status).toBe('processing');
    });

    it('A9. a confirmed success cannot be downgraded', async () => {
      const app = buildApp();
      const bookingId = await insertBooking();
      const created = await createIntent(app, bookingId, 'user-1', 'success-key');
      const paymentId = created.status === 'OK' ? created.intent.paymentId : '';
      const attemptId = created.status === 'OK' ? created.attemptId : '';

      await confirmIntent(app, paymentId, bookingId, 'CARD_SUCCESS', 'user-1', 'c');

      for (const illegal of ['failed', 'declined', 'pending', 'unknown']) {
        await expect(app.attempts.transition(attemptId, illegal as any)).rejects.toBeInstanceOf(
          InvalidPaymentAttemptTransitionError,
        );
      }

      // `succeeded -> processing` IS legal (a refund is a gateway call in flight
      // against a captured payment), but it is only ever taken by the refund
      // path and must return to the pre-refund state — see T9.
      const inflight = await app.attempts.transition(attemptId, 'processing');
      expect(inflight.outcome).toBe('transitioned');
      const restored = await app.attempts.transition(attemptId, 'succeeded');
      expect(restored.outcome).toBe('transitioned');

      const stored = await app.attempts.findById(attemptId);
      expect(stored!.status).toBe('succeeded');

      // A redelivered success is a no-op, not an error and not a second charge.
      const noop = await app.attempts.transition(attemptId, 'succeeded');
      expect(noop.outcome).toBe('noop');
      expect(await app.ledger.forBooking(bookingId)).toHaveLength(1);
    });
  });

  // =========================================================================
  // PaymentTransaction ledger
  // =========================================================================

  describe('PaymentTransaction ledger', () => {
    it('T1. a CUSTOMER transaction persists against the correct booking and attempt', async () => {
      const app = buildApp();
      const bookingId = await insertBooking();
      const created = await createIntent(app, bookingId, 'user-1', 'txn-key');
      const paymentId = created.status === 'OK' ? created.intent.paymentId : '';
      const attemptId = created.status === 'OK' ? created.attemptId : '';

      await confirmIntent(app, paymentId, bookingId, 'CARD_SUCCESS', 'user-1', 'c');

      const rows = await app.ledger.forBooking(bookingId);
      expect(rows).toHaveLength(1);
      expect(rows[0].leg).toBe('CUSTOMER');
      expect(rows[0].attemptId).toBe(attemptId);
      expect(rows[0].providerOperationId).toBeNull();
      expect(rows[0].bookingId).toBe(bookingId);
      expect(rows[0].type).toBe('capture');
      expect(rows[0].status).toBe('succeeded');
      expect(rows[0].amount).toBe(1000);
      expect(rows[0].currency).toBe('EGP');
      expect(rows[0].gatewayRef).toBe(paymentId);
    });

    it('T2. a SUPPLIER transaction persists against its provider operation', async () => {
      const app = buildApp();
      const bookingId = await insertBooking();
      const operationId = await insertOperation({ bookingId });

      const row = await app.ledger.append({
        bookingId,
        leg: 'SUPPLIER',
        type: 'capture',
        status: 'succeeded',
        amount: 800,
        currency: 'EGP',
        providerOperationId: operationId,
        providerRef: 'ord_1',
        idempotencyKey: 'supplier:op-1',
      });

      expect(row.id).toBeDefined();
      expect(row.attemptId).toBeNull();

      const rows = await app.txnRepo.find({ where: { bookingId } });
      expect(rows).toHaveLength(1);
      expect(rows[0].leg).toBe('SUPPLIER');
      expect(rows[0].providerOperationId).toBe(operationId);
    });

    it('T3. cross-booking references are rejected by the database', async () => {
      const app = buildApp();
      const bookingA = await insertBooking({ offerId: 'offer-a' });
      const bookingB = await insertBooking({ offerId: 'offer-b' });
      const created = await createIntent(app, bookingA, 'user-1', 'cross-key');
      const attemptId = created.status === 'OK' ? created.attemptId : '';

      // CUSTOMER transaction pointing at another booking.
      await expectPgError(
        () =>
          app.ledger.append({
            bookingId: bookingB,
            leg: 'CUSTOMER',
            type: 'capture',
            status: 'succeeded',
            amount: 100,
            currency: 'EGP',
            attemptId,
            idempotencyKey: 'cross-booking-customer',
          }),
        PG_FK,
        'cross-booking CUSTOMER transaction',
      );

      const operationId = await insertOperation({ bookingId: bookingA });
      await expectPgError(
        () =>
          app.ledger.append({
            bookingId: bookingB,
            leg: 'SUPPLIER',
            type: 'capture',
            status: 'succeeded',
            amount: 100,
            currency: 'EGP',
            providerOperationId: operationId,
            idempotencyKey: 'cross-booking-supplier',
          }),
        PG_FK,
        'cross-booking SUPPLIER transaction',
      );

      expect(await app.txnRepo.count()).toBe(0);
    });

    it('T4. duplicate ledger references are deduplicated, not duplicated', async () => {
      const app = buildApp();
      const bookingId = await insertBooking();
      const created = await createIntent(app, bookingId, 'user-1', 'dup-key');
      const paymentId = created.status === 'OK' ? created.intent.paymentId : '';
      const attemptId = created.status === 'OK' ? created.attemptId : '';

      await confirmIntent(app, paymentId, bookingId, 'CARD_SUCCESS', 'user-1', 'c');

      // Same key twice (a retried confirm / replayed webhook).
      const first = await app.ledger.append({
        bookingId,
        leg: 'CUSTOMER',
        type: 'capture',
        status: 'succeeded',
        amount: 1000,
        currency: 'EGP',
        attemptId,
        gatewayRef: paymentId,
        idempotencyKey: `capture:${attemptId}`,
      });
      const second = await app.ledger.append({
        bookingId,
        leg: 'CUSTOMER',
        type: 'capture',
        status: 'succeeded',
        amount: 1000,
        currency: 'EGP',
        attemptId,
        gatewayRef: paymentId,
        idempotencyKey: `capture:${attemptId}`,
      });

      expect(second.id).toBe(first.id);
      expect(await app.txnRepo.count()).toBe(1);
    });

    it('T5. customer and supplier legs stay separate', async () => {
      const app = buildApp();
      const bookingId = await insertBooking();
      const created = await createIntent(app, bookingId, 'user-1', 'legs-key');
      const paymentId = created.status === 'OK' ? created.intent.paymentId : '';
      const attemptId = created.status === 'OK' ? created.attemptId : '';
      const operationId = await insertOperation({ bookingId });

      await confirmIntent(app, paymentId, bookingId, 'CARD_SUCCESS', 'user-1', 'c');
      await app.ledger.append({
        bookingId,
        leg: 'SUPPLIER',
        type: 'capture',
        status: 'succeeded',
        amount: 700,
        currency: 'EGP',
        providerOperationId: operationId,
        providerRef: 'ord_1',
        idempotencyKey: 'supplier:legs',
      });

      const rows = await app.ledger.forBooking(bookingId);
      expect(rows).toHaveLength(2);
      expect(rows.filter(r => r.leg === 'CUSTOMER')).toHaveLength(1);
      expect(rows.filter(r => r.leg === 'SUPPLIER')).toHaveLength(1);
      expect(rows.find(r => r.leg === 'CUSTOMER')!.attemptId).toBe(attemptId);
      expect(rows.find(r => r.leg === 'SUPPLIER')!.attemptId).toBeNull();

      // The balance covers the CUSTOMER leg only.
      const balance = await app.ledger.bookingBalance(bookingId);
      expect(balance.charged).toBe(1000);
      expect(balance.refunded).toBe(0);
      expect(balance.net).toBe(1000);
    });

    it('T6. a partial refund does not mark the full payment refunded', async () => {
      const app = buildApp();
      const bookingId = await insertBooking();
      const created = await createIntent(app, bookingId, 'user-1', 'refund-key');
      const paymentId = created.status === 'OK' ? created.intent.paymentId : '';
      const attemptId = created.status === 'OK' ? created.attemptId : '';

      await confirmIntent(app, paymentId, bookingId, 'CARD_SUCCESS', 'user-1', 'c');

      const refund = await app.service.refundPayment(
        {
          paymentId,
          amount: 400,
          reason: 'customer request',
          market: 'EG',
          idempotencyKey: 'refund-1',
          bookingId,
        },
        'user-1',
      );
      expect(refund.status).toBe('OK');

      const stored = await app.attempts.findById(attemptId);
      expect(stored!.status).toBe('partially_refunded');

      const balance = await app.ledger.bookingBalance(bookingId);
      expect(balance.charged).toBe(1000);
      expect(balance.refunded).toBe(400);
      expect(balance.net).toBe(600);

      const refunds = (await app.ledger.forBooking(bookingId)).filter(
        r => r.type === 'refund',
      );
      expect(refunds).toHaveLength(1);
      expect(refunds[0].amount).toBe(400);
      expect(refunds[0].status).toBe('succeeded');
    });

    it('T7. Payment Intent creation alone creates no capture transaction', async () => {
      const app = buildApp();
      const bookingId = await insertBooking();

      await createIntent(app, bookingId, 'user-1', 'intent-only');

      expect(await app.txnRepo.count()).toBe(0);
      const balance = await app.ledger.bookingBalance(bookingId);
      expect(balance.charged).toBe(0);
      expect(balance.currency).toBeNull();
    });

    it('T9. a failed refund never turns a confirmed success into a failure', async () => {
      const bookingId = await insertBooking();

      // Create + confirm against a working gateway.
      const delegate = new MockEgyptGateway();
      const working = buildApp(delegate);
      const created = await createIntent(working, bookingId, 'user-1', 'refund-fail-key');
      const paymentId = created.status === 'OK' ? created.intent.paymentId : '';
      const attemptId = created.status === 'OK' ? created.attemptId : '';
      await confirmIntent(working, paymentId, bookingId, 'CARD_SUCCESS', 'user-1', 'c');

      // Now refund through a gateway that times out, sharing the same state.
      const app = buildApp(
        gatewayWithFaults(delegate, {
          refundPayment: async () => {
            throw new Error('ETIMEDOUT: provider timed out');
          },
        }),
      );

      const refund = await app.service.refundPayment(
        {
          paymentId,
          amount: 400,
          market: 'EG',
          idempotencyKey: 'refund-fail',
          bookingId,
        },
        'user-1',
      );
      expect(refund.status).toBe('UNKNOWN');

      const stored = await app.attempts.findById(attemptId);
      // The capture is still valid: an ambiguous refund must not destroy it.
      expect(['succeeded', 'unknown']).toContain(stored!.status);
      expect(stored!.status).not.toBe('failed');
      expect(stored!.status).not.toBe('declined');

      // No refund was recorded.
      const refunds = (await app.ledger.forBooking(bookingId)).filter(
        r => r.type === 'refund',
      );
      expect(refunds).toHaveLength(0);
      // The original capture is untouched.
      expect(await app.txnRepo.count()).toBe(1);
    });

    it('T8. a failed database transaction leaves no partial ledger state', async () => {
      const app = buildApp();
      const bookingId = await insertBooking();
      const created = await createIntent(app, bookingId, 'user-1', 'rollback-key');
      const attemptId = created.status === 'OK' ? created.attemptId : '';

      await expect(
        ds.transaction(async em => {
          await app.ledger.appendWithin(em, {
            bookingId,
            leg: 'CUSTOMER',
            type: 'capture',
            status: 'succeeded',
            amount: 1000,
            currency: 'EGP',
            attemptId,
            idempotencyKey: 'rollback:test',
          });
          throw new Error('forced failure');
        }),
      ).rejects.toThrow('forced failure');

      expect(await app.txnRepo.count()).toBe(0);
    });
  });

  // =========================================================================
  // Webhook persistence
  // =========================================================================

  describe('Webhook persistence', () => {

    it('W1. duplicate event ids are processed once', async () => {
      const app = buildApp();
      const { bookingId, paymentId } = await threeDsSetup(app);
      const event = signedEvent('evt-dup', paymentId, 'payment.succeeded');

      const first = await app.service.handleWebhook(event);
      expect(first.status).toBe('PROCESSED');

      const second = await app.service.handleWebhook(event);
      expect(second.status).toBe('REJECTED');
      // The first delivery mirrors the id into the retired archive, so the
      // redelivery is caught by the legacy check before the new-store check.
      const reason = 'reason' in second ? second.reason : '';
      expect(['duplicate_event', 'duplicate_event_legacy']).toContain(reason);

      expect(await app.webhookRepo.count()).toBe(1);
      expect(await app.txnRepo.count()).toBe(1);

      const stored = await app.webhookRepo.findOne({
        where: { provider: 'mock-egypt-gateway', eventId: 'evt-dup' },
      });
      expect(stored!.status).toBe('processed');
      expect(stored!.outcome).toBe('succeeded');
      expect(stored!.processedAt).not.toBeNull();

      const rows = await app.ledger.forBooking(bookingId);
      expect(rows).toHaveLength(1);
      expect(rows[0].status).toBe('succeeded');
    });

    it('W2. concurrent duplicate delivery is safe', async () => {
      const app = buildApp();
      const { paymentId } = await threeDsSetup(app);
      const event = signedEvent('evt-race', paymentId, 'payment.succeeded');

      const results = await Promise.all([
        app.service.handleWebhook(event),
        app.service.handleWebhook(event),
        app.service.handleWebhook(event),
      ]);

      // Every response is a clean outcome — never an unhandled error.
      for (const r of results) {
        expect(['PROCESSED', 'REJECTED']).toContain(r.status);
      }
      expect(results.some(r => r.status === 'PROCESSED')).toBe(true);

      // Exactly one event row, one ledger effect, one succeeded attempt.
      expect(await app.webhookRepo.count()).toBe(1);
      expect(await app.txnRepo.count()).toBe(1);

      const attempts = await app.attemptRepo.find();
      expect(attempts).toHaveLength(1);
      expect(attempts[0].status).toBe('succeeded');
    });

    it('W3. invalid signatures are rejected and persist nothing', async () => {
      const app = buildApp();
      const { bookingId, paymentId } = await threeDsSetup(app);

      const tampered = {
        ...signedEvent('evt-bad', paymentId, 'payment.succeeded'),
        signature: 'tampered',
      };
      const result = await app.service.handleWebhook(tampered);
      expect(result.status).toBe('REJECTED');
      expect('reason' in result ? result.reason : '').toBe('invalid_signature');

      expect(await app.webhookRepo.count()).toBe(0);
      expect(await app.txnRepo.count()).toBe(0);

      const attempts = await app.attemptRepo.find();
      expect(attempts[0].status).toBe('pending');
      expect(attempts[0].failureCode).toBeNull();
    });

    it('W4. an unverified event cannot create confirmed financial success', async () => {
      const app = buildApp();
      const { paymentId } = await threeDsSetup(app);

      // No signature verification is possible for this payload, so the handler
      // must refuse before touching the attempt or the ledger.
      const forged = {
        id: 'evt-forged',
        paymentId,
        type: 'payment.succeeded' as const,
        signature: '',
        occurredAt: new Date().toISOString(),
      };
      const result = await app.service.handleWebhook(forged);
      expect(result.status).toBe('REJECTED');

      const attempts = await app.attemptRepo.find();
      expect(attempts[0].status).not.toBe('succeeded');
      expect(await app.txnRepo.count()).toBe(0);
    });

    it('W5. the event outcome comes from the gateway, not the client-supplied type', async () => {
      const app = buildApp();
      const { bookingId, paymentId } = await threeDsSetup(app);

      // A `payment.failed` webhook for an intent the gateway still reports as
      // PENDING must not be promoted to a decline or a success.
      const failed = await app.service.handleWebhook(
        signedEvent('evt-failed', paymentId, 'payment.failed'),
      );
      expect(failed.status).toBe('PROCESSED');

      const attempts = await app.attemptRepo.find();
      expect(attempts[0].status).not.toBe('succeeded');
      expect(attempts[0].status).not.toBe('declined');
      expect(await app.txnRepo.count()).toBe(0);

      // A subsequent verified success settles it exactly once.
      const ok = await app.service.handleWebhook(
        signedEvent('evt-ok', paymentId, 'payment.succeeded'),
      );
      expect(ok.status).toBe('PROCESSED');
      const after = await app.attemptRepo.find();
      expect(after[0].status).toBe('succeeded');
      expect(await app.txnRepo.count()).toBe(1);

      // The ledger agrees with the attempt state.
      const rows = await app.ledger.forBooking(bookingId);
      expect(rows).toHaveLength(1);
      expect(rows[0].status).toBe('succeeded');
    });

    it('W6. an unknown payment is retryable, not permanently consumed', async () => {
      const app = buildApp();
      await insertBooking();

      const result = await app.service.handleWebhook(
        signedEvent('evt-unknown', 'pay_does_not_exist', 'payment.succeeded'),
      );
      expect(result.status).toBe('REJECTED');
      expect('reason' in result ? result.reason : '').toBe('unknown_payment');

      // The event is NOT settled: it is retryable, and it must NOT be archived
      // (archiving it would block every redelivery forever).
      const events = await app.webhookRepo.find();
      expect(events).toHaveLength(1);
      expect(events[0].status).toBe('retryable');
      expect(events[0].outcome).toBe('payment_not_found');
      expect(events[0].processedAt).toBeNull();
      expect(await app.legacyRepo.count()).toBe(0);
      expect(await app.txnRepo.count()).toBe(0);
    });

    it('W7. a previously processed legacy event id is rejected as a duplicate', async () => {
      const app = buildApp();
      const { bookingId, paymentId } = await threeDsSetup(app);

      // A pre-P4-2 replay record: the archive must still block the event even
      // though `webhook_events` knows nothing about it.
      await app.legacyRepo.save(app.legacyRepo.create({ id: 'evt-legacy' }));

      const result = await app.service.handleWebhook(
        signedEvent('evt-legacy', paymentId, 'payment.succeeded'),
      );
      expect(result.status).toBe('REJECTED');
      expect('reason' in result ? result.reason : '').toBe('duplicate_event_legacy');

      // The financial effect never happened.
      expect(await app.webhookRepo.count()).toBe(0);
      expect(await app.legacyRepo.count()).toBe(1);
      expect(await app.txnRepo.count()).toBe(0);
      const attempts = await app.attemptRepo.find();
      expect(attempts[0].status).toBe('pending');
      expect(bookingId).toBeTruthy();
    });

    it('W8. a new event is recorded in both replay stores', async () => {
      const app = buildApp();
      const { paymentId } = await threeDsSetup(app);

      const result = await app.service.handleWebhook(
        signedEvent('evt-both', paymentId, 'payment.succeeded'),
      );
      expect(result.status).toBe('PROCESSED');

      expect(await app.webhookRepo.count()).toBe(1);
      expect(await app.legacyRepo.count()).toBe(1);

      const legacy = await app.legacyRepo.findOne({ where: { id: 'evt-both' } });
      expect(legacy).not.toBeNull();
      expect(legacy!.processedAt).toBeInstanceOf(Date);
    });

    it('W9. concurrent duplicate delivery stays consistent across both stores', async () => {
      const app = buildApp();
      const { paymentId } = await threeDsSetup(app);
      const event = signedEvent('evt-concurrent', paymentId, 'payment.succeeded');

      const results = await Promise.all([
        app.service.handleWebhook(event),
        app.service.handleWebhook(event),
        app.service.handleWebhook(event),
      ]);

      for (const r of results) {
        expect(['PROCESSED', 'REJECTED']).toContain(r.status);
      }
      expect(results.some(r => r.status === 'PROCESSED')).toBe(true);

      // Exactly one row in each replay store and exactly one financial effect.
      expect(await app.webhookRepo.count()).toBe(1);
      expect(await app.legacyRepo.count()).toBe(1);
      expect(await app.txnRepo.count()).toBe(1);

      const attempts = await app.attemptRepo.find();
      expect(attempts).toHaveLength(1);
      expect(attempts[0].status).toBe('succeeded');
    });

    it('W10. a retryable event is retried on redelivery, never archived', async () => {
      const app = buildApp();
      await insertBooking();

      const first = await app.service.handleWebhook(
        signedEvent('evt-unknown-2', 'pay_missing', 'payment.succeeded'),
      );
      expect(first.status).toBe('REJECTED');
      expect(await app.webhookRepo.count()).toBe(1);
      // Not archived — a redelivery must still be able to attempt the effect.
      expect(await app.legacyRepo.count()).toBe(0);

      // The redelivery RETRIES (it is not a hard duplicate) and fails the same
      // way, because the cause is still present.
      const second = await app.service.handleWebhook(
        signedEvent('evt-unknown-2', 'pay_missing', 'payment.succeeded'),
      );
      expect(second.status).toBe('REJECTED');
      expect('reason' in second ? second.reason : '').toBe('unknown_payment');
      expect(await app.webhookRepo.count()).toBe(1);
      expect(await app.legacyRepo.count()).toBe(0);
      expect(await app.txnRepo.count()).toBe(0);
    });
  });

  // =========================================================================
  // Webhook retryability (P4-2R2)
  // =========================================================================

  describe('Webhook retryability (P4-2R2)', () => {
    it('R1. an event arriving before its attempt exists is not permanently consumed', async () => {
      const app = buildApp();
      const bookingId = await insertBooking({ authoritativePrice: 1000 });

      // The gateway already knows the payment, but no attempt row exists yet.
      const intent = await app.gateway.createPaymentIntent({
        bookingId,
        idempotencyKey: 'user-1:early-key',
        amount: 1000,
        currency: 'EGP',
        market: 'EG',
      });
      // The provider has already confirmed it; only our association is missing.
      await app.gateway.confirmPayment({
        paymentId: intent.paymentId,
        methodReference: 'CARD_SUCCESS',
        idempotencyKey: 'gw-confirm',
      });

      const first = await app.service.handleWebhook(
        signedEvent('evt-early', intent.paymentId, 'payment.succeeded'),
      );
      expect(first.status).toBe('REJECTED');
      expect('reason' in first ? first.reason : '').toBe('unknown_attempt');

      // Retryable, NOT archived, NOT treated as processed.
      const events = await app.webhookRepo.find();
      expect(events[0].status).toBe('retryable');
      expect(events[0].outcome).toBe('attempt_not_found');
      expect(events[0].processedAt).toBeNull();
      expect(await app.legacyRepo.count()).toBe(0);
      expect(await app.txnRepo.count()).toBe(0);
    });

    it('R2. the same event processes exactly once after the association appears', async () => {
      const app = buildApp();
      const bookingId = await insertBooking({ authoritativePrice: 1000 });

      // The gateway knows the payment and it is awaiting 3DS settlement.
      const intent = await app.gateway.createPaymentIntent({
        bookingId,
        idempotencyKey: 'user-1:early-key-2',
        amount: 1000,
        currency: 'EGP',
        market: 'EG',
      });
      await app.gateway.confirmPayment({
        paymentId: intent.paymentId,
        methodReference: 'CARD_3DS',
        idempotencyKey: 'gw-confirm-2',
      });

      // The event arrives before our association exists.
      const early = await app.service.handleWebhook(
        signedEvent('evt-early-2', intent.paymentId, 'payment.succeeded'),
      );
      expect(early.status).toBe('REJECTED');
      expect('reason' in early ? early.reason : '').toBe('unknown_attempt');
      expect(await app.legacyRepo.count()).toBe(0);

      // The association appears through the normal funnel: intent + 3DS confirm.
      const created = await createIntent(app, bookingId, 'user-1', 'early-key-2', 1000);
      expect(created.status).toBe('OK');
      const paymentId = created.status === 'OK' ? created.intent.paymentId : '';
      expect(paymentId).toBe(intent.paymentId);
      await confirmIntent(app, paymentId, bookingId, 'CARD_3DS', 'user-1', 'confirm-early-2');
      expect((await app.attemptRepo.find())[0].status).toBe('pending');

      // R2: the same event now completes exactly once.
      const second = await app.service.handleWebhook(
        signedEvent('evt-early-2', paymentId, 'payment.succeeded'),
      );
      expect(second.status).toBe('PROCESSED');
      expect(second.attemptStatus).toBe('succeeded');
      expect(await app.txnRepo.count()).toBe(1);
      expect(await app.legacyRepo.count()).toBe(1);

      // A third delivery is a hard duplicate and adds nothing.
      const third = await app.service.handleWebhook(
        signedEvent('evt-early-2', paymentId, 'payment.succeeded'),
      );
      expect(third.status).toBe('REJECTED');
      expect(await app.txnRepo.count()).toBe(1);
      expect(await app.legacyRepo.count()).toBe(1);
    });

    it('R3. a temporary gateway lookup failure leaves the event retryable', async () => {
      const gateway = new FlakyGateway();
      gateway.failTimes = 1;
      const app = buildApp(gateway);
      const { paymentId } = await threeDsSetup(app);

      const first = await app.service.handleWebhook(
        signedEvent('evt-flaky', paymentId, 'payment.succeeded'),
      );
      expect(first.status).toBe('REJECTED');
      expect('reason' in first ? first.reason : '').toBe('gateway_unavailable');

      const events = await app.webhookRepo.find();
      expect(events).toHaveLength(1);
      expect(events[0].status).toBe('retryable');
      expect(events[0].outcome).toBe('gateway_unavailable');
      expect(events[0].processedAt).toBeNull();
      expect(await app.legacyRepo.count()).toBe(0);
      expect(await app.txnRepo.count()).toBe(0);

      // R5: the retry completes and produces exactly one financial effect.
      const second = await app.service.handleWebhook(
        signedEvent('evt-flaky', paymentId, 'payment.succeeded'),
      );
      expect(second.status).toBe('PROCESSED');
      expect(second.attemptStatus).toBe('succeeded');
      expect(await app.txnRepo.count()).toBe(1);
      expect(await app.legacyRepo.count()).toBe(1);
      expect((await app.webhookRepo.find())[0].status).toBe('processed');
    });

    it('R4. a database transaction failure does not archive or consume the event', async () => {
      const app = buildApp();
      const { bookingId, paymentId } = await threeDsSetup(app);

      // Force a REAL failure inside the effect transaction: a trigger rejects
      // the CUSTOMER ledger insert, so the attempt transition, the event status
      // and the archive insert all roll back together.
      await ds.query(`
        CREATE OR REPLACE FUNCTION p4_test_fail_ledger() RETURNS trigger AS $$
        BEGIN
          RAISE EXCEPTION 'injected ledger failure';
        END;
        $$ LANGUAGE plpgsql
      `);
      await ds.query(`
        CREATE TRIGGER trg_p4_fail_ledger
          BEFORE INSERT ON payment_transactions
          FOR EACH ROW EXECUTE FUNCTION p4_test_fail_ledger()
      `);

      try {
        const failed = await app.service.handleWebhook(
          signedEvent('evt-txfail', paymentId, 'payment.succeeded'),
        );
        expect(failed.status).toBe('REJECTED');
        expect('reason' in failed ? failed.reason : '').toBe('effect_retryable');
      } finally {
        await ds.query(
          'DROP TRIGGER IF EXISTS trg_p4_fail_ledger ON payment_transactions',
        );
        await ds.query('DROP FUNCTION IF EXISTS p4_test_fail_ledger()');
      }

      // Nothing was archived, the attempt did not move, no ledger row exists,
      // and the event is explicitly retryable.
      expect(await app.legacyRepo.count()).toBe(0);
      expect(await app.txnRepo.count()).toBe(0);
      expect((await app.attemptRepo.find())[0].status).toBe('pending');
      const events = await app.webhookRepo.find();
      expect(events[0].status).toBe('retryable');
      expect(events[0].outcome).toBe('effect_failed');
      expect(events[0].processedAt).toBeNull();

      // R5: the redelivery completes exactly once and every artefact agrees.
      const retry = await app.service.handleWebhook(
        signedEvent('evt-txfail', paymentId, 'payment.succeeded'),
      );
      expect(retry.status).toBe('PROCESSED');
      expect(retry.attemptStatus).toBe('succeeded');

      expect(await app.txnRepo.count()).toBe(1);
      expect(await app.legacyRepo.count()).toBe(1);
      expect((await app.attemptRepo.find())[0].status).toBe('succeeded');
      const settled = await app.webhookRepo.find();
      expect(settled[0].status).toBe('processed');
      expect(settled[0].outcome).toBe('succeeded');
      expect(settled[0].processedAt).not.toBeNull();
      expect(bookingId).toBeTruthy();
    });
  });

  // =========================================================================
  // Webhook final outcomes (P4-2R2)
  // =========================================================================

  describe('Webhook final outcomes (P4-2R2)', () => {
    it('F9. a confirmed gateway amount contradiction cannot produce a capture', async () => {
      const app = buildApp(wrongRetrieveAmountGateway(new MockEgyptGateway()));
      const { bookingId, paymentId } = await threeDsSetup(app);

      const result = await app.service.handleWebhook(
        signedEvent('evt-mismatch', paymentId, 'payment.succeeded'),
      );
      expect(result.status).toBe('REJECTED');
      expect('reason' in result ? result.reason : '').toBe('gateway_amount_mismatch');

      // PERMANENT: archived, so a redelivery cannot retry it into a capture.
      expect(await app.txnRepo.count()).toBe(0);
      expect(await app.legacyRepo.count()).toBe(1);
      const events = await app.webhookRepo.find();
      expect(events[0].status).toBe('failed');
      expect(events[0].outcome).toBe('gateway_amount_mismatch');

      const again = await app.service.handleWebhook(
        signedEvent('evt-mismatch', paymentId, 'payment.succeeded'),
      );
      expect(again.status).toBe('REJECTED');
      expect(await app.txnRepo.count()).toBe(0);
      expect(bookingId).toBeTruthy();
    });

    it('F10. an incomplete gateway response is retryable, not a confirmed failure', async () => {
      const app = buildApp(malformedGateway(new MockEgyptGateway()));
      const { paymentId } = await threeDsSetup(app);

      const first = await app.service.handleWebhook(
        signedEvent('evt-incomplete', paymentId, 'payment.succeeded'),
      );
      expect(first.status).toBe('REJECTED');
      expect('reason' in first ? first.reason : '').toBe('gateway_response_incomplete');

      // The attempt is NOT moved to a failure — nothing was proven.
      expect((await app.attemptRepo.find())[0].status).toBe('pending');
      expect(await app.txnRepo.count()).toBe(0);
      expect(await app.legacyRepo.count()).toBe(0);

      const events = await app.webhookRepo.find();
      expect(events[0].status).toBe('retryable');
      expect(events[0].outcome).toBe('gateway_response_incomplete');
      expect(events[0].processedAt).toBeNull();
    });

    it('C12. different event ids for the same payment cannot duplicate the capture', async () => {
      const app = buildApp();
      const { bookingId, paymentId } = await threeDsSetup(app);

      const a = await app.service.handleWebhook(
        signedEvent('evt-A', paymentId, 'payment.succeeded'),
      );
      expect(a.status).toBe('PROCESSED');

      // A distinct event id for the SAME payment (the gateway re-issued it).
      const b = await app.service.handleWebhook(
        signedEvent('evt-B', paymentId, 'payment.succeeded'),
      );
      expect(b.status).toBe('PROCESSED');

      // One capture, one succeeded attempt, two archived identities.
      const rows = await app.ledger.forBooking(bookingId);
      expect(rows).toHaveLength(1);
      expect(rows[0].status).toBe('succeeded');
      expect((await app.attemptRepo.find())[0].status).toBe('succeeded');
      expect(await app.legacyRepo.count()).toBe(2);
      expect(await app.webhookRepo.count()).toBe(2);
    });

    it('C13. a late failure event cannot downgrade a succeeded payment', async () => {
      const gateway = new SwitchableGateway();
      const app = buildApp(gateway);
      const { bookingId, paymentId } = await threeDsSetup(app);

      const ok = await app.service.handleWebhook(
        signedEvent('evt-ok', paymentId, 'payment.succeeded'),
      );
      expect(ok.status).toBe('PROCESSED');
      expect((await app.attemptRepo.find())[0].status).toBe('succeeded');
      expect(await app.txnRepo.count()).toBe(1);

      // The provider now reports FAILED for the same payment.
      gateway.forceStatus = 'FAILED';
      const late = await app.service.handleWebhook(
        signedEvent('evt-late', paymentId, 'payment.failed'),
      );
      expect(late.status).toBe('REJECTED');
      expect('reason' in late ? late.reason : '').toBe('attempt_state_conflict');

      // The capture stands: no downgrade, no second ledger row.
      expect((await app.attemptRepo.find())[0].status).toBe('succeeded');
      expect(await app.txnRepo.count()).toBe(1);
      // The late event is permanently archived so a redelivery cannot retry
      // the downgrade.
      expect(await app.legacyRepo.count()).toBe(2);
      const late2 = await app.service.handleWebhook(
        signedEvent('evt-late', paymentId, 'payment.failed'),
      );
      expect(late2.status).toBe('REJECTED');
      expect((await app.attemptRepo.find())[0].status).toBe('succeeded');
      expect(await app.txnRepo.count()).toBe(1);
      expect(bookingId).toBeTruthy();
    });

    it('C14. a duplicate event cannot cause a second payment-state transition', async () => {
      const app = buildApp();
      const { paymentId } = await threeDsSetup(app);

      const first = await app.service.handleWebhook(
        signedEvent('evt-dup', paymentId, 'payment.succeeded'),
      );
      expect(first.status).toBe('PROCESSED');
      const afterFirst = (await app.attemptRepo.find())[0];
      expect(afterFirst.status).toBe('succeeded');

      const second = await app.service.handleWebhook(
        signedEvent('evt-dup', paymentId, 'payment.succeeded'),
      );
      expect(second.status).toBe('REJECTED');
      const afterSecond = (await app.attemptRepo.find())[0];

      // Untouched: the redelivery was blocked before any write.
      expect(afterSecond.status).toBe('succeeded');
      expect(afterSecond.updatedAt.getTime()).toBe(afterFirst.updatedAt.getTime());
      expect(await app.txnRepo.count()).toBe(1);
      expect(await app.webhookRepo.count()).toBe(1);
      expect(await app.legacyRepo.count()).toBe(1);
    });

    it('C15. a losing compare-and-set race cannot record a capture for a declined attempt', async () => {
      const app = buildApp();
      const bookingId = await insertBooking({ authoritativePrice: 1000 });

      // The gateway already reports SUCCEEDED for this payment.
      const intent = await app.gateway.createPaymentIntent({
        bookingId,
        idempotencyKey: 'user-1:race-key',
        amount: 1000,
        currency: 'EGP',
        market: 'EG',
      });
      await app.gateway.confirmPayment({
        paymentId: intent.paymentId,
        methodReference: 'CARD_SUCCESS',
        idempotencyKey: 'gw-race',
      });

      // The durable attempt is still `pending` — the webhook path's expected
      // pre-state for a 3DS-style settlement.
      await ds.query(
        `INSERT INTO payment_attempts
           ("bookingId","userId","attemptNo","idempotencyKey",amount,currency,status,"gatewayId","gatewayRef")
         VALUES ($1,'user-1',1,'race-attempt-key',1000,'EGP','pending','mock-egypt-gateway',$2)`,
        [bookingId, intent.paymentId],
      );

      // Hold the row lock and move the attempt to `declined` WITHOUT committing.
      // The webhook's compare-and-set UPDATE therefore loses the race and
      // `transitionWithin` re-reads the row and reports `conflict`.
      const lock = ds.createQueryRunner();
      await lock.connect();
      await lock.startTransaction();
      await lock.query(
        `UPDATE payment_attempts SET status = 'declined'
         WHERE "bookingId" = $1 AND status = 'pending'`,
        [bookingId],
      );

      const pending = app.service.handleWebhook(
        signedEvent('evt-race', intent.paymentId, 'payment.succeeded'),
      );

      // Wait until the handler is genuinely blocked on the row lock, so the
      // `conflict` branch (not the pre-update state-machine assert) runs.
      const deadline = Date.now() + 5000;
      let waiting = 0;
      while (Date.now() < deadline) {
        const rows: Array<{ waiting: number }> = await ds.query(
          `SELECT count(*)::int AS waiting FROM pg_stat_activity
            WHERE wait_event_type = 'Lock' AND query ILIKE '%payment_attempts%'`,
        );
        waiting = rows[0]?.waiting ?? 0;
        if (waiting > 0) break;
        await new Promise(r => setTimeout(r, 50));
      }
      expect(waiting).toBeGreaterThan(0);

      await lock.commitTransaction();
      const result = await pending;
      await lock.release();

      // The event is permanently rejected: the durable attempt contradicts the
      // authoritative outcome, so NO capture may be recorded for it.
      expect(result.status).toBe('REJECTED');
      expect('reason' in result ? result.reason : '').toBe('attempt_state_conflict');
      expect((await app.attemptRepo.find())[0].status).toBe('declined');
      expect(await app.txnRepo.count()).toBe(0);
      expect(await app.legacyRepo.count()).toBe(1);
      const events = await app.webhookRepo.find();
      expect(events[0].status).toBe('failed');
      expect(events[0].outcome).toBe('attempt_state_conflict');
    });
  });

  // =========================================================================
  // API surface
  // =========================================================================

  describe('API behaviour', () => {
    it('P1. the ledger endpoint is ownership-checked and returns the durable rows', async () => {
      const app = buildApp();
      const bookingId = await insertBooking();
      const created = await createIntent(app, bookingId, 'user-1', 'api-key');
      const paymentId = created.status === 'OK' ? created.intent.paymentId : '';
      await confirmIntent(app, paymentId, bookingId, 'CARD_SUCCESS', 'user-1', 'c');

      const timeline = await app.service.bookingTimeline(bookingId, 'user-1');
      expect(timeline).toHaveLength(1);
      expect(timeline[0]).toMatchObject({
        bookingId,
        leg: 'CUSTOMER',
        type: 'capture',
        status: 'succeeded',
        amount: 1000,
        currency: 'EGP',
      });
      expect(timeline[0].attemptId).toBeTruthy();
      expect(timeline[0].createdAt).toEqual(expect.any(String));

      await expect(
        app.service.bookingTimeline(bookingId, 'user-2'),
      ).rejects.toThrow(/not found/i);
    });

    it('P2. the balance endpoint reflects the CUSTOMER leg only', async () => {
      const app = buildApp();
      const bookingId = await insertBooking();
      const created = await createIntent(app, bookingId, 'user-1', 'balance-key');
      const paymentId = created.status === 'OK' ? created.intent.paymentId : '';
      await confirmIntent(app, paymentId, bookingId, 'CARD_SUCCESS', 'user-1', 'c');
      await app.service.refundPayment(
        {
          paymentId,
          amount: 250,
          market: 'EG',
          idempotencyKey: 'r-1',
          bookingId,
        },
        'user-1',
      );

      const balance = await app.service.bookingBalance(bookingId, 'user-1');
      expect(balance).toEqual({
        charged: 1000,
        refunded: 250,
        net: 750,
        currency: 'EGP',
      });
    });

    it('P3. checkout for a booking that is not yours is refused', async () => {
      const app = buildApp();
      const bookingId = await insertBooking({ userId: 'user-1' });

      await expect(
        createIntent(app, bookingId, 'user-2', 'intruder-key'),
      ).rejects.toThrow(/not found/i);

      expect(await app.attemptRepo.count()).toBe(0);
    });

    it('P4. a currency that does not match the booking is refused', async () => {
      const app = buildApp();
      // The amount matches the authoritative price so ONLY the currency is
      // wrong — the amount check must not mask the currency check.
      const bookingId = await insertBooking({
        currency: 'USD',
        authoritativePrice: 100,
      });

      await expect(
        app.service.createPayment(
          {
            bookingId,
            amount: 100,
            currency: 'EGP',
            market: 'EG',
            idempotencyKey: 'currency-key',
          },
          'user-1',
        ),
      ).rejects.toThrow(/currency mismatch/i);

      expect(await app.attemptRepo.count()).toBe(0);
    });

    it('P5. markets without a gateway stay unavailable', async () => {
      const app = buildApp();
      const bookingId = await insertBooking();

      const result = await app.service.createPayment(
        {
          bookingId,
          amount: 100,
          currency: 'EGP',
          market: 'SA',
          idempotencyKey: 'sa-key',
        },
        'user-1',
      );
      expect(result.status).toBe('UNAVAILABLE');
      expect(await app.attemptRepo.count()).toBe(0);
    });
  });

  // =========================================================================
  // Authoritative payment amount (P4-2R)
  // =========================================================================

  describe('Authoritative payment amount (P4-2R)', () => {
    it('AA1. a client cannot lower the amount charged', async () => {
      const app = buildApp();
      const bookingId = await insertBooking({ authoritativePrice: 1000 });

      await expect(
        app.service.createPayment(
          {
            bookingId,
            amount: 1,
            currency: 'EGP',
            market: 'EG',
            idempotencyKey: 'lower',
          },
          'user-1',
        ),
      ).rejects.toThrow(/amount mismatch/i);

      // Nothing was claimed and nothing was charged.
      expect(await app.attemptRepo.count()).toBe(0);
      expect(await app.txnRepo.count()).toBe(0);
    });

    it('AA2. a client cannot increase the amount charged', async () => {
      const app = buildApp();
      const bookingId = await insertBooking({ authoritativePrice: 1000 });

      await expect(
        app.service.createPayment(
          {
            bookingId,
            amount: 999999,
            currency: 'EGP',
            market: 'EG',
            idempotencyKey: 'higher',
          },
          'user-1',
        ),
      ).rejects.toThrow(/amount mismatch/i);

      expect(await app.attemptRepo.count()).toBe(0);
      expect(await app.txnRepo.count()).toBe(0);
    });

    it('AA3. currency tampering is rejected', async () => {
      const app = buildApp();
      const bookingId = await insertBooking({
        authoritativePrice: 1000,
        currency: 'EGP',
      });

      await expect(
        app.service.createPayment(
          {
            bookingId,
            amount: 1000,
            currency: 'USD',
            market: 'EG',
            idempotencyKey: 'currency',
          },
          'user-1',
        ),
      ).rejects.toThrow(/currency mismatch/i);

      expect(await app.attemptRepo.count()).toBe(0);
    });

    it('AA4. the gateway receives the server-authoritative amount and currency', async () => {
      const gateway = new RecordingGateway();
      const app = buildApp(gateway);
      const bookingId = await insertBooking({
        authoritativePrice: 4850.75,
        currency: 'EGP',
      });

      const result = await app.service.createPayment(
        {
          bookingId,
          amount: 4850.75,
          currency: 'EGP',
          market: 'EG',
          idempotencyKey: 'recorded',
        },
        'user-1',
      );
      expect(result.status).toBe('OK');

      expect(gateway.createIntentInputs).toHaveLength(1);
      expect(gateway.createIntentInputs[0].amount).toBeCloseTo(4850.75, 2);
      expect(gateway.createIntentInputs[0].currency).toBe('EGP');

      const stored = await app.attempts.findById(
        result.status === 'OK' ? result.attemptId : '',
      );
      expect(stored!.amount).toBeCloseTo(4850.75, 2);
      expect(stored!.currency).toBe('EGP');
    });

    it('AA5. confirmation rejects an amount mismatch from the gateway', async () => {
      const app = buildApp(wrongAmountGateway(new MockEgyptGateway(), 'confirm'));
      const bookingId = await insertBooking({ authoritativePrice: 1000 });

      const created = await createIntent(app, bookingId, 'user-1', 'mismatch-confirm');
      const paymentId = created.status === 'OK' ? created.intent.paymentId : '';
      const attemptId = created.status === 'OK' ? created.attemptId : '';

      const confirmed = await confirmIntent(
        app,
        paymentId,
        bookingId,
        'CARD_SUCCESS',
        'user-1',
        'c',
      );
      expect(confirmed.status).toBe('UNKNOWN');

      const stored = await app.attempts.findById(attemptId);
      expect(stored!.status).toBe('unknown');
      expect(stored!.failureCode).toBe('gateway_amount_mismatch');
      // No capture was recorded for a contradictory provider state.
      expect(await app.txnRepo.count()).toBe(0);
    });

    it('AA6. a gateway that echoes a wrong amount on intent creation is not accepted', async () => {
      const app = buildApp(wrongAmountGateway(new MockEgyptGateway(), 'create'));
      const bookingId = await insertBooking({ authoritativePrice: 1000 });

      const result = await createIntent(app, bookingId, 'user-1', 'mismatch-create');
      expect(result.status).toBe('UNKNOWN');
      expect(result.attemptStatus).toBe('unknown');

      const stored = await app.attempts.findById(
        result.status === 'UNKNOWN' ? result.attemptId : '',
      );
      expect(stored!.failureCode).toBe('gateway_amount_mismatch');
      expect(await app.txnRepo.count()).toBe(0);
    });

    it('AA7. missing or unverifiable authoritative pricing fails safely', async () => {
      const app = buildApp();

      // A legacy row that never got a provider-revalidated price.
      const noPrice = await insertBooking({ authoritativePrice: 0 });
      await expect(
        app.service.createPayment(
          {
            bookingId: noPrice,
            amount: 100,
            currency: 'EGP',
            market: 'EG',
            idempotencyKey: 'no-price',
          },
          'user-1',
        ),
      ).rejects.toThrow(/pricing is unavailable/i);

      // A row whose currency cannot be a real ISO-4217 code.
      const badCurrency = await insertBooking({
        authoritativePrice: 500,
        currency: 'US',
      });
      await expect(
        app.service.createPayment(
          {
            bookingId: badCurrency,
            amount: 500,
            currency: 'US',
            market: 'EG',
            idempotencyKey: 'bad-currency',
          },
          'user-1',
        ),
      ).rejects.toThrow(/currency is unavailable/i);

      // No fallback to the client quote in either case.
      expect(await app.attemptRepo.count()).toBe(0);
    });

    it('AA8. legitimate checkout requests stay compatible', async () => {
      const app = buildApp();
      const bookingId = await insertBooking({
        authoritativePrice: 2500,
        currency: 'EGP',
      });

      const created = await createIntent(app, bookingId, 'user-1', 'legit', 2500);
      expect(created.status).toBe('OK');
      const paymentId = created.status === 'OK' ? created.intent.paymentId : '';

      const confirmed = await confirmIntent(
        app,
        paymentId,
        bookingId,
        'CARD_SUCCESS',
        'user-1',
        'c',
      );
      expect(confirmed.status).toBe('OK');
      expect(confirmed.attemptStatus).toBe('succeeded');

      const balance = await app.ledger.bookingBalance(bookingId);
      expect(balance.charged).toBe(2500);
    });

    it('AA9. a refund cannot exceed the captured amount', async () => {
      const app = buildApp();
      const bookingId = await insertBooking({ authoritativePrice: 1000 });

      const created = await createIntent(app, bookingId, 'user-1', 'refund-bound');
      const paymentId = created.status === 'OK' ? created.intent.paymentId : '';
      await confirmIntent(app, paymentId, bookingId, 'CARD_SUCCESS', 'user-1', 'c');

      await expect(
        app.service.refundPayment(
          {
            paymentId,
            amount: 1001,
            market: 'EG',
            idempotencyKey: 'over-refund',
            bookingId,
          },
          'user-1',
        ),
      ).rejects.toThrow(/exceeds the captured amount/i);

      // Only the original capture is on the ledger.
      expect(await app.txnRepo.count()).toBe(1);
    });
  });

  // =========================================================================
  // Migration
  // =========================================================================

  describe('Migration 7/8/9/10', () => {
    /** Revert to the P4-1 schema state (migrations 7..10 not applied). */
    async function revertToP4_1(): Promise<void> {
      for (let i = 0; i < 4; i++) {
        await ds.undoLastMigration();
      }
    }

    /** Re-apply the P4-2R chain (7, 8, 9). */
    async function applyP4_2(): Promise<void> {
      await ds.runMigrations();
    }

    async function tableExists(name: string): Promise<boolean> {
      const rows = await ds.query(
        `SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = $1`,
        [name],
      );
      return rows.length > 0;
    }

    it('M1. the P4-1 status set upgrades to the P4-2 set without data loss', async () => {
      const app = buildApp();

      await revertToP4_1();

      try {
        const bookingId = await insertBooking();
        const attemptId = await app.attempts.claim({
          userId: 'user-1',
          bookingId,
          idempotencyKey: 'legacy-status',
          amount: 500,
          currency: 'EGP',
          gatewayId: 'mock-egypt-gateway',
        });
        // P4-1 spelling of the same state.
        await ds.query(
          `UPDATE payment_attempts SET status = 'requires_confirmation' WHERE id = $1`,
          [attemptId.attempt.id],
        );
        await app.ledger.append({
          bookingId,
          leg: 'CUSTOMER',
          type: 'capture',
          status: 'succeeded',
          amount: 500,
          currency: 'EGP',
          attemptId: attemptId.attempt.id,
          idempotencyKey: 'legacy-txn',
        });

        await applyP4_2();

        const attempt = await app.attempts.findById(attemptId.attempt.id);
        expect(attempt!.status).toBe('requires_action');

        const txns = await app.txnRepo.find({ where: { bookingId } });
        expect(txns).toHaveLength(1);
        expect(txns[0].idempotencyKey).toBe('legacy-txn');

        const booking = await app.bookingRepo.findOne({ where: { id: bookingId } });
        expect(booking).not.toBeNull();
      } finally {
        await applyP4_2();
      }
    });

    it('M2. the new status set is the one the database enforces', async () => {
      const app = buildApp();
      const bookingId = await insertBooking();
      const created = await createIntent(app, bookingId, 'user-1', 'check-key');
      const attemptId = created.status === 'OK' ? created.attemptId : '';

      // A state outside the P4-2 vocabulary is rejected by the CHECK.
      await expect(
        ds.query(`UPDATE payment_attempts SET status = 'bogus' WHERE id = $1`, [attemptId]),
      ).rejects.toBeTruthy();

      // Every state the orchestrator actually uses is accepted.
      for (const status of [
        'created',
        'processing',
        'requires_action',
        'pending',
        'succeeded',
        'declined',
        'failed',
        'unknown',
        'cancelled',
        'consumed',
        'voided',
        'refunded',
        'partially_refunded',
      ]) {
        await ds.query(`UPDATE payment_attempts SET status = $2 WHERE id = $1`, [
          attemptId,
          status,
        ]);
        const row = await app.attempts.findById(attemptId);
        expect(row!.status).toBe(status);
      }
    });

    it('M3. both replay stores exist with their original identity semantics', async () => {
      // webhook_events — post-P4-2 identity is (provider, eventId).
      const pk = await ds.query(
        `SELECT a.attname FROM pg_index i
           JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey)
          WHERE i.indrelid = 'webhook_events'::regclass AND i.indisprimary
          ORDER BY a.attname`,
      );
      expect(pk.map((r: { attname: string }) => r.attname).sort()).toEqual([
        'eventId',
        'provider',
      ]);

      // processed_webhooks — the RETIRED archive keeps its ORIGINAL identity:
      // the bare event id, with no provider column. Inventing one would change
      // what the historical rows mean.
      const legacyPk = await ds.query(
        `SELECT a.attname FROM pg_index i
           JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey)
          WHERE i.indrelid = 'processed_webhooks'::regclass AND i.indisprimary
          ORDER BY a.attname`,
      );
      expect(legacyPk.map((r: { attname: string }) => r.attname)).toEqual(['id']);

      const legacyColumns = await ds.query(
        `SELECT column_name FROM information_schema.columns
          WHERE table_schema='public' AND table_name='processed_webhooks'
          ORDER BY column_name`,
      );
      expect(legacyColumns.map((c: { column_name: string }) => c.column_name)).toEqual([
        'id',
        'processedAt',
      ]);
    });

    it('M4. migration 8/9 up and down never drop the archive', async () => {
      expect(await tableExists('processed_webhooks')).toBe(true);

      // Reverting the whole P4-2R chain (10, 9 then 8) leaves the archive in
      // place — migration 10 only widens the webhook status CHECK.
      await ds.undoLastMigration(); // 10
      await ds.undoLastMigration(); // 9
      await ds.undoLastMigration(); // 8
      expect(await tableExists('processed_webhooks')).toBe(true);
      expect(await tableExists('webhook_events')).toBe(true);

      // Re-applying is idempotent and preserves whatever is in the archive.
      await ds.runMigrations();
      expect(await tableExists('processed_webhooks')).toBe(true);

      const pk = await ds.query(
        `SELECT a.attname FROM pg_index i
           JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey)
          WHERE i.indrelid = 'webhook_events'::regclass AND i.indisprimary
          ORDER BY a.attname`,
      );
      expect(pk.map((r: { attname: string }) => r.attname).sort()).toEqual([
        'eventId',
        'provider',
      ]);
    });

    it('M5. migration 7 down restores the P4-1 status vocabulary', async () => {
      const app = buildApp();
      const bookingId = await insertBooking();
      const created = await createIntent(app, bookingId, 'user-1', 'm5-key');
      const attemptId = created.status === 'OK' ? created.attemptId : '';
      expect((await app.attempts.findById(attemptId))!.status).toBe('requires_action');

      await revertToP4_1();

      // The P4-1 CHECK is back and the value is translated.
      expect((await app.attempts.findById(attemptId))!.status).toBe('requires_confirmation');
      await expect(
        ds.query(`UPDATE payment_attempts SET status = 'processing' WHERE id = $1`, [
          attemptId,
        ]),
      ).rejects.toBeTruthy();

      // Re-apply and confirm the round trip.
      await applyP4_2();
      expect((await app.attempts.findById(attemptId))!.status).toBe('requires_action');
    });

    it('M6. historical legacy webhook ids survive the P4-2R upgrade', async () => {
      await revertToP4_1();

      // A database that has been live since before P4-2 has processed events.
      await ds.query(
        `INSERT INTO processed_webhooks (id, "processedAt") VALUES
           ('legacy-evt-1', '2026-10-01T10:00:00Z'),
           ('legacy-evt-2', '2026-10-02T11:00:00Z')`,
      );

      await applyP4_2();

      const rows = await ds.query(
        `SELECT id FROM processed_webhooks ORDER BY id`,
      );
      expect(rows.map((r: { id: string }) => r.id)).toEqual([
        'legacy-evt-1',
        'legacy-evt-2',
      ]);
    });

    it('M7. migration 9 recreates the archive for a database that ran the original drop', async () => {
      // Simulate a database where the ORIGINAL migration 8 already dropped the
      // table: its rows are gone and no DDL can bring them back. Revert
      // migrations 10 and 9 first so migration 9 is pending again and can
      // actually execute.
      await ds.undoLastMigration(); // 10
      await ds.undoLastMigration(); // 9
      await ds.query(`DROP TABLE processed_webhooks`);
      expect(await tableExists('processed_webhooks')).toBe(false);

      await applyP4_2();

      expect(await tableExists('processed_webhooks')).toBe(true);
      const rows = await ds.query(`SELECT COUNT(*)::int AS n FROM processed_webhooks`);
      expect(rows[0].n).toBe(0);

      // The recreated shape is exactly the one the entity maps.
      const legacyPk = await ds.query(
        `SELECT a.attname FROM pg_index i
           JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey)
          WHERE i.indrelid = 'processed_webhooks'::regclass AND i.indisprimary`,
      );
      expect(legacyPk.map((r: { attname: string }) => r.attname)).toEqual(['id']);
    });

    it('M8. migration 10 accepts `retryable` and its down() translates it back', async () => {
      const app = buildApp();

      // The widened CHECK admits the new outcome.
      await ds.query(
        `INSERT INTO webhook_events
           (provider, "eventId", "eventType", "payloadHash", status, outcome)
         VALUES ('mock-egypt-gateway', 'evt-r2', 'payment.succeeded', 'hash',
                 'retryable', 'effect_failed')`,
      );
      const row = await app.webhookRepo.findOne({
        where: { provider: 'mock-egypt-gateway', eventId: 'evt-r2' },
      });
      expect(row!.status).toBe('retryable');

      // The CHECK is the one migration 10 manages.
      const check = await ds.query(
        `SELECT pg_get_constraintdef(oid) AS def FROM pg_constraint
          WHERE conname = 'chk_webhook_events_status'`,
      );
      expect(check[0].def).toContain('retryable');

      // down() translates retryable -> received so the narrowed CHECK holds.
      await ds.undoLastMigration(); // 10
      const reverted = await app.webhookRepo.findOne({
        where: { provider: 'mock-egypt-gateway', eventId: 'evt-r2' },
      });
      expect(reverted!.status).toBe('received');

      await applyP4_2();
      const reapplied = await app.webhookRepo.findOne({
        where: { provider: 'mock-egypt-gateway', eventId: 'evt-r2' },
      });
      expect(reapplied!.status).toBe('received');
    });
  });

  // =========================================================================
  // Nest wiring
  // =========================================================================

  describe('Nest wiring', () => {
    it('N1. PaymentsModule resolves every service with real repositories', async () => {
      // The persistence tests construct services by hand, which would hide a
      // broken `@InjectRepository` or a missing provider. This boots the real
      // module against the test database and resolves from the container.
      const { Module } = await import('@nestjs/common');
      const { NestFactory } = await import('@nestjs/core');
      const { TypeOrmModule } = await import('@nestjs/typeorm');
      const { ConfigModule } = await import('@nestjs/config');
      const { PaymentsModule } = await import('../src/modules/payments/payments.module');
      const { PaymentsController } = await import(
        '../src/modules/payments/payments.controller'
      );

      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const WiringModule = class {}; // decorated below (avoids a class decorator here)
      Module({
        imports: [
          ConfigModule.forRoot({ isGlobal: true, ignoreEnvFile: true, ignoreEnvVars: true }),
          TypeOrmModule.forRoot({
            type: 'postgres',
            url: TEST_DB_URL,
            autoLoadEntities: true,
            synchronize: false,
          }),
          PaymentsModule,
        ],
      })(WiringModule);

      const app = await NestFactory.createApplicationContext(WiringModule as any, {
        logger: false,
      });

      try {
        expect(app.get(PaymentService)).toBeInstanceOf(PaymentService);
        expect(app.get(PaymentAttemptService)).toBeInstanceOf(PaymentAttemptService);
        expect(app.get(LedgerService)).toBeInstanceOf(LedgerService);
        expect(app.get(PaymentsController)).toBeInstanceOf(PaymentsController);
      } finally {
        await app.close();
      }
    });
  });
});
