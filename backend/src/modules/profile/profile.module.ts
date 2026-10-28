import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { UserProfile } from '../../database/entities/user_profile.entity';
import { ProfileService } from './profile.service';
import { ProfileController } from './profile.controller';
import { MemoryModule } from '../memory/memory.module';

@Module({
  imports: [TypeOrmModule.forFeature([UserProfile]), MemoryModule],
  controllers: [ProfileController],
  providers: [ProfileService],
  exports: [ProfileService],
})
export class ProfileModule {}
