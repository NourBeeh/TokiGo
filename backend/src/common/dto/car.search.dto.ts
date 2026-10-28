import { IsString, IsDateString, IsOptional } from 'class-validator';

export class CarSearchDto {
  @IsString()
  pickupLocation!: string;

  @IsDateString()
  pickupTime!: Date;

  @IsDateString()
  dropoffTime!: Date;

  /** MarketContext selector (ISO-3166-1 alpha-2). Display currency/locale. */
  @IsOptional()
  @IsString()
  market?: string;
}
