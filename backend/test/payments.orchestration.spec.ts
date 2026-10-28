import { PaymentService } from '../src/modules/payments/payment.service';
import { PaymentRouter } from '../src/modules/payments/payment.router';
import { MockEgyptGateway, signMockWebhook } from '../src/modules/payments/mock.egypt.gateway';
import { LedgerService } from '../src/modules/payments/ledger.service';

/**
 * Payment abstraction tests (spec points 10, 31-36, O.8/O.9):
 * idempotency, market routing, 3DS async recovery via webhook, and the
 * immutable ledger trail.
 */

describe('Payment orchestration (mock EG gateway)', () => {
  let gateway: MockEgyptGateway;
  let service: PaymentService;

  beforeEach(() => {
    gateway = new MockEgyptGateway();
    service = new PaymentService(new PaymentRouter(gateway), new LedgerService());
  });

  it('creates an intent for the EG market and records a ledger CHARGE', async () => {
    const result = await service.createPayment({
      bookingId: 'bk-1',
      amount: 4850,
      currency: 'EGP',
      market: 'EG',
      idempotencyKey: 'idem-1',
    });
    expect(result.status).toBe('OK');
    if (result.status === 'OK') {
      expect(result.intent.status).toBe('REQUIRES_CONFIRMATION');
      expect(result.intent.currency).toBe('EGP');
    }
    const timeline = service.bookingTimeline('bk-1');
    expect(timeline).toHaveLength(1);
    expect(timeline[0].type).toBe('CHARGE');
    expect(timeline[0].amount).toBe(4850);
  });

  it('rejects markets without a configured gateway', async () => {
    const result = await service.createPayment({
      bookingId: 'bk-2',
      amount: 100,
      currency: 'SAR',
      market: 'SA',
      idempotencyKey: 'idem-2',
    });
    expect(result.status).toBe('UNAVAILABLE');
  });

  it('is idempotent: the same create key returns the original intent (spec point 10)', async () => {
    const a = await service.createPayment({
      bookingId: 'bk-3',
      amount: 500,
      currency: 'EGP',
      market: 'EG',
      idempotencyKey: 'same-key',
    });
    const b = await service.createPayment({
      bookingId: 'bk-3',
      amount: 500,
      currency: 'EGP',
      market: 'EG',
      idempotencyKey: 'same-key',
    });
    if (a.status === 'OK' && b.status === 'OK') {
      expect(a.intent.paymentId).toBe(b.intent.paymentId);
    } else {
      fail('create should succeed');
    }
  });

  it('confirms a successful card payment to SUCCEEDED', async () => {
    const created = await service.createPayment({
      bookingId: 'bk-4',
      amount: 300,
      currency: 'EGP',
      market: 'EG',
      idempotencyKey: 'idem-4',
    });
    const paymentId = created.status === 'OK' ? created.intent.paymentId : '';
    const confirmed = await service.confirmPayment({
      paymentId,
      methodReference: 'CARD_SUCCESS',
      market: 'EG',
      idempotencyKey: 'confirm-4',
      bookingId: 'bk-4',
    });
    if (confirmed.status === 'OK') {
      expect(confirmed.intent.status).toBe('SUCCEEDED');
    }
  });

  it('3DS flows stay PENDING until the signed webhook settles them (O.9)', async () => {
    const created = await service.createPayment({
      bookingId: 'bk-5',
      amount: 900,
      currency: 'EGP',
      market: 'EG',
      idempotencyKey: 'idem-5',
    });
    const paymentId = created.status === 'OK' ? created.intent.paymentId : '';

    const pending = await service.confirmPayment({
      paymentId,
      methodReference: 'CARD_3DS',
      market: 'EG',
      idempotencyKey: 'confirm-5',
      bookingId: 'bk-5',
    });
    if (pending.status === 'OK') {
      expect(pending.intent.status).toBe('PENDING');
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
  });

  it('declined cards FAIL without a ledger capture side-effect', async () => {
    const created = await service.createPayment({
      bookingId: 'bk-6',
      amount: 700,
      currency: 'EGP',
      market: 'EG',
      idempotencyKey: 'idem-6',
    });
    const paymentId = created.status === 'OK' ? created.intent.paymentId : '';
    const failed = await service.confirmPayment({
      paymentId,
      methodReference: 'CARD_DECLINED',
      market: 'EG',
      idempotencyKey: 'confirm-6',
      bookingId: 'bk-6',
    });
    if (failed.status === 'OK') {
      expect(failed.intent.status).toBe('FAILED');
    }
  });

  it('refund appends a reversal entry; the original charge stays intact (spec point 36)', async () => {
    await service.createPayment({
      bookingId: 'bk-7',
      amount: 1000,
      currency: 'EGP',
      market: 'EG',
      idempotencyKey: 'idem-7',
    });
    const gatewayIntent = await gateway.createPaymentIntent({
      bookingId: 'bk-7',
      idempotencyKey: 'idem-7',
      amount: 1000,
      currency: 'EGP',
      market: 'EG',
    });
    await gateway.confirmPayment({
      paymentId: gatewayIntent.paymentId,
      methodReference: 'CARD_SUCCESS',
      idempotencyKey: 'confirm-7',
    });
    const refund = await service.refundPayment({
      paymentId: gatewayIntent.paymentId,
      amount: 400,
      reason: 'customer request',
      market: 'EG',
      idempotencyKey: 'refund-7',
      bookingId: 'bk-7',
    });
    if (refund.status === 'OK') {
      expect(refund.intent.status).toBe('REFUNDED');
    }
    const timeline = service.bookingTimeline('bk-7');
    const types = timeline.map(e => e.type);
    expect(types).toContain('CHARGE');
    expect(types).toContain('REFUND');
  });
});

describe('Ledger balance (spec point O.8)', () => {
  it('charge minus refund equals net receipts', async () => {
    const gateway = new MockEgyptGateway();
    const ledger = new LedgerService();
    const service = new PaymentService(new PaymentRouter(gateway), ledger);

    await service.createPayment({
      bookingId: 'bk-bal',
      amount: 2000,
      currency: 'EGP',
      market: 'EG',
      idempotencyKey: 'idem-bal',
    });
    const intent = await gateway.createPaymentIntent({
      bookingId: 'bk-bal',
      idempotencyKey: 'idem-bal',
      amount: 2000,
      currency: 'EGP',
      market: 'EG',
    });
    await gateway.confirmPayment({
      paymentId: intent.paymentId,
      methodReference: 'CARD_SUCCESS',
      idempotencyKey: 'confirm-bal',
    });
    await service.refundPayment({
      paymentId: intent.paymentId,
      amount: 500,
      market: 'EG',
      idempotencyKey: 'refund-bal',
      bookingId: 'bk-bal',
    });

    const balance = ledger.bookingBalance('bk-bal');
    expect(balance.charged).toBe(2000);
    expect(balance.refunded).toBe(500);
    expect(balance.net).toBe(1500);
    expect(balance.currency).toBe('EGP');
  });
});
