import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { UserEvent } from '../../database/entities/user_event.entity';
import { ProfileModule } from '../profile/profile.module';
import { MemoryModule } from '../memory/memory.module';
import { EventsService } from './events.service';
import { EventsController } from './events.controller';

@Module({
  imports: [TypeOrmModule.forFeature([UserEvent]), ProfileModule, MemoryModule],
  controllers: [EventsController],
  providers: [EventsService],
  exports: [EventsService],
})
export class EventsModule {}
