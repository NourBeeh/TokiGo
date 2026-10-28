/**
 * Payment abstraction (spec points 31-33, O.7) — gateway routing by
 * paymentRegion. The Egypt gateway is implemented first as a
 * deterministic mock with real idempotency/webhook semantics, ready to be
 * swapped for a production PSP adapter without touching booking services.
 */

export interface CreatePaymentIntentInput {
  /** Internal booking/order reference this payment belongs to. */
  bookingId: string;
  /** Idempotency key bound to the money-changing operation (spec point 10). */
  idempotencyKey: string;
  amount: number;
  currency: string;
  market: string;
  methods?: string[];
}

export interface PaymentIntent {
  paymentId: string;
  bookingId: string;
  amount: number;
  currency: string;
  status: PaymentStatus;
  clientSecret: string;
  createdAt: string;
}

export type PaymentStatus =
  | 'REQUIRES_CONFIRMATION'
  | 'PENDING'
  | 'SUCCEEDED'
  | 'FAILED'
  | 'REFUNDED';

export interface ConfirmPaymentInput {
  paymentId: string;
  /** Mock method — a real gateway would use a tokenized card reference. */
  methodReference: 'CARD_SUCCESS' | 'CARD_3DS' | 'CARD_DECLINED' | 'WALLET';
  idempotencyKey: string;
}

export interface RefundInput {
  paymentId: string;
  amount: number;
  reason?: string;
  idempotencyKey: string;
}

export interface WebhookPayload {
  id: string;
  paymentId: string;
  type: 'payment.succeeded' | 'payment.failed' | 'payment.refunded';
  signature: string;
  occurredAt: string;
}

export interface PaymentGateway {
  readonly gatewayId: string;
  readonly supportsMarket: string[];
  createPaymentIntent(input: CreatePaymentIntentInput): Promise<PaymentIntent>;
  confirmPayment(input: ConfirmPaymentInput): Promise<PaymentIntent>;
  refundPayment(input: RefundInput): Promise<PaymentIntent>;
  retrievePayment(paymentId: string): Promise<PaymentIntent | null>;
  verifyWebhook(payload: WebhookPayload): boolean;
}

export function routesForMarket(paymentRegion: string): string | null {
  // Config-driven routing table (spec point 33): EG first; SA/AE activate
  // only after gateway onboarding approval.
  switch (paymentRegion) {
    case 'EG':
      return 'EG';
    default:
      return null;
  }
}
