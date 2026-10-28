import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { HomeSection } from '../../database/entities/home_section.entity';
import { HomeCard } from '../../database/entities/home_card.entity';
import { NuiteeModule } from '../nuitee/nuitee.module';
import { CacheModule } from '../cache/cache.module';
import { DuffelModule } from '../duffel/duffel.module';
import { HomeController } from './home.controller';
import { HomeService } from './home.service';
import { HomeFlightsService } from './home.flights.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([HomeSection, HomeCard]),
    // Real hotel source (Nuitee) + real flight source (Duffel) + the
    // short-TTL snapshot cache.
    NuiteeModule,
    DuffelModule,
    CacheModule,
  ],
  controllers: [HomeController],
  providers: [HomeService, HomeFlightsService],
})
export class HomeModule {}
