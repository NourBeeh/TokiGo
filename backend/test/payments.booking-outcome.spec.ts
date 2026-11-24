import { PaymentService } from '../src/modules/payments/payment.service';

/**
 * Payment safety around an unresolved booking outcome.
 *
 * A booking in `reconciliation_pending` (or still `confirming`, or already
 * `confirmed`) must never produce another payment intent. The guard runs
 * BEFORE the durable attempt claim and BEFORE any gateway call, so a checkout
 * retry cannot create a second charge for a booking whose provider outcome is
 * unknown.
 */

function makeService(booking: Record<string, any>) {
  const gateway = {
    gatewayId: 'mock-egypt',
    supportsMarket: ['EG'],
    createPaymentIntent: jest.fn().mockResolvedValue({
      paymentId: 'pi_1',
      bookingId: booking.id,
      amount: 100,
      currency: 'USD',
      status: 'REQUIRES_CONFIRMATION',
      clientSecret: 'secret',
      createdAt: new Date().toISOString(),
    }),
  };
  const router = {
    forMarket: jest.fn().mockReturnValue(gateway),
    listGateways: jest
      .fn()
      .mockReturnValue([{ gatewayId: 'mock-egypt', markets: ['EG'] }]),
  };
  const attempts = {
    claim: jest.fn().mockResolvedValue({
      created: true,
      attempt: {
        id: 'attempt-1',
        bookingId: booking.id,
        userId: booking.userId,
        amount: 100,
        currency: 'USD',
        status: 'created',
      },
    }),
    transition: jest
      .fn()
      .mockResolvedValue({ attempt: { id: 'attempt-1', status: 'processing' } }),
  };
  const bookings = {
    findOne: jest.fn().mockResolvedValue(booking),
  };

  const service = new PaymentService(
    router as any,
    {} as any,
    attempts as any,
    bookings as any,
    {} as any,
    {} as any,
  );
  return { service, gateway, attempts, bookings, router };
}

const baseBooking = {
  id: 'b1',
  userId: 'u1',
  status: 'reconciliation_pending',
  authoritativePrice: 100,
  currency: 'USD',
  priceVersion: 'price-v1-test',
};

describe('PaymentService — unresolved booking outcome', () => {
  it('returns UNKNOWN for reconciliation_pending without claiming an attempt or calling the gateway', async () => {
    const { service, gateway, attempts } = makeService({ ...baseBooking });

    const result = await service.createPayment(
      {
        bookingId: 'b1',
        amount: 100,
        currency: 'USD',
        market: 'EG',
        idempotencyKey: 'pay-b1-card',
      },
      'u1',
    );

    expect(result).toMatchObject({
      status: 'UNKNOWN',
      reason: 'booking_outcome_unknown',
      bookingId: 'b1',
      bookingStatus: 'reconciliation_pending',
      retryable: false,
    });
    expect(attempts.claim).not.toHaveBeenCalled();
    expect(gateway.createPaymentIntent).not.toHaveBeenCalled();
  });

  it('blocked for an in-flight confirmation and for an already confirmed booking', async () => {
    for (const status of ['confirming', 'confirmed']) {
      const { service, gateway, attempts } = makeService({
        ...baseBooking,
        status,
      });
      const result = await service.createPayment(
        {
          bookingId: 'b1',
          amount: 100,
          currency: 'USD',
          market: 'EG',
          idempotencyKey: `pay-b1-${status}`,
        },
        'u1',
      );
      expect(result).toMatchObject({
        status: 'UNKNOWN',
        bookingStatus: status,
        retryable: false,
      });
      expect(attempts.claim).not.toHaveBeenCalled();
      expect(gateway.createPaymentIntent).not.toHaveBeenCalled();
    }
  });

  it('a normal prepared booking still claims one attempt and calls the gateway once', async () => {
    const { service, gateway, attempts } = makeService({
      ...baseBooking,
      status: 'prepared',
    });

    const result = await service.createPayment(
      {
        bookingId: 'b1',
        amount: 100,
        currency: 'USD',
        market: 'EG',
        idempotencyKey: 'pay-b1-card',
      },
      'u1',
    );

    expect(result).toMatchObject({ status: 'OK', attemptId: 'attempt-1' });
    expect(attempts.claim).toHaveBeenCalledTimes(1);
    expect(attempts.claim).toHaveBeenCalledWith(
      expect.objectContaining({ priceVersion: 'price-v1-test' }),
    );
    expect(gateway.createPaymentIntent).toHaveBeenCalledTimes(1);
  });
});
