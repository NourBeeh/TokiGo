import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';

import {
  PaymentTransaction,
  PaymentTransactionLeg,
  PaymentTransactionStatus,
  PaymentTransactionType,
} from '../../database/entities/payment-transaction.entity';
import { isUniqueViolation } from './payment-attempt.service';

/**
 * Durable financial ledger (P4-2).
 *
 * Every money movement is a row in `payment_transactions`. The in-memory array
 * P4-0 kept here is gone — PostgreSQL is the source of truth, and
 * `GET /payments/ledger/:bookingId` reads the table rather than a process-local
 * list that dies on restart.
 *
 * Two strictly separate legs, never merged on one row:
 *
 *  CUSTOMER — the traveller paying TokiGo. MUST reference a `payment_attempts`
 *            row, and the composite FK `(attemptId, bookingId)` makes a
 *            cross-booking customer transaction impossible.
 *  SUPPLIER — TokiGo paying the travel supplier. MUST reference a
 *            `provider_operations` row; never tied to a customer attempt.
 *
 * `idempotencyKey` is globally unique, so a retried refund/capture can never
 * produce a second financial effect.
 */

export interface AppendLedgerInput {
  bookingId: string;
  leg: PaymentTransactionLeg;
  type: PaymentTransactionType;
  status: PaymentTransactionStatus;
  amount: number;
  currency: string;
  /** CUSTOMER leg only. */
  attemptId?: string | null;
  /** SUPPLIER leg only. */
  providerOperationId?: string | null;
  gatewayRef?: string | null;
  providerRef?: string | null;
  /** One financial effect per key. Callers pass a deterministic key. */
  idempotencyKey: string;
  metadata?: Record<string, any> | null;
}

/**
 * Response shape returned by `GET /payments/ledger/:bookingId`.
 *
 * Supersedes the P4-0 in-memory shape (`side`/`paymentId`/`occurredAt`). The
 * old names were an artefact of the process-local array; the durable row is
 * the contract now. See docs/p4-2-report-*.md for the mapping.
 */
export interface LedgerEntryView {
  id: string;
  bookingId: string;
  leg: PaymentTransactionLeg;
  type: PaymentTransactionType;
  status: PaymentTransactionStatus;
  amount: number;
  currency: string;
  attemptId: string | null;
  providerOperationId: string | null;
  gatewayRef: string | null;
  providerRef: string | null;
  idempotencyKey: string;
  metadata: Record<string, any> | null;
  createdAt: string;
}

@Injectable()
export class LedgerService {
  constructor(
    @InjectRepository(PaymentTransaction)
    private readonly transactions: Repository<PaymentTransaction>,
  ) {}

  /**
   * Append a financial effect. Idempotent on `idempotencyKey`: a retry returns
   * the already-recorded row instead of creating a duplicate.
   */
  async append(input: AppendLedgerInput): Promise<PaymentTransaction> {
    const existing = await this.transactions.findOne({
      where: { idempotencyKey: input.idempotencyKey },
    });
    if (existing) {
      return existing;
    }
    try {
      return await this.transactions.save(this.transactions.create(input));
    } catch (error) {
      if (isUniqueViolation(error)) {
        const raced = await this.transactions.findOne({
          where: { idempotencyKey: input.idempotencyKey },
        });
        if (raced) {
          return raced;
        }
      }
      throw error;
    }
  }

  /**
   * Append inside a caller-managed transaction, using `ON CONFLICT DO NOTHING`
   * so a concurrent writer can never abort the surrounding transaction. Used
   * by the webhook path, where the attempt state, this entry and the event
   * status must commit together.
   */
  async appendWithin(
    em: Repository<PaymentTransaction>['manager'],
    input: AppendLedgerInput,
  ): Promise<PaymentTransaction> {
    await em
      .createQueryBuilder()
      .insert()
      .into(PaymentTransaction)
      .values(input)
      .orIgnore()
      .execute();
    const row = await em.findOne(PaymentTransaction, {
      where: { idempotencyKey: input.idempotencyKey },
    });
    if (!row) {
      throw new Error(`Ledger insert did not produce a row for ${input.idempotencyKey}.`);
    }
    return row;
  }

  async forBooking(bookingId: string): Promise<PaymentTransaction[]> {
    return this.transactions.find({
      where: { bookingId },
      order: { createdAt: 'ASC' },
    });
  }

  async forAttempt(attemptId: string): Promise<PaymentTransaction[]> {
    return this.transactions.find({
      where: { attemptId },
      order: { createdAt: 'ASC' },
    });
  }

  /**
   * Balanced trail check over the CUSTOMER leg only: captured minus refunded
   * equals net receipts. Supplier settlements are a separate obligation and are
   * deliberately excluded.
   */
  async bookingBalance(bookingId: string): Promise<{
    charged: number;
    refunded: number;
    net: number;
    currency: string | null;
  }> {
    const rows = await this.forBooking(bookingId);
    const customer = rows.filter((r) => r.leg === 'CUSTOMER');
    const charged = customer
      .filter((r) => r.type === 'capture' && r.status === 'succeeded')
      .reduce((sum, r) => sum + r.amount, 0);
    const refunded = customer
      .filter((r) => r.type === 'refund' && r.status === 'succeeded')
      .reduce((sum, r) => sum + r.amount, 0);
    const currency = customer.find((r) => r.status === 'succeeded')?.currency ?? null;
    return { charged, refunded, net: charged - refunded, currency };
  }

  /** Project a durable row onto the API view. */
  static toView(row: PaymentTransaction): LedgerEntryView {
    return {
      id: row.id,
      bookingId: row.bookingId,
      leg: row.leg,
      type: row.type,
      status: row.status,
      amount: row.amount,
      currency: row.currency,
      attemptId: row.attemptId ?? null,
      providerOperationId: row.providerOperationId ?? null,
      gatewayRef: row.gatewayRef ?? null,
      providerRef: row.providerRef ?? null,
      idempotencyKey: row.idempotencyKey,
      metadata: row.metadata ?? null,
      createdAt: row.createdAt.toISOString(),
    };
  }
}
