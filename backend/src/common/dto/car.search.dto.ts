import { IsString, IsDateString, IsOptional, Matches } from 'class-validator';

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

  /** Explicit display currency (ISO-4217); the market currency applies when absent. */
  @IsOptional()
  @IsString()
  @Matches(/^[A-Za-z]{3}$/, { message: 'currency must be an ISO-4217 code' })
  currency?: string;
}
