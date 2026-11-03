import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { RecommendedHotelService } from './recommended-hotel.service';
import { RecommendedHotelsController } from './recommended-hotels.controller';
import { RecommendWarmupService } from './recommend.warmup';
import { NuiteeModule } from '../nuitee/nuitee.module';
import { ProfileModule } from '../profile/profile.module';
import { AiModule } from '../ai/ai.module';
import { ProvidersModule } from '../providers/providers.module';
import { UserProfile } from '../../database/entities/user_profile.entity';

@Module({
  imports: [
    NuiteeModule,
    ProfileModule,
    AiModule,
    // PricingService (display-currency conversion) is exported by ProvidersModule.
    ProvidersModule,
    TypeOrmModule.forFeature([UserProfile]),
  ],
  controllers: [RecommendedHotelsController],
  providers: [RecommendedHotelService, RecommendWarmupService],
  exports: [RecommendedHotelService],
})
export class RecommendModule {}
