import {
  IsString,
  IsDateString,
  IsOptional,
  IsInt,
  Min,
  IsArray,
  IsIn,
  IsBoolean,
  Matches,
  ValidateNested,
  ArrayMinSize,
  ArrayMaxSize,
} from 'class-validator';
import { Type } from 'class-transformer';
import { TRAVEL_MOODS } from '../travel_mood';

/**
 * One leg of a multi-city itinerary: where it leaves from, where it lands and
 * when. The provider turns each leg into one slice of the offer request.
 */
export class FlightLegDto {
  @IsString()
  origin!: string;

  @IsString()
  destination!: string;

  @IsDateString()
  date!: Date;
}

export class FlightSearchDto {
  @IsString()
  origin!: string;

  @IsString()
  destination!: string;

  @IsDateString()
  departure!: Date;

  @IsOptional()
  @IsDateString()
  returnDate?: Date;

  @IsOptional()
  @IsInt()
  @Min(1)
  passengers?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  children?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  infants?: number;

  @IsOptional()
  @IsArray()
  @IsInt({ each: true })
  childAges?: number[];

  @IsOptional()
  @IsArray()
  @IsInt({ each: true })
  infantAges?: number[];

  /**
   * A multi-city itinerary (owner decision, 2026-10-20). When present it
   * REPLACES the single origin/destination/departure triple: one leg per
   * slice, in order. The legacy fields stay for one-way and round-trip.
   */
  @IsOptional()
  @IsArray()
  @ArrayMinSize(2)
  @ArrayMaxSize(6)
  @ValidateNested({ each: true })
  @Type(() => FlightLegDto)
  legs?: FlightLegDto[];

  /** MarketContext selector (ISO-3166-1 alpha-2). Display currency/locale. */
  @IsOptional()
  @IsString()
  market?: string;

  /**
   * Explicit display currency (ISO-4217) chosen by the traveller. When absent
   * the market's own currency applies.
   */
  @IsOptional()
  @IsString()
  @Matches(/^[A-Za-z]{3}$/, { message: 'currency must be an ISO-4217 code' })
  currency?: string;

  /**
   * Cabin class for the flight search (owner decision, 2026-11): the travel
   * class the traveller picks in the Flights form. Duffel honours it verbatim
   * (economy / premium_economy / business / first); providers without cabin
   * support simply ignore it, and the traveller's intent is never silently
   * narrowed.
   */
  @IsOptional()
  @IsString()
  @IsIn(['economy', 'premium_economy', 'business', 'first'], {
    message: 'cabinClass must be one of economy, premium_economy, business, first',
  })
  cabinClass?: string;

  /**
   * Non-stop flights only (owner decision, 2026-11). Duffel honours it via
   * `max_connections: 0`; cabin-only providers simply ignore it and the
   * client applies the same filter on the returned offers.
   */
  @IsOptional()
  @IsBoolean()
  directOnly?: boolean;

  /** Informational traveller context; providers do not receive this field. */
  @IsOptional()
  @IsIn([...TRAVEL_MOODS])
  mood?: string;
}
