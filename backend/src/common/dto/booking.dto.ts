import {
  ArrayMaxSize,
  IsArray,
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

/**
 * Booking DTOs (Phase 4A) — validated at the HTTP boundary (global
 * ValidationPipe with whitelist + forbidNonWhitelisted in main.ts).
 *
 * SECURITY: userId is NEVER part of any DTO. Ownership is derived from the
 * JWT and enforced in the service; a client can never book on behalf of
 * another user. Prices are NEVER accepted from the client either — the
 * authoritative amount always comes from a provider-side revalidation.
 */

export const BOOKING_TYPES = ['flight', 'hotel', 'car', 'package'] as const;

export class PrepareBookingDto {
  @IsString()
  @MinLength(1)
  @MaxLength(200)
  offerId!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(80)
  providerId!: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  searchId?: string;

  @IsOptional()
  @IsIn(BOOKING_TYPES as unknown as string[])
  offerType?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  providerName?: string;
}

export class RevalidateBookingDto {
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  bookingId!: string;
}

export class CreateBookingDto {
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  bookingId!: string;

  /** Mandatory idempotency key — a retried create can never double-book. */
  @IsString()
  @MinLength(1)
  @MaxLength(200)
  idempotencyKey!: string;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(20)
  travelers?: any[];

  /**
   * The exact verified payment attempt to consume. Optional for clients: when
   * omitted the server auto-selects only when EXACTLY ONE verified attempt
   * matches the booking, user, amount, currency and accepted price version.
   * Supplying an id never bypasses those checks.
   */
  @IsOptional()
  @IsUUID()
  paymentAttemptId?: string;
}

export const PRICE_CHANGE_DECISIONS = ['accept', 'decline'] as const;

/**
 * Explicit customer decision on a revalidated price/terms change.
 *
 * The `expected*` fields are the values the customer was SHOWN. The service
 * rejects the decision when they no longer match the stored revalidated state,
 * so a stale screen can never accept a different amount or terms version.
 * Prices are still never trusted from the body as the authoritative amount —
 * the service stores its own provider-derived snapshot.
 */
export class PriceChangeDecisionDto {
  @IsIn(PRICE_CHANGE_DECISIONS as unknown as string[])
  decision!: 'accept' | 'decline';

  @IsOptional()
  @IsNumber()
  @Min(0)
  expectedPrice?: number;

  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(8)
  expectedCurrency?: string;

  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(200)
  expectedTermsVersion?: string;
}

export const RECONCILIATION_OUTCOMES = ['confirmed', 'not_found'] as const;

/**
 * Explicit, admin-only resolution of an unknown provider booking outcome.
 *
 * This is an operator statement backed by evidence gathered OUTSIDE the
 * automatic flow (provider dashboard / support). The backend deliberately
 * does not invent a lookup call: it records the resolution durably. A
 * `confirmed` outcome must name the provider reference/id that proves the
 * booking exists. A `not_found` outcome is the only way to free the retained
 * idempotency key for a new, explicit attempt.
 */
export class ReconcileBookingDto {
  @IsIn(RECONCILIATION_OUTCOMES as unknown as string[])
  outcome!: 'confirmed' | 'not_found';

  /** Provider confirmation reference (PNR / hotel confirmation code). */
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(200)
  providerReference?: string;

  /** Provider-side booking/order id, when that is the available evidence. */
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(200)
  providerBookingId?: string;

  /** Investigation note (no credentials or card data). */
  @IsOptional()
  @IsString()
  @MaxLength(1000)
  note?: string;
}
