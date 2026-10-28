import {
  IsIn,
  IsISO8601,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Matches,
  Min,
  MinLength,
} from 'class-validator';

/**
 * Payment contracts (Stage-2 refactor, 2026-10-25).
 *
 * These used to be plain classes declared INSIDE the controller with no
 * decorators at all. The global ValidationPipe runs with `whitelist: true` and
 * `forbidNonWhitelisted: true`, and an undecorated class has ZERO allowed
 * properties — so every `/payments/*` POST was rejected with
 * 400 "property X should not exist" before the handler ever ran. Checkout
 * therefore always fell back to "Payment unavailable for this market".
 *
 * The fields below are exactly what the Flutter checkout sends
 * (`lib/features/booking/application/services/checkout_payment_service.dart`);
 * adding a field to that client without adding it here is a 400, and that is
 * the intended behaviour.
 */

/** Intent: what the customer is about to pay for. */
export class CreatePaymentDto {
  @IsString()
  @MinLength(1)
  bookingId!: string;

  /** Minor-unit-free decimal amount as the client quoted it. */
  @IsNumber()
  @Min(0)
  amount!: number;

  /** ISO-4217, e.g. EGP / USD. */
  @IsString()
  @Matches(/^[A-Z]{3}$/, { message: 'currency must be an ISO-4217 code' })
  currency!: string;

  /** Market the payment is routed through (EG, AE, …). */
  @IsString()
  @Matches(/^[A-Za-z]{2,3}$/, { message: 'market must be a 2-3 letter code' })
  market!: string;

  /** Client-generated; the gateway deduplicates on it (spec point 10). */
  @IsString()
  @MinLength(1)
  idempotencyKey!: string;
}

/** Confirm: the customer picked a method for an existing intent. */
export class ConfirmPaymentDto {
  @IsString()
  @MinLength(1)
  paymentId!: string;

  @IsIn(['CARD_SUCCESS', 'CARD_3DS', 'CARD_DECLINED', 'WALLET'])
  methodReference!: 'CARD_SUCCESS' | 'CARD_3DS' | 'CARD_DECLINED' | 'WALLET';

  @IsString()
  @Matches(/^[A-Za-z]{2,3}$/, { message: 'market must be a 2-3 letter code' })
  market!: string;

  @IsString()
  @MinLength(1)
  idempotencyKey!: string;

  @IsString()
  @MinLength(1)
  bookingId!: string;
}

/** Refund: full or partial, always tied to the original intent. */
export class RefundDto {
  @IsString()
  @MinLength(1)
  paymentId!: string;

  @IsNumber()
  @Min(0)
  amount!: number;

  @IsOptional()
  @IsString()
  reason?: string;

  @IsString()
  @Matches(/^[A-Za-z]{2,3}$/, { message: 'market must be a 2-3 letter code' })
  market!: string;

  @IsString()
  @MinLength(1)
  idempotencyKey!: string;

  @IsString()
  @MinLength(1)
  bookingId!: string;
}

/** Gateway callback. The signature is verified by the gateway, not here. */
export class WebhookDto {
  @IsString()
  @MinLength(1)
  id!: string;

  @IsString()
  @MinLength(1)
  paymentId!: string;

  @IsIn(['payment.succeeded', 'payment.failed', 'payment.refunded'])
  type!: 'payment.succeeded' | 'payment.failed' | 'payment.refunded';

  @IsString()
  @IsNotEmpty()
  signature!: string;

  @IsISO8601()
  occurredAt!: string;

  @IsOptional()
  @IsString()
  @Matches(/^[A-Za-z]{2,3}$/, { message: 'market must be a 2-3 letter code' })
  market?: string;
}
