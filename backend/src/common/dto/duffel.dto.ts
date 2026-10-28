import { Transform } from 'class-transformer';
import {
  ArrayNotEmpty,
  IsArray,
  IsISO8601,
  IsInt,
  IsNotEmpty,
  IsObject,
  IsString,
  Matches,
  Max,
  Min,
  MinLength,
} from 'class-validator';

/**
 * Duffel HTTP contracts (Stage-2 refactor, 2026-10-25).
 *
 * The controller previously took inline `any[]` bodies: `create-booking`
 * forwarded whatever the caller sent straight to the airline provider — an
 * unauthenticated endpoint that could spend real money. The bodies are now
 * validated shapes, and the booking route is JWT-guarded.
 *
 * The passenger/payment ITEMS stay provider-shaped: Duffel owns that schema
 * and duplicating it here would drift. The contract pinned here is the part we
 * actually depend on — a non-empty array of objects, sent with a real offer id.
 */

/** Flight search (public: it only reads prices). */
export class DuffelFlightSearchDto {
  /** IATA airport code, e.g. CAI. */
  @Transform(({ value }) =>
    typeof value === 'string' ? value.trim().toUpperCase() : value,
  )
  @IsString()
  @MinLength(3)
  @Matches(/^[A-Z]{3}$/, { message: 'origin must be a 3-letter IATA code' })
  origin!: string;

  @Transform(({ value }) =>
    typeof value === 'string' ? value.trim().toUpperCase() : value,
  )
  @IsString()
  @MinLength(3)
  @Matches(/^[A-Z]{3}$/, { message: 'destination must be a 3-letter IATA code' })
  destination!: string;

  /** ISO-8601 date (YYYY-MM-DD accepted). */
  @IsISO8601()
  departureDate!: string;

  @IsInt()
  @Min(1)
  @Max(9)
  passengers!: number;
}

/** Booking creation (JWT-guarded: it moves money). */
export class DuffelCreateBookingDto {
  @IsString()
  @IsNotEmpty()
  offerId!: string;

  /** Provider-shaped passenger objects, forwarded verbatim. */
  @IsArray()
  @ArrayNotEmpty()
  @IsObject({ each: true, message: 'each passenger must be an object' })
  passengers!: Record<string, any>[];

  /** Provider-shaped payment objects, forwarded verbatim. */
  @IsArray()
  @ArrayNotEmpty()
  @IsObject({ each: true, message: 'each payment must be an object' })
  payments!: Record<string, any>[];
}
