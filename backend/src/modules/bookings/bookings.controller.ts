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
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { BookingExceptionFilter } from './booking-exception.filter';
import { BookingsService } from './bookings.service';
import {
  CreateBookingDto,
  PrepareBookingDto,
  PriceChangeDecisionDto,
  ReconcileBookingDto,
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

  /**
   * Explicit customer decision on a price/terms change. Acceptance is bound
   * server-side to provider + offer + price + currency + terms version.
   */
  @Post(':id/price-change')
  async priceChange(
    @Req() req: Request,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: PriceChangeDecisionDto,
  ) {
    return this.bookings.decidePriceChange(userId(req), id, dto);
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

  /**
   * Admin-only explicit resolution of an unknown provider outcome.
   *
   * There is no automatic provider lookup: an operator records the evidence
   * (`confirmed` with a provider reference, or `not_found`). The customer
   * routes can never reach it, and it never creates a second provider booking
   * itself.
   */
  @Post(':id/reconcile')
  @UseGuards(RolesGuard)
  @Roles('admin')
  async reconcile(
    @Req() req: Request,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ReconcileBookingDto,
  ) {
    return this.bookings.reconcile(userId(req), id, dto);
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
