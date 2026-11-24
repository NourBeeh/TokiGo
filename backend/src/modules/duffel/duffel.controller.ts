import { Body, Controller, Post, UseGuards } from '@nestjs/common';
import { DuffelService } from './duffel.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { DuffelFlightSearchDto } from '../../common/dto/duffel.dto';

/**
 * Raw Duffel endpoints.
 *
 * `search-flights` only reads prices and carries no user data.
 *
 * P0-S6: `POST /api/duffel/create-booking` was REMOVED. It accepted a
 * caller-supplied `payments[]` array and forwarded it verbatim to the airline,
 * bypassing `payment_attempts`, the ledger and every server-side amount check —
 * an authenticated user could move money outside the authoritative payment
 * lifecycle. Duffel is not enabled in this phase (no credentials), so the route
 * was dormant, but leaving a money-moving back door in the codebase was not
 * acceptable.
 *
 * Compatibility impact: this was a diagnostics/parity route only. The Flutter
 * app does not call it (no reference in `lib/`); all real bookings go through
 * the JWT-guarded `/bookings/*` flow, which is unchanged. `DuffelService.
 * createOrder` remains for a future, properly authorised integration.
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
      adults: body.adults,
      children: body.children,
      infants: body.infants,
      childAges: body.childAges,
      infantAges: body.infantAges,
    });
  }
}
