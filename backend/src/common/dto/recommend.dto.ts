import { IsInt, IsOptional, IsString, Matches, Max, Min } from 'class-validator';
import { Transform } from 'class-transformer';

export class RecommendedHotelsQueryDto {
  /** Number of cards to return (5-10, default 6). */
  @IsOptional()
  @Transform(({ value }) => parseInt(value, 10))
  @IsInt()
  @Min(1)
  @Max(12)
  limit?: number;

  /**
   * Country code (ISO-2). The engine enriches from the profile/geo when absent.
   * Normalised to upper-case before validation so `eg` and ` EG ` are the same
   * market instead of two different cache identities.
   */
  @IsOptional()
  @Transform(({ value }) =>
    typeof value === 'string' ? value.trim().toUpperCase() : value,
  )
  @IsString()
  @Matches(/^[A-Z]{2}$/, { message: 'code must be an ISO-2 country code' })
  code?: string;
}
