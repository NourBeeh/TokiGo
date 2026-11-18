import {
  IsInt,
  IsOptional,
  IsString,
  IsUrl,
  Matches,
  Max,
  Min,
} from 'class-validator';
import { Type } from 'class-transformer';

/** Optimize one provider image into a CDN-backed WebP object. */
export class OptimizeImageDto {
  /** Provider image URL. Fetched server-side only, never stored permanently. */
  @IsUrl({ require_protocol: true, protocols: ['https'] })
  sourceUrl!: string;

  @IsOptional()
  @IsString()
  @Matches(/^[0-9a-fA-F-]{36}$/, { message: 'hotelId must be a UUID' })
  hotelId?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(80)
  @Max(1600)
  width?: number;
}
