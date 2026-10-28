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

const DEV_FALLBACK_SIGNING_KEY = 'dev-only-insecure-webhook-key';

export function signMockWebhook(payload: Omit<WebhookPayload, 'signature'>): string {
  const secret =
    process.env.WEBHOOK_SIGNING_KEY ?? DEV_FALLBACK_SIGNING_KEY;
  if (secret === DEV_FALLBACK_SIGNING_KEY) {
    // eslint-disable-next-line no-console
    console.warn(
      '[MockEgyptGateway] WEBHOOK_SIGNING_KEY not set — using INSECURE dev fallback.',
    );
  }
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
    this.signingKey =
      (config ? config.get<string>('WEBHOOK_SIGNING_KEY') : undefined) ??
      process.env.WEBHOOK_SIGNING_KEY ??
      'dev-only-insecure-webhook-key';
    if (this.signingKey === 'dev-only-insecure-webhook-key') {
      // eslint-disable-next-line no-console
      console.warn(
        '[MockEgyptGateway] WEBHOOK_SIGNING_KEY not set — using INSECURE dev fallback.',
      );
    }
  }

  async createPaymentIntent(input: CreatePaymentIntentInput): Promise<PaymentIntent> {
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

export const MOCK_SIGNATURE_SECRET =
  process.env.WEBHOOK_SIGNING_KEY ?? 'dev-only-insecure-webhook-key';
