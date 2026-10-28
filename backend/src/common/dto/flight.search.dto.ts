import {
  IsString,
  IsDateString,
  IsOptional,
  IsInt,
  Min,
  IsArray,
  IsIn,
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

  /** Informational traveller context; providers do not receive this field. */
  @IsOptional()
  @IsIn([...TRAVEL_MOODS])
  mood?: string;
}
