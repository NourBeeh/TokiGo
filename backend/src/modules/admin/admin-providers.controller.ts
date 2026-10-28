import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { Request } from 'express';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import {
  UpdateProviderConfigDto,
  UpdateProviderPriorityDto,
  UpdateProviderStatusDto,
} from '../../common/dto/admin.dto';
import { AdminService } from './admin.service';

/**
 * Admin provider management (ADM-B1): switch active providers per vertical,
 * reorder priorities, edit config and probe health — all at runtime, no
 * backend restart required.
 */
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('admin')
@Controller('admin/providers')
export class AdminProvidersController {
  constructor(private readonly admin: AdminService) {}

  @Get()
  listProviders() {
    return this.admin.listProviders();
  }

  @Patch(':key/status')
  setStatus(
    @Param('key') key: string,
    @Body() dto: UpdateProviderStatusDto,
    @Req() req: Request,
  ) {
    return this.admin.setProviderStatus(key, dto.isActive, adminUserId(req));
  }

  @Patch(':key/priority')
  setPriority(
    @Param('key') key: string,
    @Body() dto: UpdateProviderPriorityDto,
    @Req() req: Request,
  ) {
    return this.admin.setProviderPriority(key, dto.priority, adminUserId(req));
  }

  @Patch(':key/config')
  setConfig(
    @Param('key') key: string,
    @Body() dto: UpdateProviderConfigDto,
    @Req() req: Request,
  ) {
    return this.admin.setProviderConfig(key, dto.config, adminUserId(req));
  }

  @Post(':key/health-check')
  healthCheck(@Param('key') key: string, @Req() req: Request) {
    return this.admin.runHealthCheck(key, adminUserId(req));
  }

  @Post('refresh-registry')
  refreshRegistry(@Req() req: Request) {
    return this.admin.refreshRegistry(adminUserId(req));
  }
}

/** Passport's Express.User is an empty interface; the JWT strategy always
 * attaches the full user entity, so the id is safely readable here. */
function adminUserId(req: Request): string | undefined {
  const user = req.user as { id?: string } | undefined;
  return user?.id;
}
