import {
  IsInt,
  IsISO8601,
  IsOptional,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { Type } from 'class-transformer';

/**
 * GET /home/nearby-stays query contract.
 *
 * The center is either explicit GPS (`lat`/`lng`) or a user-selected `city`
 * (with its `country`). There is deliberately NO country-wide default: when
 * neither is supplied the endpoint answers `locationRequired: true`.
 */
export class NearbyStaysQueryDto {
  @IsOptional()
  @Type(() => Number)
  @Min(-90)
  @Max(90)
  lat?: number;

  @IsOptional()
  @Type(() => Number)
  @Min(-180)
  @Max(180)
  lng?: number;

  /** GPS accuracy in metres; a coarse fix lowers the reported confidence. */
  @IsOptional()
  @Type(() => Number)
  @Min(0)
  @Max(100_000)
  accuracy?: number;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  @Matches(/^[^\x00-\x1f]*$/, { message: 'city contains control characters' })
  city?: string;

  /**
   * Canonical city id from `GET /geo/cities`. When supplied it is an explicit
   * city selection and takes precedence over GPS coordinates.
   */
  @IsOptional()
  @IsString()
  @MaxLength(64)
  @Matches(/^[a-z0-9-]+$/, { message: 'cityId must be a canonical slug' })
  cityId?: string;

  @IsOptional()
  @IsString()
  @Matches(/^[A-Za-z]{2}$/, { message: 'country must be ISO-3166-1 alpha-2' })
  country?: string;

  @IsOptional()
  @IsString()
  @Matches(/^(en|ar)$/, { message: 'language must be en or ar' })
  language?: string;

  @IsOptional()
  @IsString()
  @Matches(/^[A-Za-z]{3}$/, { message: 'currency must be ISO-4217 alpha-3' })
  currency?: string;

  /** Guest residency/nationality required by the provider (default EG). */
  @IsOptional()
  @IsString()
  @Matches(/^[A-Za-z]{2}$/, { message: 'nationality must be ISO-3166-1 alpha-2' })
  nationality?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(8)
  adults?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(4)
  rooms?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(24)
  limit?: number;

  /** IANA timezone for the promotional date window (e.g. Africa/Cairo). */
  @IsOptional()
  @IsString()
  @MaxLength(64)
  @Matches(/^[^\x00-\x1f]*$/, { message: 'timezone contains control characters' })
  timezone?: string;

  /**
   * First promotional night (`YYYY-MM-DD`). Optional: the server starts the
   * seven-night window at today in the requested timezone.
   */
  @IsOptional()
  @IsISO8601({ strict: false })
  fromDate?: string;
}
