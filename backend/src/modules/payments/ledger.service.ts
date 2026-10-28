import { Injectable } from '@nestjs/common';

/**
 * Immutable payment ledger (spec points 36, O.8): every financial movement
 * is appended — never updated destructively. Refunds are stored as reversal
 * entries referencing the original payment.
 */

export type LedgerSide =
  | 'CUSTOMER'
  | 'PROVIDER'
  | 'GATEWAY'
  | 'WALLET'
  | 'REFUND'
  | 'FEE'
  | 'FX';

export type LedgerType =
  | 'CHARGE'
  | 'CAPTURE'
  | 'REFUND'
  | 'GATEWAY_FEE'
  | 'MARKUP'
  | 'PROVIDER_CHARGE'
  | 'FX_DIFFERENCE'
  | 'ADJUSTMENT';

export interface LedgerEntry {
  id: string;
  bookingId: string;
  paymentId?: string;
  gateway?: string;
  provider?: string;
  side: LedgerSide;
  type: LedgerType;
  amount: number;
  currency: string;
  externalReference?: string;
  metadata?: Record<string, any>;
  occurredAt: string;
}

@Injectable()
export class LedgerService {
  private readonly entries: LedgerEntry[] = [];

  append(entry: Omit<LedgerEntry, 'id' | 'occurredAt'>): LedgerEntry {
    const record: LedgerEntry = {
      ...entry,
      id: `led_${Math.random().toString(36).slice(2, 10)}${Date.now().toString(36)}`,
      occurredAt: new Date().toISOString(),
    };
    this.entries.push(record);
    return record;
  }

  forBooking(bookingId: string): LedgerEntry[] {
    return this.entries.filter(e => e.bookingId === bookingId);
  }

  /** Balanced trail check: customer charges minus refunds equal net receipts. */
  bookingBalance(bookingId: string): {
    charged: number;
    refunded: number;
    net: number;
    currency: string | null;
  } {
    const booking = this.forBooking(bookingId);
    const charged = booking
      .filter(e => e.type === 'CHARGE' || e.type === 'CAPTURE')
      .reduce((s, e) => s + e.amount, 0);
    const refunded = booking
      .filter(e => e.type === 'REFUND')
      .reduce((s, e) => s + e.amount, 0);
    const currency = booking[0]?.currency ?? null;
    return { charged, refunded, net: charged - refunded, currency };
  }
}
