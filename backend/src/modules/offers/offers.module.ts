import { Module } from '@nestjs/common';
import { OffersController } from './offers.controller';
import { ProvidersModule } from '../providers/providers.module';

@Module({
  imports: [ProvidersModule],
  controllers: [OffersController],
})
export class OffersModule {}
