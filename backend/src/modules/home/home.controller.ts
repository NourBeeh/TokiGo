import { Controller, Get } from '@nestjs/common';
import { HomeService } from './home.service';

/**
 * The generic Home feed's remaining owner: the destination sections used by
 * the Explore Cities page. The old `/home/recommended` rail, the mood flight
 * rail and `/home/refresh` were removed with the legacy Home system.
 */
@Controller('home')
export class HomeController {
  constructor(private readonly homeService: HomeService) {}

  @Get('sections')
  async getSections() {
    return this.homeService.getSections();
  }
}
