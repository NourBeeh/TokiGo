import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as crypto from 'crypto';
import {
  ConfirmPaymentInput,
  CreatePaymentIntentInput,
  PaymentGateway,
  PaymentIntent,
  PaymentStatus,
  RefundInput,
  WebhookPayload,
} from './payment.gateway';
import { isProductionRuntime } from '../../common/runtime/runtime';

/**
 * Deterministic mock Egyptian gateway (spec point 32) — plugs into the same
 * PaymentGateway interface a production PSP adapter will implement.
 *
 * Semantics preserved from the spec:
 *  - idempotency: repeating create/confirm/refund with the same key returns
 *    the original result (point 10)
 *  - webhook signing + verification (point 11)
 *  - 3DS-style pending state (CARD_3DS -> PENDING until the simulated
 *    webhook completes it — mirroring async recovery flows, point O.9)
 */

/** Minimum signing-key length accepted in production. */
const MIN_SIGNING_KEY_BYTES = 16;

/** Values that must never be accepted as a production signing key. */
const WEAK_SIGNING_KEYS = new Set([
  'dev_only_signing_key',
  'test-signing-key',
  'p4-test-signing-key',
  'changeme',
  'secret',
]);

const isProduction = (): boolean => isProductionRuntime();

/**
 * Resolve and validate the webhook signing key.
 *
 * The key is mandatory in every environment: without it a webhook signature
 * cannot be verified, so the gateway refuses to construct rather than run
 * open. Production additionally rejects known development/test values and
 * short keys — a predictable HMAC secret lets anyone forge a "successful"
 * payment event.
 */
export function resolveWebhookSigningKey(config?: ConfigService): string {
  const secret =
    (config ? config.get<string>('WEBHOOK_SIGNING_KEY') : undefined) ??
    process.env.WEBHOOK_SIGNING_KEY;

  if (!secret) {
    throw new Error(
      'WEBHOOK_SIGNING_KEY must be set. The payment gateway cannot verify ' +
        'webhook signatures without it, so the backend refuses to start.',
    );
  }

  if (isProduction()) {
    if (WEAK_SIGNING_KEYS.has(secret)) {
      throw new Error(
        'WEBHOOK_SIGNING_KEY is a known development/test value and must not ' +
          'be used in production.',
      );
    }
    if (Buffer.byteLength(secret, 'utf8') < MIN_SIGNING_KEY_BYTES) {
      throw new Error(
        `WEBHOOK_SIGNING_KEY must be at least ${MIN_SIGNING_KEY_BYTES} bytes.`,
      );
    }
  }

  return secret;
}

export function signMockWebhook(payload: Omit<WebhookPayload, 'signature'>): string {
  const secret = resolveWebhookSigningKey();
  return crypto
    .createHmac('sha256', secret)
    .update(`${payload.id}:${payload.paymentId}`)
    .digest('hex');
}

@Injectable()
export class MockEgyptGateway implements PaymentGateway {
  readonly gatewayId = 'mock-egypt-gateway';
  readonly supportsMarket = ['EG'];

  private readonly signingKey: string;
  private readonly intents = new Map<string, PaymentIntent>();
  private readonly idempotencyResults = new Map<string, PaymentIntent>();

  constructor(config?: ConfigService) {
    this.assertTestOnly('constructor');
    this.signingKey = resolveWebhookSigningKey(config);
  }

  /**
   * Defense in depth: even if an instance is constructed before the runtime is
   * classified, no financial operation may execute in production.
   */
  private assertTestOnly(operation: string): void {
    if (isProductionRuntime()) {
      throw new Error(
        `MockEgyptGateway.${operation} is test-only and must never run in ` +
          'production. No verified real payment provider is configured.',
      );
    }
  }

  async createPaymentIntent(input: CreatePaymentIntentInput): Promise<PaymentIntent> {
    this.assertTestOnly('createPaymentIntent');
    const existing = this.idempotencyResults.get(`create:${input.idempotencyKey}`);
    if (existing) return existing;

    if (input.amount <= 0) {
      throw new Error('Payment amount must be positive');
    }

    const intent: PaymentIntent = {
      paymentId: `pay_${randomId()}`,
      bookingId: input.bookingId,
      amount: input.amount,
      currency: input.currency,
      status: 'REQUIRES_CONFIRMATION',
      clientSecret: `secret_${randomId()}`,
      createdAt: new Date().toISOString(),
    };
    this.intents.set(intent.paymentId, intent);
    this.idempotencyResults.set(`create:${input.idempotencyKey}`, intent);
    return intent;
  }

  async confirmPayment(input: ConfirmPaymentInput): Promise<PaymentIntent> {
    this.assertTestOnly('confirmPayment');
    const existing = this.idempotencyResults.get(`confirm:${input.idempotencyKey}`);
    if (existing) return existing;

    const intent = this.intents.get(input.paymentId);
    if (!intent) throw new Error('Payment not found');
    if (intent.status === 'SUCCEEDED') return intent;
    if (intent.status === 'REFUNDED') throw new Error('Cannot confirm a refunded payment');

    let next: PaymentStatus;
    switch (input.methodReference) {
      case 'CARD_SUCCESS':
      case 'WALLET':
        next = 'SUCCEEDED';
        break;
      case 'CARD_3DS':
        // Async completion — the simulated webhook finishes it (O.9).
        next = 'PENDING';
        break;
      case 'CARD_DECLINED':
      default:
        next = 'FAILED';
        break;
    }

    const updated: PaymentIntent = { ...intent, status: next };
    this.intents.set(intent.paymentId, updated);
    this.idempotencyResults.set(`confirm:${input.idempotencyKey}`, updated);
    return updated;
  }

  async refundPayment(input: RefundInput): Promise<PaymentIntent> {
    this.assertTestOnly('refundPayment');
    const existing = this.idempotencyResults.get(`refund:${input.idempotencyKey}`);
    if (existing) return existing;

    const intent = this.intents.get(input.paymentId);
    if (!intent) throw new Error('Payment not found');
    if (intent.status !== 'SUCCEEDED') throw new Error('Only succeeded payments can be refunded');
    if (input.amount > intent.amount) throw new Error('Refund exceeds captured amount');

    const updated: PaymentIntent = { ...intent, status: 'REFUNDED' };
    this.intents.set(intent.paymentId, updated);
    this.idempotencyResults.set(`refund:${input.idempotencyKey}`, updated);
    return updated;
  }

  async retrievePayment(paymentId: string): Promise<PaymentIntent | null> {
    return this.intents.get(paymentId) ?? null;
  }

  /** Simulated PSP webhook signature verification (spec point 11). */
  verifyWebhook(payload: WebhookPayload): boolean {
    // HMAC-SHA256 over "id:paymentId", constant-time compare.
    const expected = crypto
      .createHmac('sha256', this.signingKey)
      .update(`${payload.id}:${payload.paymentId}`)
      .digest('hex');
    try {
      return crypto.timingSafeEqual(
        Buffer.from(payload.signature, 'utf8'),
        Buffer.from(expected, 'utf8'),
      );
    } catch {
      return false;
    }
  }

  /** Test/deterministic hook: complete a 3DS PENDING payment. */
  settlePending(paymentId: string): PaymentIntent | null {
    this.assertTestOnly('settlePending');
    const intent = this.intents.get(paymentId);
    if (!intent || intent.status !== 'PENDING') return null;
    const updated: PaymentIntent = { ...intent, status: 'SUCCEEDED' };
    this.intents.set(paymentId, updated);
    return updated;
  }
}

function randomId(): string {
  return Math.random().toString(36).slice(2, 12) + Date.now().toString(36);
}
