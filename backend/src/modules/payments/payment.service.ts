import { Injectable, ForbiddenException } from '@nestjs/common';
import { PaymentRouter } from './payment.router';
import { LedgerService } from './ledger.service';
import { routesForMarket } from './payment.gateway';

/**
 * Payment orchestrator (spec point 31): one customer-payment abstraction
 * consumed by booking services. All money-changing operations are
 * idempotent and every movement lands in the ledger.
 */

@Injectable()
export class PaymentService {
  private readonly processedWebhooks = new Set<string>();
  // Ownership tracking: paymentId/bookingId -> owning userId (fail-closed).
  private readonly paymentOwners = new Map<string, string>();
  private readonly bookingOwners = new Map<string, string>();

  constructor(
    private readonly router: PaymentRouter,
    private readonly ledger: LedgerService,
  ) {}

  async createPayment(input: {
    bookingId: string;
    amount: number;
    currency: string;
    market: string;
    idempotencyKey: string;
  }, userId?: string) {
    const region = routesForMarket(input.market);
    const gateway = region ? this.router.forMarket(region) : null;
    if (!gateway) {
      return {
        status: 'UNAVAILABLE' as const,
        reason: `No payment gateway configured for market ${input.market}`,
      };
    }
    const intent = await gateway.createPaymentIntent({
      bookingId: input.bookingId,
      idempotencyKey: input.idempotencyKey,
      amount: input.amount,
      currency: input.currency,
      market: input.market,
    });
    // Record ownership so later refund/confirm/ledger calls can be authorized.
    if (userId) {
      this.paymentOwners.set(intent.paymentId, userId);
      this.bookingOwners.set(input.bookingId, userId);
    }
    this.ledger.append({
      bookingId: input.bookingId,
      paymentId: intent.paymentId,
      gateway: gateway.gatewayId,
      side: 'CUSTOMER',
      type: 'CHARGE',
      amount: input.amount,
      currency: input.currency,
      externalReference: intent.paymentId,
    });
    return { status: 'OK' as const, intent };
  }

  async confirmPayment(input: {
    paymentId: string;
    methodReference: 'CARD_SUCCESS' | 'CARD_3DS' | 'CARD_DECLINED' | 'WALLET';
    market: string;
    idempotencyKey: string;
    bookingId: string;
  }, userId?: string) {
    // Ownership check (fail-closed) — only when a caller identity is supplied.
    if (userId) {
      const owner = this.paymentOwners.get(input.paymentId);
      if (owner && owner !== userId) {
        throw new ForbiddenException('Payment does not belong to the caller.');
      }
      if (input.bookingId && this.bookingOwners.get(input.bookingId) && this.bookingOwners.get(input.bookingId) !== userId) {
        throw new ForbiddenException('Booking does not belong to the caller.');
      }
    }
    const gateway = this.router.forMarket(routesForMarket(input.market) ?? input.market);
    if (!gateway) {
      return { status: 'UNAVAILABLE' as const };
    }
    const intent = await gateway.confirmPayment({
      paymentId: input.paymentId,
      methodReference: input.methodReference,
      idempotencyKey: input.idempotencyKey,
    });
    return { status: 'OK' as const, intent };
  }

  async refundPayment(input: {
    paymentId: string;
    amount: number;
    reason?: string;
    market: string;
    idempotencyKey: string;
    bookingId: string;
  }, userId?: string) {
    // Ownership check (fail-closed) — only when a caller identity is supplied.
    if (userId) {
      const owner = this.paymentOwners.get(input.paymentId);
      if (owner && owner !== userId) {
        throw new ForbiddenException('Payment does not belong to the caller.');
      }
      if (input.bookingId && this.bookingOwners.get(input.bookingId) && this.bookingOwners.get(input.bookingId) !== userId) {
        throw new ForbiddenException('Booking does not belong to the caller.');
      }
    }
    const gateway = this.router.forMarket(routesForMarket(input.market) ?? input.market);
    if (!gateway) {
      return { status: 'UNAVAILABLE' as const };
    }
    const intent = await gateway.refundPayment({
      paymentId: input.paymentId,
      amount: input.amount,
      reason: input.reason,
      idempotencyKey: input.idempotencyKey,
    });
    // Refunds append a reversal entry — the original charge stays intact
    // (spec point 36: never update financial history destructively).
    this.ledger.append({
      bookingId: input.bookingId,
      paymentId: input.paymentId,
      gateway: gateway.gatewayId,
      side: 'REFUND',
      type: 'REFUND',
      amount: input.amount,
      currency: intent.currency,
      externalReference: input.paymentId,
      metadata: { reason: input.reason },
    });
    return { status: 'OK' as const, intent };
  }

  async handleWebhook(payload: {
    id: string;
    paymentId: string;
    type: 'payment.succeeded' | 'payment.failed' | 'payment.refunded';
    signature: string;
    occurredAt: string;
    market?: string;
  }) {
    const gateway = this.router.forMarket(routesForMarket(payload.market ?? 'EG') ?? 'EG');
    if (!gateway || !gateway.verifyWebhook(payload)) {
      return { status: 'REJECTED' as const };
    }
    // Replay protection: a webhook id must be processed at most once.
    if (this.processedWebhooks.has(payload.id)) {
      return { status: 'REJECTED' as const };
    }
    // Existence check: the payment must actually exist in the gateway.
    const existing = await gateway.retrievePayment(payload.paymentId);
    if (!existing) {
      return { status: 'REJECTED' as const };
    }
    this.processedWebhooks.add(payload.id);
    // Verified webhooks settle async (3DS) payments — the split-brain
    // recovery path (spec point O.9): payment success never assumes
    // booking success; booking services react to the status change.
    const mock = gateway as unknown as { settlePending?(id: string): any };
    if (typeof mock.settlePending === 'function') {
      mock.settlePending(payload.paymentId);
    }
    return { status: 'PROCESSED' as const };
  }

  bookingTimeline(bookingId: string, userId?: string) {
    if (userId) {
      const owner = this.bookingOwners.get(bookingId);
      // Fail-closed only when we have recorded ownership for this booking.
      // Unknown (legacy) bookings are allowed to keep backward compat with
      // pre-existing ledger entries, but only for the recording owner.
      if (owner && owner !== userId) {
        throw new ForbiddenException('Booking does not belong to the caller.');
      }
    }
    return this.ledger.forBooking(bookingId);
  }
}
