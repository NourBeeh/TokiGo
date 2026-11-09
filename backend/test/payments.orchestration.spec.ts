import 'reflect-metadata';
import { join } from 'path';
import { DataSource } from 'typeorm';

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

jest.setTimeout(60_000);

/**
 * End-to-end payment orchestration against a REAL PostgreSQL database.
 *
 * P4-0 kept this suite database-free with an in-memory ledger and fake booking
 * ids. P4-2 makes PostgreSQL the source of truth, so the orchestration is now
 * exercised through the durable attempt/ledger/webhook tables. The per-case
 * constraint and concurrency assertions live in `p4.persistence.spec.ts`;
 * this suite covers the flows end to end.
 *
 * Skipped unless P4_TEST_DB_URL is set:
 *   P4_TEST_DB_URL=postgres://user:pass@127.0.0.1:5432/tokigo_p4_test \
 *     npx jest test/payments.orchestration.spec.ts
 */

const TEST_DB_URL = process.env.P4_TEST_DB_URL;
const describeDb = TEST_DB_URL ? describe : describe.skip;

process.env.WEBHOOK_SIGNING_KEY = process.env.WEBHOOK_SIGNING_KEY ?? 'test-signing-key';

describeDb('Payment orchestration (mock EG gateway, PostgreSQL-backed)', () => {
  let ds: DataSource;
  let gateway: MockEgyptGateway;
  let service: PaymentService;
  let ledger: LedgerService;
  let attempts: PaymentAttemptService;

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
    gateway = new MockEgyptGateway();
    const attemptRepo = ds.getRepository(PaymentAttempt);
    const txnRepo = ds.getRepository(PaymentTransaction);
    const webhookRepo = ds.getRepository(WebhookEvent);
    const bookingRepo = ds.getRepository(Booking);
    const legacyRepo = ds.getRepository(ProcessedWebhook);
    attempts = new PaymentAttemptService(attemptRepo);
    ledger = new LedgerService(txnRepo);
    service = new PaymentService(
      new PaymentRouter(gateway),
      ledger,
      attempts,
      bookingRepo,
      webhookRepo,
      legacyRepo,
    );
  });

  async function newBooking(overrides: Record<string, unknown> = {}): Promise<string> {
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

  it('creates an intent for the EG market and records the durable attempt', async () => {
    const bookingId = await newBooking({ authoritativePrice: 4850 });

    const result = await service.createPayment(
      {
        bookingId,
        amount: 4850,
        currency: 'EGP',
        market: 'EG',
        idempotencyKey: 'idem-1',
      },
      'user-1',
    );
    expect(result.status).toBe('OK');
    if (result.status === 'OK') {
      expect(result.intent.status).toBe('REQUIRES_CONFIRMATION');
      expect(result.intent.currency).toBe('EGP');
      expect(result.attemptStatus).toBe('requires_action');
    }

    // Creating an intent moves no money: the ledger stays empty until a
    // confirmed capture (spec point: never record a capture from intent alone).
    const timeline = await service.bookingTimeline(bookingId, 'user-1');
    expect(timeline).toHaveLength(0);

    const stored = await attempts.findById(
      result.status === 'OK' ? result.attemptId : '',
    );
    expect(stored!.status).toBe('requires_action');
    expect(stored!.gatewayRef).toBe(result.status === 'OK' ? result.intent.paymentId : null);
  });

  it('rejects markets without a configured gateway', async () => {
    const bookingId = await newBooking({ currency: 'SAR' });

    const result = await service.createPayment(
      {
        bookingId,
        amount: 100,
        currency: 'SAR',
        market: 'SA',
        idempotencyKey: 'idem-2',
      },
      'user-1',
    );
    expect(result.status).toBe('UNAVAILABLE');
  });

  it('is idempotent: the same create key returns the original intent (spec point 10)', async () => {
    const bookingId = await newBooking({ authoritativePrice: 500 });

    const a = await service.createPayment(
      {
        bookingId,
        amount: 500,
        currency: 'EGP',
        market: 'EG',
        idempotencyKey: 'same-key',
      },
      'user-1',
    );
    const b = await service.createPayment(
      {
        bookingId,
        amount: 500,
        currency: 'EGP',
        market: 'EG',
        idempotencyKey: 'same-key',
      },
      'user-1',
    );
    if (a.status === 'OK' && b.status === 'OK') {
      expect(a.intent.paymentId).toBe(b.intent.paymentId);
      expect(a.attemptId).toBe(b.attemptId);
    } else {
      fail('create should succeed');
    }
  });

  it('confirms a successful card payment to SUCCEEDED and records the capture', async () => {
    const bookingId = await newBooking({ authoritativePrice: 300 });
    const created = await service.createPayment(
      {
        bookingId,
        amount: 300,
        currency: 'EGP',
        market: 'EG',
        idempotencyKey: 'idem-4',
      },
      'user-1',
    );
    const paymentId = created.status === 'OK' ? created.intent.paymentId : '';

    const confirmed = await service.confirmPayment(
      {
        paymentId,
        methodReference: 'CARD_SUCCESS',
        market: 'EG',
        idempotencyKey: 'confirm-4',
        bookingId,
      },
      'user-1',
    );
    expect(confirmed.status).toBe('OK');
    if (confirmed.status === 'OK') {
      expect(confirmed.intent?.status).toBe('SUCCEEDED');
      expect(confirmed.attemptStatus).toBe('succeeded');
    }

    const timeline = await service.bookingTimeline(bookingId, 'user-1');
    expect(timeline).toHaveLength(1);
    expect(timeline[0]).toMatchObject({
      leg: 'CUSTOMER',
      type: 'capture',
      status: 'succeeded',
      amount: 300,
    });
  });

  it('3DS flows stay PENDING until the signed webhook settles them (O.9)', async () => {
    const bookingId = await newBooking({ authoritativePrice: 900 });
    const created = await service.createPayment(
      {
        bookingId,
        amount: 900,
        currency: 'EGP',
        market: 'EG',
        idempotencyKey: 'idem-5',
      },
      'user-1',
    );
    const paymentId = created.status === 'OK' ? created.intent.paymentId : '';

    const pending = await service.confirmPayment(
      {
        paymentId,
        methodReference: 'CARD_3DS',
        market: 'EG',
        idempotencyKey: 'confirm-5',
        bookingId,
      },
      'user-1',
    );
    expect(pending.status).toBe('OK');
    if (pending.status === 'OK') {
      expect(pending.intent?.status).toBe('PENDING');
      expect(pending.attemptStatus).toBe('pending');
    }

    // Wrong signature is rejected (spec point 11).
    const bad = await service.handleWebhook({
      id: 'evt-1',
      paymentId,
      type: 'payment.succeeded',
      signature: 'tampered',
      occurredAt: new Date().toISOString(),
    });
    expect(bad.status).toBe('REJECTED');

    // Correct signed webhook settles the async payment.
    const good = await service.handleWebhook({
      id: 'evt-1',
      paymentId,
      type: 'payment.succeeded',
      signature: signMockWebhook({
        id: 'evt-1',
        paymentId,
        type: 'payment.succeeded',
        occurredAt: new Date().toISOString(),
      }),
      occurredAt: new Date().toISOString(),
    });
    expect(good.status).toBe('PROCESSED');

    const retrieved = await gateway.retrievePayment(paymentId);
    expect(retrieved?.status).toBe('SUCCEEDED');

    const timeline = await service.bookingTimeline(bookingId, 'user-1');
    expect(timeline).toHaveLength(1);
    expect(timeline[0].status).toBe('succeeded');
  });

  it('declined cards FAIL without a successful capture side-effect', async () => {
    const bookingId = await newBooking({ authoritativePrice: 700 });
    const created = await service.createPayment(
      {
        bookingId,
        amount: 700,
        currency: 'EGP',
        market: 'EG',
        idempotencyKey: 'idem-6',
      },
      'user-1',
    );
    const paymentId = created.status === 'OK' ? created.intent.paymentId : '';

    const failed = await service.confirmPayment(
      {
        paymentId,
        methodReference: 'CARD_DECLINED',
        market: 'EG',
        idempotencyKey: 'confirm-6',
        bookingId,
      },
      'user-1',
    );
    expect(failed.status).toBe('OK');
    if (failed.status === 'OK') {
      expect(failed.intent?.status).toBe('FAILED');
      expect(failed.attemptStatus).toBe('declined');
    }

    // The decline is auditable, but it is NOT a successful capture.
    const timeline = await service.bookingTimeline(bookingId, 'user-1');
    expect(timeline).toHaveLength(1);
    expect(timeline[0].status).toBe('failed');

    const balance = await ledger.bookingBalance(bookingId);
    expect(balance.charged).toBe(0);
  });

  it('refund appends a reversal entry; the original capture stays intact (spec point 36)', async () => {
    const bookingId = await newBooking();
    const created = await service.createPayment(
      {
        bookingId,
        amount: 1000,
        currency: 'EGP',
        market: 'EG',
        idempotencyKey: 'idem-7',
      },
      'user-1',
    );
    const paymentId = created.status === 'OK' ? created.intent.paymentId : '';
    await service.confirmPayment(
      {
        paymentId,
        methodReference: 'CARD_SUCCESS',
        market: 'EG',
        idempotencyKey: 'confirm-7',
        bookingId,
      },
      'user-1',
    );

    const refund = await service.refundPayment(
      {
        paymentId,
        amount: 400,
        reason: 'customer request',
        market: 'EG',
        idempotencyKey: 'refund-7',
        bookingId,
      },
      'user-1',
    );
    expect(refund.status).toBe('OK');

    const timeline = await service.bookingTimeline(bookingId, 'user-1');
    const types = timeline.map(e => e.type);
    expect(types).toContain('capture');
    expect(types).toContain('refund');
    expect(timeline[0].status).toBe('succeeded');
  });
});

describeDb('Ledger balance (spec point O.8)', () => {
  let ds: DataSource;
  let service: PaymentService;
  let ledger: LedgerService;

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
    const gateway = new MockEgyptGateway();
    ledger = new LedgerService(ds.getRepository(PaymentTransaction));
    service = new PaymentService(
      new PaymentRouter(gateway),
      ledger,
      new PaymentAttemptService(ds.getRepository(PaymentAttempt)),
      ds.getRepository(Booking),
      ds.getRepository(WebhookEvent),
      ds.getRepository(ProcessedWebhook),
    );
  });

  it('charge minus refund equals net receipts', async () => {
    const row = {
      userId: 'user-1',
      offerId: 'offer-bal',
      providerId: 'duffel-flight',
      providerName: 'Duffel Flights',
      type: 'flight',
      status: 'prepared',
      currency: 'EGP',
      authoritativePrice: 2000,
    };
    const inserted = await ds.query(
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
    const bookingId = inserted[0].id as string;

    const created = await service.createPayment(
      {
        bookingId,
        amount: 2000,
        currency: 'EGP',
        market: 'EG',
        idempotencyKey: 'idem-bal',
      },
      'user-1',
    );
    const paymentId = created.status === 'OK' ? created.intent.paymentId : '';
    await service.confirmPayment(
      {
        paymentId,
        methodReference: 'CARD_SUCCESS',
        market: 'EG',
        idempotencyKey: 'confirm-bal',
        bookingId,
      },
      'user-1',
    );
    await service.refundPayment(
      {
        paymentId,
        amount: 500,
        market: 'EG',
        idempotencyKey: 'refund-bal',
        bookingId,
      },
      'user-1',
    );

    const balance = await ledger.bookingBalance(bookingId);
    expect(balance.charged).toBe(2000);
    expect(balance.refunded).toBe(500);
    expect(balance.net).toBe(1500);
    expect(balance.currency).toBe('EGP');
  });
});
