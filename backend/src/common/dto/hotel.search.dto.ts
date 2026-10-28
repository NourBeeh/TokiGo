import {
  IsArray,
  IsDateString,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  IsIn,
  Matches,
  Max,
  Min,
  MinLength,
} from 'class-validator';
import { TRAVEL_MOODS } from '../travel_mood';

export class HotelSearchDto {
  @IsString()
  city!: string;

  @IsDateString()
  checkIn!: Date;

  @IsDateString()
  checkOut!: Date;

  @IsOptional()
  @IsInt()
  @Min(1)
  guests?: number;

  /**
   * Phase 3A (Flutter) sends the rich hotel search fields; Phase 3B adds
   * them to this DTO so the whitelist pipe accepts the contract the client
   * already implements. Explicit null = unset (the client sends null for
   * omitted fields; class-validator treats null as absent for @IsOptional
   * in non-strict mode — verified by the 3B contract spec).
   */
  @IsOptional()
  @IsInt()
  @Min(1)
  rooms?: number | null;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(5)
  minRating?: number | null;

  @IsOptional()
  @IsNumber()
  @Min(0)
  maxPrice?: number | null;

  @IsOptional()
  @IsNumber()
  @Min(0)
  minPrice?: number | null;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  @MinLength(1, { each: true })
  amenities?: string[] | null;

  /**
   * Optional ISO-3166-1 alpha-2 country of the searched city. The provider
   * rates endpoint requires a country alongside the city name; without it a
   * city such as Gudauri would be queried under the fallback country and
   * return an empty (but false) answer. Discover cards send their own country.
   */
  @IsOptional()
  @IsString()
  @Matches(/^[A-Za-z]{2}$/)
  country?: string | null;

  /** MarketContext selector (ISO-3166-1 alpha-2). Display currency/locale. */
  @IsOptional()
  @IsString()
  market?: string;

  /** Informational traveller context; providers do not receive this field. */
  @IsOptional()
  @IsIn([...TRAVEL_MOODS])
  mood?: string;
}
