import { Module } from '@nestjs/common';
import { DuffelService } from './duffel.service';
import { DuffelController } from './duffel.controller';

@Module({
  providers: [DuffelService],
  controllers: [DuffelController],
  exports: [DuffelService],
})
export class DuffelModule {}