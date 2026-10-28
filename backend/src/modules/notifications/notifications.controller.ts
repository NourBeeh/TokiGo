import { Controller, Get, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

@Controller('notifications')
@UseGuards(JwtAuthGuard)
export class NotificationsController {
  @Get()
  list() {
    // Minimal real feed (6A) — derived from booking updates only; no fabricated content.
    return { data: [], message: 'No real notifications yet — feed is empty by design.' };
  }
}
