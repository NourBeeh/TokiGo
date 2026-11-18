import { IsISO8601, IsInt, IsOptional, IsString, Matches, Min } from 'class-validator';
import { Type } from 'class-transformer';
import {
  DEFAULT_PAGE_LIMIT,
  MAX_PAGE_LIMIT,
  PaginationDto,
} from './pagination.dto';

/** Hotel metadata discovery query (never prices). */
export class HotelDiscoveryDto extends PaginationDto {
  @IsOptional()
  @IsString()
  @Matches(/^[^\x00-\x1f]{0,200}$/, { message: 'query contains control characters' })
  query?: string;

  @IsOptional()
  @IsString()
  @Matches(/^[^\x00-\x1f]{0,120}$/, { message: 'city contains control characters' })
  city?: string;

  @IsOptional()
  @IsString()
  @Matches(/^[A-Za-z]{2}$/, { message: 'countryCode must be ISO-3166-1 alpha-2' })
  countryCode?: string;

  /** Comma-separated facility names. */
  @IsOptional()
  @IsString()
  facilities?: string;

  /** Convenience: parse the comma-separated facilities into a list. */
  facilityList(): string[] {
    return (this.facilities ?? '')
      .split(',')
      .map((f) => f.trim())
      .filter(Boolean)
      .slice(0, 20);
  }
}

/** Trigger a background metadata synchronization for one city. */
export class HotelSyncDto {
  @IsString()
  @Matches(/^[^\x00-\x1f]{1,120}$/, { message: 'city is required' })
  city!: string;

  @IsOptional()
  @IsString()
  @Matches(/^[A-Za-z]{2}$/, { message: 'country must be ISO-3166-1 alpha-2' })
  country?: string;

  @IsOptional()
  @IsString()
  @Matches(/^(en|ar)$/, { message: 'language must be en or ar' })
  language?: string;
}
