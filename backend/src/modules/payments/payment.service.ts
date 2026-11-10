import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { createHash } from 'crypto';
import { Repository } from 'typeorm';

import { PaymentRouter } from './payment.router';
import { LedgerService, LedgerEntryView } from './ledger.service';
import { PaymentAttemptService } from './payment-attempt.service';
import {
  isDefinitiveGatewayError,
  safeFailureCode,
  statusFromGateway,
} from './payment-attempt.state';
import { routesForMarket } from './payment.gateway';
import { Booking } from '../bookings/booking.entity';
import { WebhookEvent } from '../../database/entities/webhook-event.entity';
import {
  WEBHOOK_EVENT_FINAL_STATUSES,
  WEBHOOK_EVENT_RETRYABLE_STATUSES,
} from '../../database/entities/webhook-event.entity';
import { PaymentAttempt } from '../../database/entities/payment-attempt.entity';
import { ProcessedWebhook } from '../../database/entities/processed_webhook.entity';
import { InvalidPaymentAttemptTransitionError } from './payment-attempt.state';
import { PaymentIntent } from './payment.gateway';

/** How long a concurrent retry waits for the winning request's gateway ref. */
const CLAIM_WAIT_MS = 1000;
const CLAIM_POLL_MS = 50;

/**
 * Tolerance when comparing a client quote or a gateway echo against the
 * server-authoritative amount. `bookings.authoritativePrice` is a Postgres
 * `real` (float32), so exact float equality is not guaranteed across the
 * JSON round trip; anything within one cent is the same money.
 */
const MONEY_TOLERANCE = 0.01;

/** The payable amount and currency, derived from trusted server-side data. */
interface ServerPricing {
  amount: number;
  currency: string;
}

/**
 * The gateway echoed an amount or currency that contradicts the amount we sent.
 *
 * This is never treated as a success: the provider's state is inconsistent with
 * the durable attempt, so the outcome is ambiguous and requires reconciliation.
 */
export class GatewayAmountMismatchError extends Error {
  constructor(
    readonly expected: ServerPricing,
    readonly received: { amount: number; currency: string },
  ) {
    super(
      `Gateway returned ${received.amount} ${received.currency}; expected ${expected.amount} ${expected.currency}.`,
    );
    this.name = 'GatewayAmountMismatchError';
  }
}

function delay(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

@Injectable()
export class PaymentService {
  constructor(
    private readonly router: PaymentRouter,
    private readonly ledger: LedgerService,
    private readonly attempts: PaymentAttemptService,
    @InjectRepository(Booking)
    private readonly bookings: Repository<Booking>,
    @InjectRepository(WebhookEvent)
    private readonly webhookEvents: Repository<WebhookEvent>,
    /**
     * The retired pre-P4-2 replay table. Kept as an archive and checked before
     * any webhook effect so a historically processed event can never be applied
     * twice. See `processed_webhook.entity.ts`.
     */
    @InjectRepository(ProcessedWebhook)
    private readonly legacyWebhooks: Repository<ProcessedWebhook>,
  ) {}

  async createPayment(
    input: {
      bookingId: string;
      amount: number;
      currency: string;
      market: string;
      idempotencyKey: string;
    },
    userId?: string,
  ) {
    const region = routesForMarket(input.market);
    const gateway = region ? this.router.forMarket(region) : null;
    if (!gateway) {
      return {
        status: 'UNAVAILABLE' as const,
        reason: `No payment gateway configured for market ${input.market}`,
      };
    }

    const booking = await this.requireOwnedBooking(input.bookingId, userId);

    // The payable amount is derived from the durable booking row, never from
    // the request. `authoritativePrice` / `currency` are written only by
    // provider revalidation in BookingsService, so they are the trusted
    // authority. If they are missing or unusable we fail — we never fall back
    // to the client's quote.
    const pricing = this.resolveServerPricing(booking);

    // The client's amount/currency are treated as a QUOTE to validate, not as
    // the authority. A mismatch means the quote was tampered with or is stale;
    // both are rejected, and the charge always uses the server value.
    this.assertQuoteMatchesServerPricing(input, pricing);

    const { attempt, created } = await this.attempts.claim({
      userId: booking.userId,
      bookingId: booking.id,
      idempotencyKey: input.idempotencyKey,
      amount: pricing.amount,
      currency: pricing.currency,
      gatewayId: gateway.gatewayId,
    });

    if (!created) {
      // A retry (or a race loser) with the same key resolves to the SAME
      // durable attempt. Never create a second one, never charge twice.
      return this.resolveExistingAttempt(gateway.gatewayId, attempt);
    }

    await this.attempts.transition(attempt.id, 'processing');

    let intent;
    try {
      intent = await gateway.createPaymentIntent({
        bookingId: input.bookingId,
        idempotencyKey: this.gatewayKey(booking.userId, input.idempotencyKey),
        amount: pricing.amount,
        currency: pricing.currency,
        market: input.market,
      });
      // The provider must echo the exact amount we asked it to charge.
      this.assertGatewayIntentMatches(intent, pricing);
    } catch (error) {
      const mismatch = error instanceof GatewayAmountMismatchError;
      const to = mismatch || !isDefinitiveGatewayError(error) ? 'unknown' : 'failed';
      const updated = await this.attempts.transition(attempt.id, to, {
        failureCode: mismatch ? 'gateway_amount_mismatch' : safeFailureCode(error),
      });
      return {
        status: to === 'unknown' ? ('UNKNOWN' as const) : ('FAILED' as const),
        attemptId: attempt.id,
        attemptStatus: updated.attempt.status,
        reason: mismatch ? 'gateway_amount_mismatch' : safeFailureCode(error),
      };
    }

    // REQUIRES_CONFIRMATION means the customer must still act — no money has
    // moved, so NO ledger entry is written here (spec: never record a capture
    // from Payment Intent creation alone).
    const updated = await this.attempts.transition(attempt.id, 'requires_action', {
      gatewayRef: intent.paymentId,
    });
    return { status: 'OK' as const, intent, attemptId: attempt.id, attemptStatus: updated.attempt.status };
  }

  /**
   * Derive the payable amount and currency from the booking row.
   *
   * `bookings.authoritativePrice` is the provider-revalidated total, written by
   * `BookingsService.prepare` / `revalidate` / `create`. Add-ons are NOT part of
   * it: the add-ons step in the funnel explicitly offers nothing and adds
   * nothing (see `add_ons_page.dart`), so the booking total IS the payable
   * amount today. No pricing model is invented here.
   */
  private resolveServerPricing(booking: Booking): ServerPricing {
    const amount = booking.authoritativePrice;
    const currency = booking.currency;

    if (typeof amount !== 'number' || !Number.isFinite(amount) || amount <= 0) {
      throw new ConflictException(
        'Authoritative pricing is unavailable for this booking.',
      );
    }
    if (typeof currency !== 'string' || !/^[A-Z]{3}$/.test(currency)) {
      throw new ConflictException(
        'Authoritative currency is unavailable for this booking.',
      );
    }
    return { amount, currency };
  }

  /**
   * Reject a client quote that disagrees with the server-authoritative price.
   * Never silently accept and never silently fall back.
   */
  private assertQuoteMatchesServerPricing(
    quote: { amount: number; currency: string },
    pricing: ServerPricing,
  ): void {
    if (
      typeof quote.amount !== 'number' ||
      !Number.isFinite(quote.amount) ||
      Math.abs(quote.amount - pricing.amount) > MONEY_TOLERANCE
    ) {
      throw new ConflictException(
        `Amount mismatch: the authoritative price is ${pricing.amount} ${pricing.currency}.`,
      );
    }
    if (quote.currency !== pricing.currency) {
      throw new ConflictException(
        `Currency mismatch: the authoritative currency is ${pricing.currency}.`,
      );
    }
  }

  /**
   * Reject a gateway echo that contradicts the amount we sent. Throws
   * {@link GatewayAmountMismatchError} so callers can classify it as ambiguous.
   */
  private assertGatewayIntentMatches(
    intent: { amount: number; currency: string } | null,
    expected: ServerPricing,
  ): void {
    if (!intent) {
      throw new GatewayAmountMismatchError(expected, {
        amount: Number.NaN,
        currency: '',
      });
    }
    if (
      typeof intent.amount !== 'number' ||
      Math.abs(intent.amount - expected.amount) > MONEY_TOLERANCE ||
      intent.currency !== expected.currency
    ) {
      throw new GatewayAmountMismatchError(expected, {
        amount: intent.amount,
        currency: intent.currency,
      });
    }
  }

  /**
   * Resolve a retry against an attempt that already exists. If the winning
   * request has not stored its gateway reference yet, wait a bounded time for
   * it rather than calling the gateway a second time.
   */
  private async resolveExistingAttempt(gatewayId: string, attempt: PaymentAttempt) {
    let current = attempt;
    const deadline = Date.now() + CLAIM_WAIT_MS;
    while (!current.gatewayRef && Date.now() < deadline) {
      await delay(CLAIM_POLL_MS);
      const fresh = await this.attempts.findById(current.id);
      if (!fresh) break;
      current = fresh;
    }

    if (!current.gatewayRef) {
      // Still no gateway reference: the first request is in flight or failed
      // before reaching the provider. Report the durable state — never start a
      // second provider operation for the same key.
      const fresh = await this.attempts.findById(current.id);
      return {
        status: 'PENDING' as const,
        attemptId: current.id,
        attemptStatus: fresh?.status ?? current.status,
      };
    }

    const gateway = this.router.forMarket(
      // The attempt already knows its gateway; look it up by id.
      this.marketForGateway(gatewayId),
    );
    const intent = gateway ? await gateway.retrievePayment(current.gatewayRef) : null;
    if (!intent) {
      return {
        status: 'UNAVAILABLE' as const,
        attemptId: current.id,
        attemptStatus: current.status,
        reason: 'gateway_intent_unavailable',
      };
    }
    // The stored intent must still match the amount this attempt was created
    // for; a provider-side change is an ambiguity, never a silent success.
    try {
      this.assertGatewayIntentMatches(intent, {
        amount: current.amount,
        currency: current.currency,
      });
    } catch (error) {
      return {
        status: 'UNKNOWN' as const,
        attemptId: current.id,
        attemptStatus: current.status,
        reason: error instanceof GatewayAmountMismatchError
          ? 'gateway_amount_mismatch'
          : 'gateway_intent_invalid',
      };
    }
    return {
      status: 'OK' as const,
      intent,
      attemptId: current.id,
      attemptStatus: current.status,
    };
  }

  /**
   * The gateway's idempotency key is namespaced by user.
   *
   * A provider must never hand the SAME payment intent to two different users
   * who happen to pick the same client key — that would let one traveller
   * confirm another's payment. Namespacing keeps the provider's dedupe scope
   * aligned with the `(userId, idempotencyKey)` unique constraint, which stays
   * as the database-level backstop.
   */
  private gatewayKey(userId: string, idempotencyKey: string): string {
    return `${userId}:${idempotencyKey}`;
  }

  /** Gateways are few and stable; resolve the market from the gateway id. */
  private marketForGateway(gatewayId: string): string {
    const known = this.router.listGateways().find(g => g.gatewayId === gatewayId);
    return known?.markets[0] ?? 'EG';
  }

  async confirmPayment(
    input: {
      paymentId: string;
      methodReference: 'CARD_SUCCESS' | 'CARD_3DS' | 'CARD_DECLINED' | 'WALLET';
      market: string;
      idempotencyKey: string;
      bookingId: string;
    },
    userId?: string,
  ) {
    const gateway = this.router.forMarket(routesForMarket(input.market) ?? input.market);
    if (!gateway) {
      return { status: 'UNAVAILABLE' as const };
    }

    const attempt = await this.attempts.findByGatewayRef(gateway.gatewayId, input.paymentId);
    if (!attempt) {
      throw new NotFoundException('Payment not found.');
    }
    this.assertOwnership(attempt.userId, userId, attempt.bookingId, input.bookingId);

    // Already terminal: replay the state instead of calling the gateway again.
    if (attempt.status === 'succeeded') {
      return {
        status: 'OK' as const,
        intent: await gateway.retrievePayment(input.paymentId),
        attemptId: attempt.id,
        attemptStatus: attempt.status,
      };
    }
    if (
      ['declined', 'failed', 'cancelled', 'voided', 'consumed', 'refunded'].includes(
        attempt.status,
      )
    ) {
      return {
        status: attempt.status === 'declined' ? ('DECLINED' as const) : ('FAILED' as const),
        attemptId: attempt.id,
        attemptStatus: attempt.status,
        reason: `attempt_${attempt.status}`,
      };
    }

    const transition = await this.attempts.transition(attempt.id, 'processing', {
      method: input.methodReference,
    });
    if (transition.outcome !== 'transitioned') {
      // Another request already moved this attempt. Do NOT call the gateway.
      return {
        status: 'PENDING' as const,
        attemptId: attempt.id,
        attemptStatus: transition.attempt.status,
      };
    }

    let intent;
    try {
      intent = await gateway.confirmPayment({
        paymentId: input.paymentId,
        methodReference: input.methodReference,
        idempotencyKey: this.gatewayKey(attempt.userId, input.idempotencyKey),
      });
      // Confirmation must settle the amount this attempt was created for.
      this.assertGatewayIntentMatches(intent, {
        amount: attempt.amount,
        currency: attempt.currency,
      });
    } catch (error) {
      const mismatch = error instanceof GatewayAmountMismatchError;
      const to = mismatch || !isDefinitiveGatewayError(error) ? 'unknown' : 'failed';
      await this.attempts.transition(attempt.id, to, {
        failureCode: mismatch ? 'gateway_amount_mismatch' : safeFailureCode(error),
      });
      return {
        status: to === 'unknown' ? ('UNKNOWN' as const) : ('FAILED' as const),
        attemptId: attempt.id,
        attemptStatus: to,
        reason: mismatch ? 'gateway_amount_mismatch' : safeFailureCode(error),
      };
    }

    const target = statusFromGateway(intent.status);
    await this.attempts.transition(attempt.id, target);

    if (target === 'succeeded') {
      // The ONLY place a successful customer capture is recorded.
      await this.ledger.append({
        bookingId: attempt.bookingId,
        leg: 'CUSTOMER',
        type: 'capture',
        status: 'succeeded',
        amount: attempt.amount,
        currency: attempt.currency,
        attemptId: attempt.id,
        gatewayRef: input.paymentId,
        idempotencyKey: `capture:${attempt.id}`,
      });
    } else if (target === 'declined') {
      await this.ledger.append({
        bookingId: attempt.bookingId,
        leg: 'CUSTOMER',
        type: 'capture',
        status: 'failed',
        amount: attempt.amount,
        currency: attempt.currency,
        attemptId: attempt.id,
        gatewayRef: input.paymentId,
        idempotencyKey: `capture-failed:${attempt.id}:${input.idempotencyKey}`,
      });
    }

    return {
      status: 'OK' as const,
      intent,
      attemptId: attempt.id,
      attemptStatus: target,
    };
  }

  async refundPayment(
    input: {
      paymentId: string;
      amount: number;
      reason?: string;
      market: string;
      idempotencyKey: string;
      bookingId: string;
    },
    userId?: string,
  ) {
    const gateway = this.router.forMarket(routesForMarket(input.market) ?? input.market);
    if (!gateway) {
      return { status: 'UNAVAILABLE' as const };
    }

    const attempt = await this.attempts.findByGatewayRef(gateway.gatewayId, input.paymentId);
    if (!attempt) {
      throw new NotFoundException('Payment not found.');
    }
    this.assertOwnership(attempt.userId, userId, attempt.bookingId, input.bookingId);

    if (!['succeeded', 'partially_refunded'].includes(attempt.status)) {
      return {
        status: 'FAILED' as const,
        attemptId: attempt.id,
        attemptStatus: attempt.status,
        reason: `attempt_${attempt.status}`,
      };
    }
    if (
      typeof input.amount !== 'number' ||
      !Number.isFinite(input.amount) ||
      !(input.amount > 0)
    ) {
      throw new BadRequestException('Refund amount must be positive.');
    }
    // A refund can never exceed what was actually captured for this attempt.
    if (input.amount > attempt.amount + MONEY_TOLERANCE) {
      throw new BadRequestException(
        `Refund amount exceeds the captured amount of ${attempt.amount} ${attempt.currency}.`,
      );
    }

    const transition = await this.attempts.transition(attempt.id, 'processing');
    if (transition.outcome !== 'transitioned') {
      return {
        status: 'PENDING' as const,
        attemptId: attempt.id,
        attemptStatus: transition.attempt.status,
      };
    }
    const previousStatus = attempt.status;

    let intent;
    try {
      intent = await gateway.refundPayment({
        paymentId: input.paymentId,
        amount: input.amount,
        reason: input.reason,
        idempotencyKey: this.gatewayKey(attempt.userId, input.idempotencyKey),
      });
      // The gateway still reports the captured amount and currency; a change
      // here means the provider state contradicts the durable attempt.
      this.assertGatewayIntentMatches(intent, {
        amount: attempt.amount,
        currency: attempt.currency,
      });
    } catch (error) {
      // A failed refund must NOT mark the capture as failed — the money is
      // still collected. Return to the pre-refund state, or `unknown` when the
      // outcome is ambiguous (the refund may have happened).
      const mismatch = error instanceof GatewayAmountMismatchError;
      const to =
        mismatch || !isDefinitiveGatewayError(error) ? 'unknown' : previousStatus;
      await this.attempts.transition(attempt.id, to, {
        failureCode: mismatch ? 'gateway_amount_mismatch' : safeFailureCode(error),
      });
      return {
        status: to === 'unknown' ? ('UNKNOWN' as const) : ('FAILED' as const),
        attemptId: attempt.id,
        attemptStatus: to,
        reason: mismatch ? 'gateway_amount_mismatch' : safeFailureCode(error),
      };
    }

    // A partial refund must not mark the whole payment refunded.
    const fullyRefunded = input.amount >= attempt.amount;
    const target = fullyRefunded ? 'refunded' : 'partially_refunded';
    await this.attempts.transition(attempt.id, target);

    await this.ledger.append({
      bookingId: attempt.bookingId,
      leg: 'CUSTOMER',
      type: 'refund',
      status: 'succeeded',
      amount: input.amount,
      currency: attempt.currency,
      attemptId: attempt.id,
      gatewayRef: input.paymentId,
      idempotencyKey: `refund:${attempt.id}:${input.idempotencyKey}`,
      metadata: input.reason ? { reason: input.reason } : null,
    });

    return {
      status: 'OK' as const,
      intent,
      attemptId: attempt.id,
      attemptStatus: target,
    };
  }

  /**
   * Gateway callback.
   *
   * Two replay authorities are consulted, and they cannot disagree about
   * whether an event was already applied:
   *
   *  - `webhook_events` is the authoritative store for events first seen after
   *    P4-2, keyed by `(provider, eventId)`.
   *  - `processed_webhooks` is the RETIRED pre-P4-2 archive. Its rows are
   *    preserved and it is checked first, so a historically processed id can
   *    never be applied again. New events are mirrored into it as well.
   *
   * The event is persisted BEFORE any financial effect, and the effect is
   * applied from the gateway's authoritative state — never from the
   * client-supplied `type`. The gateway's amount and currency must also match
   * the durable attempt.
   */
  async handleWebhook(payload: {
    id: string;
    paymentId: string;
    type: 'payment.succeeded' | 'payment.failed' | 'payment.refunded';
    signature: string;
    occurredAt: string;
    market?: string;
  }) {
    const gateway = this.router.forMarket(routesForMarket(payload.market ?? 'EG') ?? 'EG');
    if (!gateway) {
      return { status: 'REJECTED' as const, reason: 'unknown_gateway' };
    }
    // The mock gateway implements real HMAC-SHA256 verification over
    // "id:paymentId"; a bad signature is rejected before anything is persisted.
    if (!gateway.verifyWebhook(payload)) {
      return { status: 'REJECTED' as const, reason: 'invalid_signature' };
    }

    const provider = gateway.gatewayId;
    const payloadHash = createHash('sha256')
      .update(`${payload.id}:${payload.paymentId}:${payload.type}:${payload.occurredAt}`)
      .digest('hex');

    // P4-2R: the retired pre-P4-2 archive is still a replay authority. An event
    // id that was processed before P4-2 must never be applied again — the
    // original table stored only the bare event id, and that identity is
    // preserved rather than inventing a provider column the rows never had.
    const legacy = await this.legacyWebhooks.findOne({ where: { id: payload.id } });
    if (legacy) {
      return { status: 'REJECTED' as const, reason: 'duplicate_event_legacy' };
    }

    const claim = await this.claimWebhookEvent(provider, payload.id, payload.type, payloadHash);
    if (claim.state === 'duplicate') {
      return { status: 'REJECTED' as const, reason: 'duplicate_event' };
    }

    // --- provider retrieval. No transaction is open here. ------------------
    // A lookup failure is NOT proof that the payment failed; it is a transient
    // condition, so the event stays retryable.
    let authoritative: PaymentIntent | null = null;
    try {
      authoritative = await gateway.retrievePayment(payload.paymentId);
    } catch {
      await this.markWebhookEvent(
        provider,
        payload.id,
        'retryable',
        'gateway_unavailable',
      );
      return { status: 'REJECTED' as const, reason: 'gateway_unavailable' };
    }

    // The provider may simply not know the payment yet (event ordering). That is
    // timing, not a verdict — a later delivery must be able to retry.
    if (!authoritative) {
      await this.markWebhookEvent(provider, payload.id, 'retryable', 'payment_not_found');
      return { status: 'REJECTED' as const, reason: 'unknown_payment' };
    }

    const attempt = await this.attempts.findByGatewayRef(provider, payload.paymentId);
    if (!attempt) {
      // Not automatically permanent: the attempt may not be visible yet.
      await this.markWebhookEvent(provider, payload.id, 'retryable', 'attempt_not_found');
      return { status: 'REJECTED' as const, reason: 'unknown_attempt' };
    }

    // The mock gateway has no real async hook; `settlePending` models the bank
    // confirming a 3DS intent. It is only invoked for a signature-verified
    // `payment.succeeded` event, and the authority below is re-read from the
    // gateway afterwards — the client-supplied type never decides the outcome.
    if (payload.type === 'payment.succeeded' && authoritative.status === 'PENDING') {
      const settle = (gateway as unknown as { settlePending?: (id: string) => unknown })
        .settlePending;
      if (typeof settle === 'function') {
        try {
          settle.call(gateway, payload.paymentId);
          authoritative =
            (await gateway.retrievePayment(payload.paymentId)) ?? authoritative;
        } catch {
          await this.markWebhookEvent(
            provider,
            payload.id,
            'retryable',
            'gateway_unavailable',
          );
          return { status: 'REJECTED' as const, reason: 'gateway_unavailable' };
        }
      }
    }

    // --- amount/currency authority ---------------------------------------
    // Distinguish an INCOMPLETE response from a CONFIRMED contradiction.
    // A malformed value is not evidence of anything, so it is retryable; only a
    // well-formed value that disagrees with the durable attempt is a permanent
    // rejection. In neither case is a capture ever recorded.
    const wellFormed =
      typeof authoritative.amount === 'number' &&
      Number.isFinite(authoritative.amount) &&
      typeof authoritative.currency === 'string';
    if (!wellFormed) {
      await this.markWebhookEvent(
        provider,
        payload.id,
        'retryable',
        'gateway_response_incomplete',
      );
      return {
        status: 'REJECTED' as const,
        reason: 'gateway_response_incomplete',
        attemptId: attempt.id,
        attemptStatus: attempt.status,
      };
    }
    const amountMatches =
      Math.abs(authoritative.amount - attempt.amount) <= MONEY_TOLERANCE &&
      authoritative.currency === attempt.currency;
    if (!amountMatches) {
      // The provider answered, and the answer contradicts the durable attempt.
      await this.markWebhookEvent(
        provider,
        payload.id,
        'failed',
        'gateway_amount_mismatch',
      );
      await this.recordLegacyEvent(payload.id);
      return {
        status: 'REJECTED' as const,
        reason: 'gateway_amount_mismatch',
        attemptId: attempt.id,
        attemptStatus: attempt.status,
      };
    }

    const target = statusFromGateway(authoritative.status);

    // Attempt state + ledger entry + event status + legacy archive commit
    // atomically. If this rolls back, the event stays `received` and NOT
    // archived, so a redelivery can complete the effect exactly once.
    try {
      await this.attempts.getManager().transaction(async em => {
        await this.attempts.transitionWithin(em, attempt.id, target);
        if (target === 'succeeded') {
          await this.ledger.appendWithin(em, {
            bookingId: attempt.bookingId,
            leg: 'CUSTOMER',
            type: 'capture',
            status: 'succeeded',
            amount: attempt.amount,
            currency: attempt.currency,
            attemptId: attempt.id,
            gatewayRef: payload.paymentId,
            idempotencyKey: `capture:${attempt.id}`,
          });
        }
        await em.update(
          WebhookEvent,
          { provider, eventId: payload.id },
          { status: 'processed', outcome: target, processedAt: new Date() },
        );
        // Mirror the event id into the retired archive so the two replay
        // stores cannot drift apart.
        await this.recordLegacyEvent(payload.id, em);
      });
    } catch (error) {
      if (error instanceof InvalidPaymentAttemptTransitionError) {
        // PERMANENT: the durable attempt state cannot reach the event's
        // outcome (e.g. a late failure event for a succeeded payment). A
        // redelivery must never downgrade it, so it is archived as rejected.
        await this.markWebhookEvent(
          provider,
          payload.id,
          'failed',
          'attempt_state_conflict',
        );
        await this.recordLegacyEvent(payload.id);
        return {
          status: 'REJECTED' as const,
          reason: 'attempt_state_conflict',
          attemptId: attempt.id,
          attemptStatus: attempt.status,
        };
      }
      // TRANSIENT: the effect did not commit (deadlock, connection drop, lock
      // timeout, …). Leave the event retryable and do NOT archive it — a
      // redelivery must be able to finish the job.
      await this.markWebhookEvent(provider, payload.id, 'retryable', 'effect_failed');
      return {
        status: 'REJECTED' as const,
        reason: 'effect_retryable',
        attemptId: attempt.id,
        attemptStatus: attempt.status,
      };
    }

    return { status: 'PROCESSED' as const, attemptId: attempt.id, attemptStatus: target };
  }

  /**
   * Mirror an event id into the retired `processed_webhooks` archive.
   *
   * `ON CONFLICT DO NOTHING` makes this idempotent and safe inside the effect
   * transaction, so a concurrent duplicate delivery can never abort it. The
   * archive is retained precisely so a pre-P4-2 id keeps blocking replays.
   */
  private async recordLegacyEvent(
    eventId: string,
    em?: Repository<ProcessedWebhook>['manager'],
  ): Promise<void> {
    await (em ?? this.legacyWebhooks.manager)
      .createQueryBuilder()
      .insert()
      .into(ProcessedWebhook)
      .values({ id: eventId })
      .orIgnore()
      .execute();
  }

  /**
   * Claim the event. The first delivery inserts `received`; a redelivery of an
   * event that is still `received` or explicitly `retryable` is allowed to try
   * again (so a transient failure is recoverable), while `processed`, `failed`
   * and `ignored` are settled outcomes and hard duplicates.
   */
  private async claimWebhookEvent(
    provider: string,
    eventId: string,
    eventType: string,
    payloadHash: string,
  ): Promise<{ state: 'fresh' | 'retry' | 'duplicate'; event: WebhookEvent }> {
    try {
      // An explicit INSERT, NOT `save()`: `save()` upserts on the primary key
      // and would silently RESET a processed event back to `received`.
      await this.webhookEvents
        .createQueryBuilder()
        .insert()
        .into(WebhookEvent)
        .values({ provider, eventId, eventType, payloadHash, status: 'received' })
        .execute();
      const saved = await this.webhookEvents.findOne({
        where: { provider, eventId },
      });
      return { state: 'fresh', event: saved! };
    } catch (error) {
      if ((error as { code?: string })?.code === '23505' || this.isUnique(error)) {
        const existing = await this.webhookEvents.findOne({
          where: { provider, eventId },
        });
        if (!existing) throw error;
        if ((WEBHOOK_EVENT_FINAL_STATUSES as readonly string[]).includes(existing.status)) {
          return { state: 'duplicate', event: existing };
        }
        // `received` or `retryable` — not settled, so a redelivery may retry.
        return { state: 'retry', event: existing };
      }
      throw error;
    }
  }

  /**
   * Record an event outcome.
   *
   * `processedAt` is only meaningful for a RESOLVED event, so it is left null
   * for `retryable` — an event that has not settled was not "processed".
   */
  private async markWebhookEvent(
    provider: string,
    eventId: string,
    status: 'processed' | 'retryable' | 'failed' | 'ignored',
    outcome: string,
  ): Promise<void> {
    const resolved = status !== 'retryable';
    await this.webhookEvents.update(
      { provider, eventId },
      resolved
        ? { status, outcome, processedAt: new Date() }
        : { status, outcome },
    );
  }

  private isUnique(error: unknown): boolean {
    const e = error as { code?: string; driverError?: { code?: string } };
    return e?.code === '23505' || e?.driverError?.code === '23505';
  }

  async bookingTimeline(bookingId: string, userId?: string): Promise<LedgerEntryView[]> {
    await this.requireOwnedBooking(bookingId, userId);
    const rows = await this.ledger.forBooking(bookingId);
    return rows.map(LedgerService.toView);
  }

  async bookingBalance(bookingId: string, userId?: string) {
    await this.requireOwnedBooking(bookingId, userId);
    return this.ledger.bookingBalance(bookingId);
  }

  /**
   * Ownership is derived from the durable `bookings` row, never from a
   * process-local map. A missing booking and a foreign booking produce the same
   * outcome so the endpoint cannot be used to probe for booking ids.
   */
  private async requireOwnedBooking(bookingId: string, userId?: string): Promise<Booking> {
    const booking = await this.bookings.findOne({ where: { id: bookingId } });
    if (!booking || (userId !== undefined && booking.userId !== userId)) {
      throw new NotFoundException('Booking not found.');
    }
    return booking;
  }

  private assertOwnership(
    attemptUserId: string,
    userId: string | undefined,
    attemptBookingId: string,
    bookingId: string,
  ): void {
    if (userId === undefined) return;
    if (attemptUserId !== userId) {
      throw new ForbiddenException('Payment does not belong to the caller.');
    }
    if (bookingId && attemptBookingId !== bookingId) {
      throw new BadRequestException('Payment does not belong to this booking.');
    }
  }
}
