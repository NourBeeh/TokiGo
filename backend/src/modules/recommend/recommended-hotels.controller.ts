import { Controller, Get, Query, Req } from '@nestjs/common';
import { Request } from 'express';
import { RecommendedHotelsQueryDto } from '../../common/dto/recommend.dto';
import { RecommendedHotelService } from './recommended-hotel.service';

/**
 * Personalised/recommendation endpoint (R-4). Reads the caller identity from
 * the (optional) JWT to enrich the profile and country; falls back to default
 * recommendations for guests. All hotels come from the current provider only.
 */
@Controller('home/recommended')
export class RecommendedHotelsController {
  constructor(private readonly engine: RecommendedHotelService) {}

  @Get()
  async recommend(@Req() req: Request, @Query() query: RecommendedHotelsQueryDto) {
    const userId = (req.user as { id?: string } | undefined)?.id;
    const result = await this.engine.recommend({
      userId,
      limit: query.limit,
      // Explicit caller country wins over the profile fallback. Dropping this
      // silently was why every Home stayed on the launch market.
      countryCode: query.code,
    });
    return {
      ...result,
      hotels: result.hotels.map((h) => ({
        ...h,
        // Wire name compatibility: the Flutter HomeItem expects `title` and
        // presentation fields; the Nuitee id stays the canonical key.
        type: 'hotel',
      })),
    };
  }
}
