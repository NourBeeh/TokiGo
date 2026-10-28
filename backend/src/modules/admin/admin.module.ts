import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuditLog } from '../../database/entities/audit_log.entity';
import { HomeCard } from '../../database/entities/home_card.entity';
import { HomeSection } from '../../database/entities/home_section.entity';
import { Provider } from '../../database/entities/provider.entity';
import { ProvidersModule } from '../providers/providers.module';
import { AdminController } from './admin.controller';
import { AdminProvidersController } from './admin-providers.controller';
import { AdminService } from './admin.service';

/**
 * Admin workstream:
 * - ADM-A1: Home content management endpoints (/admin/home/*).
 * - ADM-B1: provider switching endpoints (/admin/providers/*) backed by the
 *   persisted `providers` table via ProvidersModule's RegistrySyncService.
 */
@Module({
  imports: [
    TypeOrmModule.forFeature([HomeSection, HomeCard, AuditLog, Provider]),
    ProvidersModule,
  ],
  controllers: [AdminController, AdminProvidersController],
  providers: [AdminService],
})
export class AdminModule {}
