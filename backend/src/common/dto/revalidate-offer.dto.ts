import { IsString, IsOptional, IsIn, IsInt, Min } from 'class-validator';

/**
 * Offer revalidation request (spec points 7-8): the selected offer must be
 * re-checked for price/availability immediately before payment. Response
 * carries a structured PRICE_CHANGED result instead of a silent new price.
 */
export class RevalidateOfferDto {
  @IsString()
  offerId!: string;

  @IsString()
  providerId!: string;

  @IsIn(['flight', 'hotel', 'car', 'package'])
  offerType!: string;

  @IsOptional()
  @IsString()
  knownPrice?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  guests?: number;
}
