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
  Validate,
  ValidateNested,
  ValidationArguments,
  ValidatorConstraint,
  ValidatorConstraintInterface,
} from 'class-validator';
import { Type } from 'class-transformer';
import { TRAVEL_MOODS } from '../travel_mood';

export class HotelOccupancyDto {
  @IsInt()
  @Min(1)
  @Max(20)
  adults!: number;

  @IsOptional()
  @IsArray()
  @IsInt({ each: true })
  @Min(0, { each: true })
  @Max(17, { each: true })
  children?: number[];
}

/**
 * Cross-field contract for a hotel search.
 *
 * The provider needs ONE occupancy per room with exact child ages. A request
 * whose rooms/occupancies/guests disagree can only be fulfilled by guessing
 * (duplicating guests, collapsing rooms or inventing ages), so it is rejected
 * before any provider call.
 */
@ValidatorConstraint({ name: 'hotelSearchConsistent', async: false })
class HotelSearchConsistentConstraint implements ValidatorConstraintInterface {
  validate(_value: unknown, args: ValidationArguments): boolean {
    const dto = args.object as HotelSearchDto;
    const checkIn = new Date(dto.checkIn as unknown as string);
    const checkOut = new Date(dto.checkOut as unknown as string);
    if (Number.isNaN(checkIn.getTime()) || Number.isNaN(checkOut.getTime())) {
      return false;
    }
    if (checkOut.getTime() <= checkIn.getTime()) return false;

    const occupancies =
      Array.isArray(dto.occupancies) && dto.occupancies.length > 0
        ? dto.occupancies
        : null;

    if (!occupancies) {
      // Without per-room occupancies the provider can only express one room;
      // a multi-room request has no honest mapping.
      return dto.rooms == null || dto.rooms === 1;
    }

    if (dto.rooms != null && dto.rooms !== occupancies.length) return false;

    let guests = 0;
    for (const occupancy of occupancies) {
      if (!occupancy) return false;
      if (
        !Number.isInteger(occupancy.adults) ||
        occupancy.adults < 1 ||
        occupancy.adults > 20
      ) {
        return false;
      }
      const children = Array.isArray(occupancy.children)
        ? occupancy.children
        : [];
      for (const age of children) {
        if (!Number.isInteger(age) || age < 0 || age > 17) return false;
      }
      guests += occupancy.adults + children.length;
    }
    if (dto.guests != null && dto.guests !== guests) return false;
    return guests > 0 && guests <= 100;
  }

  defaultMessage(): string {
    return 'Hotel search dates, rooms and occupancies must be consistent: check-out after check-in, one occupancy per room, exact child ages 0-17, and guests equal to the occupancy total.';
  }
}

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
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => HotelOccupancyDto)
  occupancies?: HotelOccupancyDto[] | null;

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

  /**
   * Guest residency/nationality (ISO-3166-1 alpha-2). The provider requires
   * it for pricing; it defaults to EG and is part of the cache identity.
   */
  @IsOptional()
  @IsString()
  @Matches(/^[A-Za-z]{2}$/)
  nationality?: string | null;

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

  /** Informational traveller context; providers do not receive this field. */
  @IsOptional()
  @IsIn([...TRAVEL_MOODS])
  mood?: string;

  /** Nuitee hotel content locale. Omitted preserves the provider default. */
  @IsOptional()
  @IsIn(['en', 'ar'])
  language?: string;

  /**
   * Internal cross-field validation anchor. It carries no request data; it
   * exists so the whole-object constraint runs under the global
   * `whitelist + forbidNonWhitelisted` ValidationPipe.
   */
  @Validate(HotelSearchConsistentConstraint)
  readonly _consistency?: unknown;
}
