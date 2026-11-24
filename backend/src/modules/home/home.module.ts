import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { HomeSection } from '../../database/entities/home_section.entity';
import { HomeCard } from '../../database/entities/home_card.entity';
import { HomeController } from './home.controller';
import { HomeService } from './home.service';

@Module({
  imports: [TypeOrmModule.forFeature([HomeSection, HomeCard])],
  controllers: [HomeController],
  providers: [HomeService],
})
export class HomeModule {}
