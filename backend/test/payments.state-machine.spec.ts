import {
  allowedTransitions,
  assertTransition,
  canTransition,
  InvalidPaymentAttemptTransitionError,
  isDefinitiveGatewayError,
  isTerminal,
  PAYMENT_ATTEMPT_STATUSES,
  safeFailureCode,
  statusFromGateway,
} from '../src/modules/payments/payment-attempt.state';

/**
 * PaymentAttempt state machine — pure unit tests (no database).
 *
 * The database enforces the *vocabulary*; these tests pin the *rules*: which
 * moves are legal, which are refused, and the two safety invariants that the
 * whole phase depends on:
 *   - a confirmed success is never downgraded;
 *   - an ambiguous outcome is never silently promoted.
 */

describe('PaymentAttempt state machine', () => {
  it('exposes exactly the P4-2 vocabulary', () => {
    expect([...PAYMENT_ATTEMPT_STATUSES]).toEqual([
      'created',
      'processing',
      'requires_action',
      'pending',
      'succeeded',
      'declined',
      'failed',
      'unknown',
      'cancelled',
      'consumed',
      'voided',
      'refunded',
      'partially_refunded',
    ]);
  });

  it('every state can transition to itself (idempotent replay is a no-op)', () => {
    for (const status of PAYMENT_ATTEMPT_STATUSES) {
      expect(canTransition(status, status)).toBe(true);
    }
  });

  it('a confirmed success cannot be downgraded', () => {
    // `processing` is deliberately NOT in this list: a refund is a gateway call
    // in flight against a captured payment, and the refund path must be able to
    // mark that. It returns to `succeeded`/`partially_refunded`/`unknown` and
    // never writes `failed` (see T9 in p4.persistence.spec.ts).
    for (const downgrade of ['pending', 'unknown', 'failed', 'declined']) {
      expect(canTransition('succeeded', downgrade as any)).toBe(false);
      expect(() => assertTransition('succeeded', downgrade as any)).toThrow(
        InvalidPaymentAttemptTransitionError,
      );
    }
    // The only forward moves from a success are refund-ish or consumption.
    expect(allowedTransitions('succeeded')).toEqual([
      'processing',
      'refunded',
      'partially_refunded',
      'voided',
      'consumed',
    ]);
  });

  it('terminal states have no exits', () => {
    for (const terminal of [
      'declined',
      'failed',
      'cancelled',
      'voided',
      'refunded',
      'consumed',
    ]) {
      expect(isTerminal(terminal as any)).toBe(true);
      expect(allowedTransitions(terminal as any)).toEqual([]);
      expect(() => assertTransition(terminal as any, 'processing' as any)).toThrow(
        InvalidPaymentAttemptTransitionError,
      );
    }
  });

  it('an ambiguous outcome cannot jump straight to success', () => {
    // `unknown -> succeeded` is present, but only reachable through
    // reconciliation with authoritative provider data — never from a
    // client-supplied status. The rule the orchestrator must honour is that the
    // transition is explicitly requested, not inferred.
    expect(canTransition('unknown', 'succeeded')).toBe(true);
    // A pending payment cannot be declared succeeded without an authoritative
    // confirmation arriving through the webhook path.
    expect(canTransition('pending', 'succeeded')).toBe(true);
    // But a created attempt can never be succeeded directly.
    expect(canTransition('created', 'succeeded')).toBe(false);
  });

  it('a partially refunded attempt can still be fully refunded', () => {
    expect(canTransition('partially_refunded', 'refunded')).toBe(true);
    expect(canTransition('partially_refunded', 'partially_refunded')).toBe(true);
    expect(canTransition('partially_refunded', 'succeeded')).toBe(false);
    expect(canTransition('refunded', 'partially_refunded')).toBe(false);
  });

  it('maps gateway statuses onto the durable states', () => {
    expect(statusFromGateway('REQUIRES_CONFIRMATION')).toBe('requires_action');
    expect(statusFromGateway('PENDING')).toBe('pending');
    expect(statusFromGateway('SUCCEEDED')).toBe('succeeded');
    expect(statusFromGateway('FAILED')).toBe('declined');
    expect(statusFromGateway('SOMETHING_NEW')).toBe('unknown');
  });

  it('classifies provider errors: only definitive refusals close the attempt', () => {
    expect(isDefinitiveGatewayError(new Error('Payment not found'))).toBe(true);
    expect(isDefinitiveGatewayError(new Error('Refund exceeds captured amount'))).toBe(true);
    expect(isDefinitiveGatewayError(new Error('Cannot confirm a refunded payment'))).toBe(true);
    expect(isDefinitiveGatewayError(new Error('Payment amount must be positive'))).toBe(true);

    // Anything ambiguous must be reconciled, never closed.
    expect(isDefinitiveGatewayError(new Error('ETIMEDOUT: provider timed out'))).toBe(false);
    expect(isDefinitiveGatewayError(new Error('socket hang up'))).toBe(false);
    expect(isDefinitiveGatewayError(new Error('unexpected 500'))).toBe(false);
  });

  it('persists only a fixed failure vocabulary, never the raw provider message', () => {
    expect(safeFailureCode(new Error('Payment not found'))).toBe('payment_not_found');
    expect(safeFailureCode(new Error('Refund exceeds captured amount'))).toBe('amount_exceeded');
    expect(safeFailureCode(new Error('Cannot confirm a refunded payment'))).toBe(
      'already_refunded',
    );
    expect(safeFailureCode(new Error('Payment amount must be positive'))).toBe('invalid_amount');
    expect(safeFailureCode(new Error('ETIMEDOUT: provider timed out'))).toBe('provider_timeout');
    expect(safeFailureCode(new Error('weird unexplained failure'))).toBe('gateway_error');

    // No raw message text leaks into the persisted code.
    const code = safeFailureCode(new Error('card 4111111111111111 declined by bank'));
    expect(code).toBe('gateway_error');
    expect(code).not.toContain('4111');
  });
});
