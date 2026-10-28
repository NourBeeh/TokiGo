import {
  ArrayMaxSize,
  IsArray,
  IsIn,
  IsOptional,
  IsString,
  MaxLength,
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
}
