import { Controller, Get, Post, Query } from '@nestjs/common';
import { HomeService } from './home.service';
import { HomeFlightsService } from './home.flights.service';

@Controller('home')
export class HomeController {
  constructor(
    private readonly homeService: HomeService,
    private readonly flights: HomeFlightsService,
  ) {}

  @Get('sections')
  async getSections() {
    return this.homeService.getSections();
  }

  /**
   * NOTE: `GET /home/recommended` is NOT served here. The single owner is
   * `RecommendedHotelsController` (modules/recommend), which is country-aware,
   * scores deterministically and caches the snapshot. This controller used to
   * register the same path, and because HomeModule is imported before
   * RecommendModule, Express silently routed every Home call to the fixed
   * Cairo list and the recommendation engine was unreachable.
   */

  /**
   * Phase 2 — the real Duffel-backed flight rail for the selected travel mood.
   * `country` is the traveller's country (origin airport is a suggestion),
   * `mood` is one of the authored travel moods and `limit` is clamped to three
   * live searches. Provider failures produce an honest shorter list.
   */
  @Get('flights-for-mood')
  async getFlightsForMood(
    @Query('country') country?: string,
    @Query('mood') mood?: string,
    @Query('limit') limit?: string,
  ) {
    const parsed = limit !== undefined ? parseInt(limit, 10) : undefined;
    return this.flights.getFlightsForMood({
      country,
      mood,
      limit: Number.isFinite(parsed) ? (parsed as number) : undefined,
    });
  }

  @Post('refresh')
  async refresh() {
    return this.homeService.refresh();
  }
}
