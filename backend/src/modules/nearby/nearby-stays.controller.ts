import { Controller, Get, Query } from '@nestjs/common';
import { NearbyStaysService } from './nearby-stays.service';
import { NearbyStaysQueryDto } from '../../common/dto/nearby-stays.dto';

/**
 * GET /home/nearby-stays — promotional hotel discovery around a real place.
 *
 * Read-only and public, like the rest of Home. It never returns a bookable
 * offer: the response is a PromotionalStay list plus the actual search radius
 * and location confidence, and the client must run a fresh live search before
 * any booking.
 */
@Controller('home/nearby-stays')
export class NearbyStaysController {
  constructor(private readonly service: NearbyStaysService) {}

  @Get()
  async nearbyStays(@Query() dto: NearbyStaysQueryDto) {
    return this.service.getNearbyStays({
      latitude: dto.lat,
      longitude: dto.lng,
      accuracy: dto.accuracy,
      city: dto.city,
      cityId: dto.cityId,
      country: dto.country,
      language: dto.language,
      currency: dto.currency,
      nationality: dto.nationality,
      adults: dto.adults,
      rooms: dto.rooms,
      limit: dto.limit,
      timezone: dto.timezone,
      fromDate: dto.fromDate,
    });
  }
}
