import {
  Body,
  Controller,
  HttpCode,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { Request } from 'express';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { TrackEventDto } from '../../common/dto/event.dto';
import { EventsService } from './events.service';

/**
 * Behavioural signal tracking (R-3). Auth is optional per call: registered
 * users are identified by their JWT; guests send a stable deviceId in the body.
 */
@Controller('events')
export class EventsController {
  constructor(private readonly events: EventsService) {}

  @Post()
  @HttpCode(204)
  @UseGuards(JwtAuthGuard)
  async track(@Req() req: Request, @Body() dto: TrackEventDto) {
    const user = req.user as { id?: string } | undefined;
    await this.events.track({
      userId: user?.id,
      deviceId: user?.id ? undefined : dto.deviceId,
      type: dto.type,
      payload: dto.payload,
    });
  }
}
