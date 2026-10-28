import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { Request } from 'express';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import {
  CreateCardDto,
  CreateSectionDto,
  ReorderDto,
  UpdateCardDto,
  UpdateSectionDto,
} from '../../common/dto/admin.dto';
import { AdminService } from './admin.service';

/**
 * Admin-only Home content management. Every route requires a valid JWT whose
 * user carries `role === 'admin'` (JwtAuthGuard then RolesGuard).
 */
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('admin')
@Controller('admin')
export class AdminController {
  constructor(private readonly admin: AdminService) {}

  // ---------- Home sections ----------

  @Get('home/sections')
  listSections() {
    return this.admin.listSections();
  }

  @Post('home/sections')
  createSection(@Body() dto: CreateSectionDto, @Req() req: Request) {
    return this.admin.createSection(dto, adminUserId(req));
  }

  @Patch('home/sections/:id')
  updateSection(
    @Param('id') id: string,
    @Body() dto: UpdateSectionDto,
    @Req() req: Request,
  ) {
    return this.admin.updateSection(id, dto, adminUserId(req));
  }

  @Delete('home/sections/:id')
  async deleteSection(@Param('id') id: string, @Req() req: Request) {
    await this.admin.deleteSection(id, adminUserId(req));
    return { deleted: true };
  }

  @Post('home/sections/reorder')
  async reorderSections(@Body() dto: ReorderDto, @Req() req: Request) {
    await this.admin.reorderSections(dto, adminUserId(req));
    return { reordered: true };
  }

  // ---------- Home cards ----------

  @Post('home/cards')
  createCard(@Body() dto: CreateCardDto, @Req() req: Request) {
    return this.admin.createCard(dto, adminUserId(req));
  }

  @Patch('home/cards/:id')
  updateCard(
    @Param('id') id: string,
    @Body() dto: UpdateCardDto,
    @Req() req: Request,
  ) {
    return this.admin.updateCard(id, dto, adminUserId(req));
  }

  @Delete('home/cards/:id')
  async deleteCard(@Param('id') id: string, @Req() req: Request) {
    await this.admin.deleteCard(id, adminUserId(req));
    return { deleted: true };
  }

  @Post('home/cards/reorder')
  async reorderCards(@Body() dto: ReorderDto, @Req() req: Request) {
    await this.admin.reorderCards(dto, adminUserId(req));
    return { reordered: true };
  }

  // ---------- Audit ----------

  @Get('audit-logs')
  auditLogs(@Query('limit') limit?: string) {
    return this.admin.listAuditLogs(limit ? Number(limit) : 50);
  }
}

/** Passport's Express.User is an empty interface; the JWT strategy always
 * attaches the full user entity, so the id is safely readable here. */
function adminUserId(req: Request): string | undefined {
  const user = req.user as { id?: string } | undefined;
  return user?.id;
}
