import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Post,
  Req,
  UseFilters,
  UseGuards,
} from '@nestjs/common';
import { Request } from 'express';

import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { BookingExceptionFilter } from './booking-exception.filter';
import { BookingsService } from './bookings.service';
import {
  CreateBookingDto,
  PrepareBookingDto,
  RevalidateBookingDto,
} from '../../common/dto/booking.dto';

/**
 * Booking foundation API (Phase 4A).
 *
 * SECURITY MODEL: every route is JWT-guarded and derives the caller identity
 * from the token ([userId] below) — a request can never read or mutate another
 * user's booking. No route accepts a price or a userId from the body.
 *
 * Errors are normalised to `{code, message}` by [BookingExceptionFilter].
 */
@UseGuards(JwtAuthGuard)
@UseFilters(BookingExceptionFilter)
@Controller('bookings')
export class BookingsController {
  constructor(private readonly bookings: BookingsService) {}

  /** Prepare: capability-check + provider revalidation → authoritative price. */
  @Post('prepare')
  async prepare(@Req() req: Request, @Body() dto: PrepareBookingDto) {
    return this.bookings.prepare(userId(req), dto);
  }

  /** Revalidate a prepared booking against the live provider offer. */
  @Post('revalidate')
  async revalidate(@Req() req: Request, @Body() dto: RevalidateBookingDto) {
    return this.bookings.revalidate(userId(req), dto.bookingId);
  }

  /** Confirm (create) a booking — idempotent on the supplied key. */
  @Post()
  async create(@Req() req: Request, @Body() dto: CreateBookingDto) {
    return this.bookings.create(userId(req), dto);
  }

  @Get(':id')
  async get(
    @Req() req: Request,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.bookings.get(userId(req), id);
  }

  @Get(':id/status')
  async status(
    @Req() req: Request,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.bookings.getStatus(userId(req), id);
  }

  /** Capability-gated cancellation (unsupported providers → structured error). */
  @Post(':id/cancel')
  async cancel(
    @Req() req: Request,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.bookings.cancel(userId(req), id);
  }
}

/** Passport attaches the JWT-validated user entity to the request. */
function userId(req: Request): string {
  return (req.user as { id: string }).id;
}
