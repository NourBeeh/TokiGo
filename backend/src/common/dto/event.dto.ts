import { IsIn, IsObject, IsOptional, IsString, MaxLength } from 'class-validator';

/** All event types the recommendation engine understands (R-3/R-4). */
export const EVENT_TYPES = [
  'hotel_search',
  'hotel_view',
  'hotel_favorite',
  'trip_planned',
  'booking_confirmed',
] as const;

export class TrackEventDto {
  @IsIn(EVENT_TYPES as unknown as string[])
  type!: string;

  /** Optional stable client id used for anonymous (guest) profiles. */
  @IsOptional()
  @IsString()
  @MaxLength(80)
  deviceId?: string;

  @IsObject()
  payload!: Record<string, any>;
}
