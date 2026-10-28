import { Body, Controller, Post, UseGuards } from '@nestjs/common';
import { DuffelService } from './duffel.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import {
  DuffelCreateBookingDto,
  DuffelFlightSearchDto,
} from '../../common/dto/duffel.dto';

/**
 * Raw Duffel endpoints.
 *
 * `search-flights` is public: it only reads prices and carries no user data.
 * `create-booking` moves money at the airline, so it is JWT-guarded exactly
 * like `/bookings` — it used to accept an unauthenticated `any[]` body and
 * forward it straight to the provider.
 *
 * The app itself books through `/bookings`; these routes exist for provider
 * parity and diagnostics.
 */
@Controller('api/duffel')
export class DuffelController {
  constructor(private readonly duffelService: DuffelService) {}

  @Post('search-flights')
  @UseGuards(JwtAuthGuard)
  async searchFlights(@Body() body: DuffelFlightSearchDto) {
    return this.duffelService.searchFlights({
      origin: body.origin,
      destination: body.destination,
      departure: new Date(body.departureDate),
      passengers: body.passengers,
    });
  }

  @Post('create-booking')
  @UseGuards(JwtAuthGuard)
  async createBooking(@Body() body: DuffelCreateBookingDto) {
    return this.duffelService.createOrder(
      body.offerId,
      body.passengers,
      body.payments,
    );
  }
}
