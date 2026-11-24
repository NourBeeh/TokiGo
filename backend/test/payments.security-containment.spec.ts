import { ForbiddenException } from '@nestjs/common';

import { PaymentService } from '../src/modules/payments/payment.service';
import { PaymentRouter } from '../src/modules/payments/payment.router';
import { MockEgyptGateway } from '../src/modules/payments/mock.egypt.gateway';
import { PaymentStatus } from '../src/modules/payments/payment.gateway';

/**
 * Phase 3C.1 — payment security containment.
 *
 * These tests pin the boundaries that make a payment authoritative:
 *  - the mock gateway/router can never start or act in production;
 *  - `CARD_SUCCESS` is a test instruction, never a production payment method;
 *  - a payment is bound to the booking, user, amount, currency and accepted
 *    price version — an old-price attempt can never settle a newer booking;
 *  - refunds are admin-only, server-verified, policy-gated and capped by the
 *    remaining refundable amount.
 */

const SIGNING_KEY = 'containment-test-signing-key-0123456789';

function baseBooking(overrides: Record<string, any> = {}) {
  return {
    id: 'b1',
    userId: 'u1',
    status: 'prepared',
    authoritativePrice: 100,
    currency: 'EGP',
    priceVersion: 'price-v1-current',
    ...overrides,
  };
}

function baseAttempt(overrides: Record<string, any> = {}) {
  return {
    id: 'a1',
    bookingId: 'b1',
    userId: 'u1',
    status: 'requires_action',
    amount: 100,
    currency: 'EGP',
    priceVersion: 'price-v1-current',
    gatewayId: 'mock-egypt-gateway',
    gatewayRef: 'pi_1',
    verifiedAt: null,
    ...overrides,
  };
}

function intent(status: PaymentStatus = 'SUCCEEDED') {
  return {
    paymentId: 'pi_1',
    bookingId: 'b1',
    amount: 100,
    currency: 'EGP',
    status,
    clientSecret: 'secret',
    createdAt: new Date().toISOString(),
  };
}

function buildService(
  options: {
    gateway?: Record<string, any>;
    booking?: Record<string, any>;
    attempt?: Record<string, any> | null;
    refunds?: Record<string, any>[];
  } = {},
) {
  const gateway =
    options.gateway ??
    ({
      gatewayId: 'mock-egypt-gateway',
      supportsMarket: ['EG'],
      createPaymentIntent: jest.fn().mockResolvedValue(intent('REQUIRES_CONFIRMATION')),
      confirmPayment: jest.fn().mockResolvedValue(intent('SUCCEEDED')),
      refundPayment: jest.fn().mockResolvedValue(intent('REFUNDED')),
      retrievePayment: jest.fn().mockResolvedValue(intent('SUCCEEDED')),
      verifyWebhook: jest.fn().mockReturnValue(true),
    } as Record<string, any>);

  const router = {
    forMarket: jest.fn().mockReturnValue(gateway),
    listGateways: jest
      .fn()
      .mockReturnValue([{ gatewayId: gateway.gatewayId, markets: ['EG'] }]),
  };
  const ledger = {
    append: jest.fn().mockResolvedValue({}),
    forAttempt: jest.fn().mockResolvedValue(options.refunds ?? []),
    forBooking: jest.fn().mockResolvedValue([]),
    bookingBalance: jest.fn(),
  };
  const attempt =
    options.attempt === undefined ? baseAttempt() : options.attempt;
  const attempts = {
    claim: jest.fn(),
    transition: jest
      .fn()
      .mockImplementation(async (_id: string, to: string, patch: any = {}) => ({
        outcome: 'transitioned',
        attempt: { ...(attempt ?? baseAttempt()), status: to, ...patch },
      })),
    findById: jest.fn().mockResolvedValue(attempt),
    findOwned: jest.fn().mockResolvedValue(attempt),
    findByGatewayRef: jest.fn().mockResolvedValue(attempt),
    listForBooking: jest.fn().mockResolvedValue([]),
  };
  const bookings = {
    findOne: jest.fn().mockResolvedValue(options.booking ?? baseBooking()),
    update: jest.fn().mockResolvedValue({ affected: 1 }),
  };

  const service = new PaymentService(
    router as any,
    ledger as any,
    attempts as any,
    bookings as any,
    {} as any,
    {} as any,
  );
  return { service, gateway, router, ledger, attempts, bookings };
}

/** Run a block with `NODE_ENV=production` and no Jest worker marker. */
async function inProduction<T>(fn: () => Promise<T> | T): Promise<T> {
  const previousNodeEnv = process.env.NODE_ENV;
  const previousWorker = process.env.JEST_WORKER_ID;
  process.env.NODE_ENV = 'production';
  delete process.env.JEST_WORKER_ID;
  try {
    return await fn();
  } finally {
    if (previousNodeEnv === undefined) delete process.env.NODE_ENV;
    else process.env.NODE_ENV = previousNodeEnv;
    if (previousWorker === undefined) delete process.env.JEST_WORKER_ID;
    else process.env.JEST_WORKER_ID = previousWorker;
  }
}

describe('Payment security containment', () => {
  const originalSigningKey = process.env.WEBHOOK_SIGNING_KEY;

  beforeAll(() => {
    process.env.WEBHOOK_SIGNING_KEY = SIGNING_KEY;
  });

  afterAll(() => {
    if (originalSigningKey === undefined) delete process.env.WEBHOOK_SIGNING_KEY;
    else process.env.WEBHOOK_SIGNING_KEY = originalSigningKey;
  });

  describe('production fail-closed gateway', () => {
    it('refuses to construct the payment router in production', async () => {
      await inProduction(() => {
        expect(() => new PaymentRouter({} as any)).toThrow(
          /No verified production payment gateway/,
        );
      });
    });

    it('refuses to construct the mock gateway in production', async () => {
      await inProduction(() => {
        expect(() => new MockEgyptGateway()).toThrow(/test-only/);
      });
    });

    it('refuses every mock financial operation even on a pre-built instance', async () => {
      const gateway = new MockEgyptGateway();

      await inProduction(async () => {
        await expect(
          gateway.createPaymentIntent({
            bookingId: 'b1',
            idempotencyKey: 'k',
            amount: 100,
            currency: 'EGP',
            market: 'EG',
          }),
        ).rejects.toThrow(/test-only/);
        await expect(
          gateway.confirmPayment({
            paymentId: 'pi_1',
            methodReference: 'CARD_SUCCESS',
            idempotencyKey: 'k',
          }),
        ).rejects.toThrow(/test-only/);
        await expect(
          gateway.refundPayment({
            paymentId: 'pi_1',
            amount: 100,
            idempotencyKey: 'k',
          }),
        ).rejects.toThrow(/test-only/);
        expect(() => gateway.settlePending('pi_1')).toThrow(/test-only/);
      });
    });

    it('still allows the mock gateway in the test runtime', () => {
      expect(() => new MockEgyptGateway()).not.toThrow();
    });
  });

  describe('createPayment — accepted price version', () => {
    it('refuses to charge a booking with no accepted price version', async () => {
      const { service, gateway, attempts } = buildService({
        booking: baseBooking({ priceVersion: null }),
      });

      await expect(
        service.createPayment(
          {
            bookingId: 'b1',
            amount: 100,
            currency: 'EGP',
            market: 'EG',
            idempotencyKey: 'k1',
          },
          'u1',
        ),
      ).rejects.toMatchObject({ response: { code: 'PRICE_CHANGED' } });

      expect(attempts.claim).not.toHaveBeenCalled();
      expect(gateway.createPaymentIntent).not.toHaveBeenCalled();
    });

    it('refuses to reuse an attempt created for an older price version', async () => {
      const { service, gateway, attempts } = buildService({
        booking: baseBooking({ priceVersion: 'price-v1-new' }),
        attempt: baseAttempt({ priceVersion: 'price-v1-old' }),
      });
      attempts.claim.mockResolvedValue({
        attempt: baseAttempt({ priceVersion: 'price-v1-old' }),
        created: false,
      });

      await expect(
        service.createPayment(
          {
            bookingId: 'b1',
            amount: 100,
            currency: 'EGP',
            market: 'EG',
            idempotencyKey: 'k1',
          },
          'u1',
        ),
      ).rejects.toMatchObject({ response: { code: 'PRICE_CHANGED' } });

      expect(gateway.createPaymentIntent).not.toHaveBeenCalled();
    });

    it('refuses to charge an expired booking', async () => {
      const { service, gateway, attempts } = buildService({
        booking: baseBooking({ status: 'expired' }),
      });

      await expect(
        service.createPayment(
          {
            bookingId: 'b1',
            amount: 100,
            currency: 'EGP',
            market: 'EG',
            idempotencyKey: 'k1',
          },
          'u1',
        ),
      ).rejects.toMatchObject({ response: { code: 'BOOKING_NOT_PAYABLE' } });

      expect(attempts.claim).not.toHaveBeenCalled();
      expect(gateway.createPaymentIntent).not.toHaveBeenCalled();
    });
  });

  describe('confirmPayment — server-authoritative evidence', () => {
    it('rejects the test-only CARD_SUCCESS method in production before any state change', async () => {
      const { service, gateway, attempts } = buildService();

      await inProduction(async () => {
        await expect(
          service.confirmPayment(
            {
              paymentId: 'pi_1',
              methodReference: 'CARD_SUCCESS',
              market: 'EG',
              idempotencyKey: 'c1',
              bookingId: 'b1',
            },
            'u1',
          ),
        ).rejects.toMatchObject({
          status: 400,
          response: { code: 'TEST_PAYMENT_METHOD_FORBIDDEN' },
        });
      });

      expect(attempts.transition).not.toHaveBeenCalled();
      expect(gateway.confirmPayment).not.toHaveBeenCalled();
    });

    it('refuses to confirm a booking that is already confirmed', async () => {
      const { service, gateway } = buildService({
        booking: baseBooking({ status: 'confirmed' }),
      });

      await expect(
        service.confirmPayment(
          {
            paymentId: 'pi_1',
            methodReference: 'CARD',
            market: 'EG',
            idempotencyKey: 'c1',
            bookingId: 'b1',
          },
          'u1',
        ),
      ).rejects.toMatchObject({ response: { code: 'BOOKING_NOT_PAYABLE' } });

      expect(gateway.confirmPayment).not.toHaveBeenCalled();
    });

    it('refuses a payment whose attempt was created for a different price version', async () => {
      const { service, gateway } = buildService({
        booking: baseBooking({ priceVersion: 'price-v1-new' }),
        attempt: baseAttempt({ priceVersion: 'price-v1-old' }),
      });

      await expect(
        service.confirmPayment(
          {
            paymentId: 'pi_1',
            methodReference: 'CARD',
            market: 'EG',
            idempotencyKey: 'c1',
            bookingId: 'b1',
          },
          'u1',
        ),
      ).rejects.toMatchObject({ response: { code: 'PRICE_CHANGED' } });

      expect(gateway.confirmPayment).not.toHaveBeenCalled();
    });

    it('refuses a payment whose amount no longer matches the booking', async () => {
      const { service, gateway } = buildService({
        attempt: baseAttempt({ amount: 90 }),
      });

      await expect(
        service.confirmPayment(
          {
            paymentId: 'pi_1',
            methodReference: 'CARD',
            market: 'EG',
            idempotencyKey: 'c1',
            bookingId: 'b1',
          },
          'u1',
        ),
      ).rejects.toMatchObject({ response: { code: 'PRICE_CHANGED' } });

      expect(gateway.confirmPayment).not.toHaveBeenCalled();
    });

    it('records verifiedAt only after the gateway confirms success', async () => {
      const { service, attempts, ledger } = buildService();

      const result = await service.confirmPayment(
        {
          paymentId: 'pi_1',
          methodReference: 'CARD',
          market: 'EG',
          idempotencyKey: 'c1',
          bookingId: 'b1',
        },
        'u1',
      );

      expect(result).toMatchObject({ status: 'OK', attemptStatus: 'succeeded' });
      expect(attempts.transition).toHaveBeenCalledWith(
        'a1',
        'succeeded',
        expect.objectContaining({ verifiedAt: expect.any(Date) }),
      );
      expect(ledger.append).toHaveBeenCalledWith(
        expect.objectContaining({ type: 'capture', status: 'succeeded' }),
      );
    });
  });

  describe('refundPayment — admin, verified and policy-gated', () => {
    const refundInput = (overrides: Record<string, any> = {}) => ({
      paymentId: 'pi_1',
      amount: 40,
      market: 'EG',
      idempotencyKey: 'r1',
      bookingId: 'b1',
      ...overrides,
    });

    function refundable(overrides: Record<string, any> = {}) {
      return buildService({
        attempt: baseAttempt({
          status: 'succeeded',
          verifiedAt: new Date(),
          ...overrides,
        }),
      });
    }

    it('refuses a non-admin caller', async () => {
      const { service, attempts } = refundable();

      await expect(
        service.refundPayment(refundInput(), 'u1'),
      ).rejects.toBeInstanceOf(ForbiddenException);
      expect(attempts.findByGatewayRef).not.toHaveBeenCalled();
    });

    it('refuses an attempt with no server-verified success evidence', async () => {
      const { service } = refundable({ verifiedAt: null });

      await expect(
        service.refundPayment(refundInput(), 'u1', 'admin'),
      ).rejects.toMatchObject({ response: { code: 'PAYMENT_NOT_VERIFIED' } });
    });

    it('refuses a refund while the booking is confirmed', async () => {
      const { service } = buildService({
        booking: baseBooking({ status: 'confirmed' }),
        attempt: baseAttempt({ status: 'succeeded', verifiedAt: new Date() }),
      });

      await expect(
        service.refundPayment(refundInput(), 'u1', 'admin'),
      ).rejects.toMatchObject({ response: { code: 'REFUND_NOT_ALLOWED' } });
    });

    it('refuses a payment that belongs to a different booking', async () => {
      const { service } = refundable();

      await expect(
        service.refundPayment(
          refundInput({ bookingId: 'b2' }),
          'u1',
          'admin',
        ),
      ).rejects.toThrow(/does not belong to this booking/i);
    });

    it('refuses a payment whose booking owner does not match the attempt', async () => {
      const { service } = buildService({
        booking: baseBooking({ userId: 'u2' }),
        attempt: baseAttempt({ status: 'succeeded', verifiedAt: new Date() }),
      });

      await expect(
        service.refundPayment(refundInput(), 'u1', 'admin'),
      ).rejects.toBeInstanceOf(ForbiddenException);
    });

    it('caps a refund by the remaining refundable amount, not the original capture', async () => {
      const { service } = buildService({
        attempt: baseAttempt({ status: 'succeeded', verifiedAt: new Date() }),
        refunds: [
          {
            leg: 'CUSTOMER',
            type: 'refund',
            status: 'succeeded',
            amount: 80,
          },
        ],
      });

      await expect(
        service.refundPayment(refundInput({ amount: 30 }), 'u1', 'admin'),
      ).rejects.toThrow(/remaining refundable amount of 20/i);
    });

    it('refuses a refund for an attempt that never succeeded', async () => {
      const { service, attempts } = refundable({ status: 'declined' });

      const result = await service.refundPayment(
        refundInput(),
        'u1',
        'admin',
      );

      expect(result).toMatchObject({ status: 'FAILED', attemptStatus: 'declined' });
      expect(attempts.transition).not.toHaveBeenCalled();
    });

    it('a full refund releases the consumed attempt link', async () => {
      const { service, attempts, bookings, ledger } = refundable();

      const result = await service.refundPayment(
        refundInput({ amount: 100 }),
        'u1',
        'admin',
      );

      expect(result.status).toBe('OK');
      expect(attempts.transition).toHaveBeenCalledWith('a1', 'refunded');
      expect(bookings.update).toHaveBeenCalledWith(
        { id: 'b1' },
        expect.objectContaining({
          paymentAttemptId: null,
          paymentStatus: 'refunded',
          consumedAt: null,
        }),
      );
      expect(ledger.append).toHaveBeenCalledWith(
        expect.objectContaining({ type: 'refund', amount: 100 }),
      );
    });

    it('a partial refund keeps the link but marks the payment partially refunded', async () => {
      const { service, attempts, bookings } = refundable();

      await service.refundPayment(refundInput({ amount: 40 }), 'u1', 'admin');

      expect(attempts.transition).toHaveBeenCalledWith(
        'a1',
        'partially_refunded',
      );
      const update = bookings.update.mock.calls[0][1];
      expect(update).toMatchObject({ paymentStatus: 'partially_refunded' });
      expect(update).not.toHaveProperty('paymentAttemptId');
    });
  });
});
