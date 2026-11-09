import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { QueryFailedError, Repository } from 'typeorm';

import { PaymentAttempt, PaymentAttemptStatus } from '../../database/entities/payment-attempt.entity';
import { assertTransition } from './payment-attempt.state';

/**
 * Durable payment-attempt ownership, idempotency and state transitions (P4-2).
 *
 * PostgreSQL is the single source of truth. The in-memory
 * `paymentOwners` / `bookingOwners` maps that P4-0 kept in `PaymentService`
 * are gone: ownership is now derived from `payment_attempts."userId"` (which
 * the database itself ties to `bookings."userId"` through a composite FK).
 *
 * Idempotency is enforced by `UNIQUE ("userId", "idempotencyKey")` and is
 * claimed with an insert-then-reselect protocol: the database decides the
 * winner of a concurrent race, never a check-then-insert sequence.
 */

export interface ClaimAttemptInput {
  userId: string;
  bookingId: string;
  idempotencyKey: string;
  amount: number;
  currency: string;
  gatewayId: string;
  method?: string | null;
}

export interface ClaimAttemptResult {
  attempt: PaymentAttempt;
  /** False when an existing durable attempt was returned (retry / race loser). */
  created: boolean;
}

export type TransitionResult =
  | { outcome: 'transitioned'; attempt: PaymentAttempt }
  | { outcome: 'noop'; attempt: PaymentAttempt }
  | { outcome: 'conflict'; attempt: PaymentAttempt };

export function isUniqueViolation(error: unknown): boolean {
  const e = error as { code?: string; driverError?: { code?: string }; cause?: { code?: string } };
  const code = e?.code ?? e?.driverError?.code ?? e?.cause?.code;
  return code === '23505' || (error instanceof QueryFailedError && code === '23505');
}

@Injectable()
export class PaymentAttemptService {
  constructor(
    @InjectRepository(PaymentAttempt)
    private readonly attempts: Repository<PaymentAttempt>,
  ) {}

  /**
   * Return the durable attempt for `(userId, idempotencyKey)`, creating it when
   * this is the first request.
   *
   * Concurrency: two requests with the same key both attempt the insert. The
   * unique constraint admits exactly one; the loser catches the violation and
   * re-selects the winner's row. No second attempt is ever created, and a
   * check-then-insert window is never relied upon.
   */
  async claim(input: ClaimAttemptInput): Promise<ClaimAttemptResult> {
    const existing = await this.attempts.findOne({
      where: { userId: input.userId, idempotencyKey: input.idempotencyKey },
    });
    if (existing) {
      return { attempt: existing, created: false };
    }

    const attemptNo = await this.nextAttemptNo(input.bookingId);
    try {
      const saved = await this.attempts.save(
        this.attempts.create({
          bookingId: input.bookingId,
          userId: input.userId,
          attemptNo,
          idempotencyKey: input.idempotencyKey,
          amount: input.amount,
          currency: input.currency,
          status: 'created',
          gatewayId: input.gatewayId,
          method: input.method ?? null,
        }),
      );
      return { attempt: saved, created: true };
    } catch (error) {
      if (isUniqueViolation(error)) {
        const raced = await this.attempts.findOne({
          where: { userId: input.userId, idempotencyKey: input.idempotencyKey },
        });
        if (raced) {
          return { attempt: raced, created: false };
        }
      }
      throw error;
    }
  }

  /** 1-based attempt number within the booking (diagnostics/ordering only). */
  private async nextAttemptNo(bookingId: string): Promise<number> {
    const rows = await this.attempts.query(
      `SELECT COALESCE(MAX("attemptNo"), 0) + 1 AS next FROM payment_attempts WHERE "bookingId" = $1`,
      [bookingId],
    );
    return Number(rows[0]?.next ?? 1);
  }

  /** The TypeORM manager, exposed so callers can run an atomic transaction. */
  getManager(): Repository<PaymentAttempt>['manager'] {
    return this.attempts.manager;
  }

  async findById(attemptId: string): Promise<PaymentAttempt | null> {
    return this.attempts.findOne({ where: { id: attemptId } });
  }

  /**
   * Ownership-aware lookup. Returns null when the attempt does not exist or
   * belongs to another user, so the caller can answer with a single
   * not-found/forbidden outcome without leaking existence.
   */
  async findOwned(userId: string, attemptId: string): Promise<PaymentAttempt | null> {
    return this.attempts.findOne({ where: { id: attemptId, userId } });
  }

  /** Lookup by the gateway's own reference (the `paymentId`). */
  async findByGatewayRef(gatewayId: string, gatewayRef: string): Promise<PaymentAttempt | null> {
    return this.attempts.findOne({ where: { gatewayId, gatewayRef } });
  }

  async listForBooking(bookingId: string): Promise<PaymentAttempt[]> {
    return this.attempts.find({
      where: { bookingId },
      order: { attemptNo: 'ASC', createdAt: 'ASC' },
    });
  }

  /**
   * Apply a state transition with a compare-and-set update.
   *
   * The read validates the transition against the state machine; the UPDATE is
   * conditional on the row still being in that state, so a concurrent writer
   * that moved the row first makes this call report `conflict` instead of
   * overwriting. A single conditional UPDATE is atomic — no explicit
   * transaction (and therefore no open transaction) is needed here.
   */
  async transition(
    attemptId: string,
    to: PaymentAttemptStatus,
    patch: Partial<PaymentAttempt> = {},
  ): Promise<TransitionResult> {
    const current = await this.attempts.findOne({ where: { id: attemptId } });
    if (!current) {
      throw new NotFoundException('Payment attempt not found.');
    }
    assertTransition(current.status, to);

    if (current.status === to) {
      if (Object.keys(patch).length > 0) {
        await this.attempts.update({ id: attemptId, status: to }, patch);
      }
      return { outcome: 'noop', attempt: { ...current, ...patch } };
    }

    const result = await this.attempts.update(
      { id: attemptId, status: current.status },
      { status: to, ...patch },
    );
    if (!result.affected) {
      const now = await this.attempts.findOne({ where: { id: attemptId } });
      return { outcome: 'conflict', attempt: now ?? current };
    }
    return { outcome: 'transitioned', attempt: { ...current, status: to, ...patch } };
  }

  /**
   * Same compare-and-set, but inside a caller-managed transaction so the
   * attempt state, the ledger entry and the webhook event status commit
   * together. Used only by the webhook path.
   */
  async transitionWithin(
    em: Repository<PaymentAttempt>['manager'],
    attemptId: string,
    to: PaymentAttemptStatus,
    patch: Partial<PaymentAttempt> = {},
  ): Promise<TransitionResult> {
    const current = await em.findOne(PaymentAttempt, { where: { id: attemptId } });
    if (!current) {
      throw new NotFoundException('Payment attempt not found.');
    }
    assertTransition(current.status, to);

    if (current.status === to) {
      if (Object.keys(patch).length > 0) {
        await em.update(PaymentAttempt, { id: attemptId, status: to }, patch);
      }
      return { outcome: 'noop', attempt: { ...current, ...patch } };
    }

    const result = await em.update(
      PaymentAttempt,
      { id: attemptId, status: current.status },
      { status: to, ...patch },
    );
    if (!result.affected) {
      const now = await em.findOne(PaymentAttempt, { where: { id: attemptId } });
      return { outcome: 'conflict', attempt: now ?? current };
    }
    return { outcome: 'transitioned', attempt: { ...current, status: to, ...patch } };
  }
}
