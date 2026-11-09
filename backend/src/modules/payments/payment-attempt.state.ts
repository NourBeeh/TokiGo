/**
 * PaymentAttempt state machine (P4-2).
 *
 * P4-1 created the `payment_attempts` table and a CHECK constraint over an
 * ad-hoc status list. P4-2 replaces that list with an explicit, documented
 * state machine so that:
 *
 *  - a confirmed success can never be downgraded by a later timeout;
 *  - an ambiguous outcome can never be promoted to success without
 *    authoritative provider confirmation;
 *  - a decline stays a decline (a retry uses a NEW idempotency key, so it
 *    creates a NEW attempt rather than mutating this one).
 *
 * The table is the durable record; this module is the rulebook. The rules are
 * enforced in the application (conditional UPDATE ... WHERE status = <from>)
 * so a losing racer fails closed instead of silently overwriting.
 *
 * NOTE: the gateway contract is the mock Egyptian gateway. It exposes
 * REQUIRES_CONFIRMATION / PENDING / SUCCEEDED / FAILED and has NO cancellation
 * operation. `cancelled` therefore exists in the model but is never entered by
 * this gateway — see `docs/p4-2-report-*.md` for the limitation.
 */

export const PAYMENT_ATTEMPT_STATUSES = [
  /** Row created; no gateway call has been made yet. */
  'created',
  /** A gateway call is in flight. */
  'processing',
  /** Gateway returned REQUIRES_CONFIRMATION — the customer must act. */
  'requires_action',
  /** Gateway returned PENDING — asynchronous completion (3DS / bank). */
  'pending',
  /** Authoritative confirmation that money was captured. Terminal. */
  'succeeded',
  /** The customer's payment method was refused. Terminal. */
  'declined',
  /** Definitive operational failure (no money moved). Terminal. */
  'failed',
  /**
   * Ambiguous outcome (timeout / unknown). NOT a failure: no automatic retry
   * and no automatic charge. Requires reconciliation against authoritative
   * provider data.
   */
  'unknown',
  /** A real cancellation operation completed. Terminal. */
  'cancelled',
  /** Consumed by a booking (P4-3). Terminal. */
  'consumed',
  /** Voided (authorized-but-not-captured released). Terminal. */
  'voided',
  /** Fully refunded. Terminal. */
  'refunded',
  /** Partially refunded — further refunds may still be possible. */
  'partially_refunded',
] as const;

export type PaymentAttemptStatus = (typeof PAYMENT_ATTEMPT_STATUSES)[number];

/** Terminal states never transition again. */
export const PAYMENT_ATTEMPT_TERMINAL_STATUSES = [
  'declined',
  'failed',
  'cancelled',
  'consumed',
  'voided',
  'refunded',
] as const;

/**
 * Allowed forward transitions. A state may always transition to itself — that
 * is how an idempotent replay (a redelivered webhook, a retried confirm) is a
 * clean no-op instead of an error.
 *
 * Deliberately absent:
 *  - succeeded → pending | declined | voided-from-processing | unknown | failed
 *    (a confirmed success is never downgraded by a later timeout or error);
 *  - unknown → succeeded | failed | declined are present BUT callers must go
 *    through `reconcile()` with authoritative provider data, never through a
 *    client-supplied status;
 *  - declined | failed | cancelled | voided | refunded | consumed → *
 *    (terminal; a retry creates a new attempt with a new idempotency key).
 *
 * `succeeded → processing` exists ONLY for the refund/void paths: a refund is
 * a gateway call in flight against a captured payment, so the row must be
 * guarded against a concurrent second refund. The refund code is the only
 * caller allowed to make that move, and its exits are constrained: a
 * definitive provider refusal returns the attempt to its PREVIOUS state
 * (`succeeded` / `partially_refunded`) and an ambiguous outcome goes to
 * `unknown`. It never writes `failed`, so a timeout cannot turn a confirmed
 * success into a failure.
 */
const TRANSITIONS: Record<PaymentAttemptStatus, readonly PaymentAttemptStatus[]> = {
  created: ['processing', 'failed', 'cancelled'],
  processing: [
    'requires_action',
    'pending',
    'succeeded',
    'declined',
    'failed',
    'unknown',
    'cancelled',
    'refunded',
    'partially_refunded',
  ],
  requires_action: ['processing', 'pending', 'declined', 'failed', 'unknown', 'cancelled'],
  pending: ['succeeded', 'declined', 'failed', 'unknown', 'cancelled'],
  // Reconciliation-only exits. A caller must supply authoritative provider data.
  unknown: ['processing', 'succeeded', 'declined', 'failed', 'cancelled'],
  succeeded: ['processing', 'refunded', 'partially_refunded', 'voided', 'consumed'],
  declined: [],
  failed: [],
  cancelled: [],
  consumed: [],
  voided: [],
  refunded: [],
  partially_refunded: ['processing', 'refunded', 'partially_refunded'],
};

export class InvalidPaymentAttemptTransitionError extends Error {
  constructor(
    public readonly from: PaymentAttemptStatus,
    public readonly to: PaymentAttemptStatus,
  ) {
    super(`Invalid payment attempt transition: ${from} -> ${to}`);
    this.name = 'InvalidPaymentAttemptTransitionError';
  }
}

export function allowedTransitions(from: PaymentAttemptStatus): readonly PaymentAttemptStatus[] {
  return TRANSITIONS[from] ?? [];
}

export function canTransition(from: PaymentAttemptStatus, to: PaymentAttemptStatus): boolean {
  return from === to || allowedTransitions(from).includes(to);
}

/** Throws {@link InvalidPaymentAttemptTransitionError} when the move is illegal. */
export function assertTransition(from: PaymentAttemptStatus, to: PaymentAttemptStatus): void {
  if (!canTransition(from, to)) {
    throw new InvalidPaymentAttemptTransitionError(from, to);
  }
}

export function isTerminal(status: PaymentAttemptStatus): boolean {
  return (PAYMENT_ATTEMPT_TERMINAL_STATUSES as readonly string[]).includes(status);
}

/**
 * Map a gateway intent status onto the durable attempt state.
 *
 * The mock gateway only ever produces FAILED for a declined method, so FAILED
 * maps to `declined` rather than the operational `failed`.
 */
export function statusFromGateway(status: string): PaymentAttemptStatus {
  switch (status) {
    case 'REQUIRES_CONFIRMATION':
      return 'requires_action';
    case 'PENDING':
      return 'pending';
    case 'SUCCEEDED':
      return 'succeeded';
    case 'FAILED':
      return 'declined';
    default:
      return 'unknown';
  }
}

/**
 * Classify a thrown gateway error.
 *
 * `failed`  — the provider definitively says the operation did not happen
 *              (no money moved), so the attempt can be closed.
 * `unknown` — anything else (timeout, network, unexpected). The money MAY have
 *              moved, so the attempt must be reconciled, never auto-retried.
 */
export function isDefinitiveGatewayError(error: unknown): boolean {
  const message = (error instanceof Error ? error.message : String(error)).toLowerCase();
  if (message.includes('not found')) return true;
  if (message.includes('exceeds')) return true;
  if (message.includes('already refunded')) return true;
  if (message.includes('cannot confirm')) return true;
  if (message.includes('must be positive')) return true;
  if (message.includes('only succeeded')) return true;
  return false;
}

/**
 * Normalised, non-sensitive failure code for persistence.
 *
 * The raw gateway message is NEVER persisted: it can carry provider request
 * ids, card references or other operational detail. Only a fixed vocabulary
 * is stored.
 */
export function safeFailureCode(error: unknown): string {
  const message = (error instanceof Error ? error.message : String(error)).toLowerCase();
  if (message.includes('not found')) return 'payment_not_found';
  if (message.includes('exceeds')) return 'amount_exceeded';
  if (message.includes('already refunded')) return 'already_refunded';
  if (message.includes('cannot confirm')) return 'already_refunded';
  if (message.includes('must be positive')) return 'invalid_amount';
  if (message.includes('only succeeded')) return 'not_refundable';
  if (
    message.includes('timeout') ||
    message.includes('timed out') ||
    message.includes('econn') ||
    message.includes('socket')
  ) {
    return 'provider_timeout';
  }
  return 'gateway_error';
}
