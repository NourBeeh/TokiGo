import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { Request } from 'express';

import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import {
  CreateMemoryDto,
  ListMemoryQueryDto,
  UpdateMemoryDto,
} from '../../common/dto/memory.dto';
import { MemoryService } from './memory.service';

/**
 * User Memory Spine API (Phase 2A — Foundation).
 *
 * SECURITY MODEL: every route derives the caller identity from the JWT via
 * [userId] below — the request can NEVER specify or observe another user's
 * id. There is deliberately no `GET /memory/:userId` route; the listing
 * surface is `/memory/me` only, and every mutation verifies ownership in the
 * service layer (defense in depth on top of the route shape).
 */
@UseGuards(JwtAuthGuard)
@Controller('memory')
export class MemoryController {
  constructor(private readonly memoryService: MemoryService) {}

  /** Lists the caller's memories (updatedAt DESC; expired hidden by default). */
  @Get('me')
  async listMine(@Req() req: Request, @Query() query: ListMemoryQueryDto) {
    return this.memoryService.listForUser(userId(req), {
      type: query.type,
      source: query.source,
      includeExpired: query.includeExpired,
    });
  }

  /** Records (or updates) one structured fact for the caller. */
  @Post()
  async create(@Req() req: Request, @Body() dto: CreateMemoryDto) {
    return this.memoryService.upsert(userId(req), dto);
  }

  /** Updates a memory owned by the caller (value/source/confidence/expiry). */
  @Patch(':id')
  async update(
    @Req() req: Request,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateMemoryDto,
  ) {
    return this.memoryService.updateOwn(userId(req), id, dto);
  }

  /** Deletes one memory owned by the caller. */
  @Delete(':id')
  async remove(@Req() req: Request, @Param('id', ParseUUIDPipe) id: string) {
    await this.memoryService.deleteOwn(userId(req), id);
    return { deleted: true };
  }

  /** Clears ALL memories owned by the caller ("Forget everything"). */
  @Delete('me')
  async clearMine(@Req() req: Request) {
    await this.memoryService.clearOwn(userId(req));
    return { cleared: true };
  }
}

/** Passport's Express.User is an empty interface; the JWT strategy attaches
 * the full user entity, so the id is safely readable here. */
function userId(req: Request): string {
  const user = req.user as { id?: string } | undefined;
  if (!user?.id) throw new Error('Authenticated request missing user id.');
  return user.id;
}
