import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { RecommendedHotelService } from './recommended-hotel.service';
import { RecommendedHotelsController } from './recommended-hotels.controller';
import { NuiteeModule } from '../nuitee/nuitee.module';
import { ProfileModule } from '../profile/profile.module';
import { AiModule } from '../ai/ai.module';
import { UserProfile } from '../../database/entities/user_profile.entity';

@Module({
  imports: [
    NuiteeModule,
    ProfileModule,
    AiModule,
    TypeOrmModule.forFeature([UserProfile]),
  ],
  controllers: [RecommendedHotelsController],
  providers: [RecommendedHotelService],
  exports: [RecommendedHotelService],
})
export class RecommendModule {}
