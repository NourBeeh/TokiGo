import {
  Body,
  Controller,
  Get,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { Request } from 'express';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import {
  HotelDiscoveryDto,
  HotelSyncDto,
} from '../../common/dto/hotel-discovery.dto';
import { clampLimit, clampOffset } from '../../common/dto/pagination.dto';
import { HotelDiscoveryService } from './hotel-discovery.service';
import { HotelSyncService } from './hotel-sync.service';

/**
 * Hotel discovery API (high-load refactor).
 *
 * `GET /hotels` searches METADATA ONLY (Meilisearch first, PostgreSQL
 * fallback). It never returns prices or availability; the client prices a
 * hotel through `POST /search/hotels`, which always consults the live
 * provider. `POST /hotels/sync` refreshes metadata in the background.
 */
@Controller('hotels')
export class HotelsController {
  constructor(
    private readonly discovery: HotelDiscoveryService,
    private readonly sync: HotelSyncService,
  ) {}

  @Get()
  async discover(@Query() dto: HotelDiscoveryDto) {
    return this.discovery.discover({
      query: dto.query?.trim() || undefined,
      city: dto.city?.trim() || undefined,
      countryCode: dto.countryCode?.toUpperCase(),
      facilities: dto.facilityList(),
      limit: clampLimit(dto.limit),
      offset: clampOffset(dto.offset),
    });
  }

  /** Authenticated because it triggers real provider calls. */
  @Post('sync')
  @UseGuards(JwtAuthGuard)
  async syncCity(@Req() req: Request, @Body() dto: HotelSyncDto) {
    const result = await this.sync.requestCitySync({
      city: dto.city,
      country: dto.country,
      language: dto.language,
    });
    return { requestedBy: (req.user as { id?: string })?.id ?? null, ...result };
  }
}
