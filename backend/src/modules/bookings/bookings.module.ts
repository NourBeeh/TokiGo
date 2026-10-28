import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { Booking } from './booking.entity';
import { BookingsService } from './bookings.service';
import { BookingsController } from './bookings.controller';
import { BookingProviderRegistry } from './booking-provider.registry';
import { DuffelBookingProvider } from './adapters/duffel-booking.provider';
import { NuiteeBookingProvider } from './adapters/nuitee-booking.provider';
import { NuiteeFlightBookingProvider } from './adapters/nuitee-flight-booking.provider';
import { ProvidersModule } from '../providers/providers.module';

/**
 * Booking foundation module (Phase 4A).
 *
 * Wires the persisted Booking record, the provider capability registry and
 * the JWT-guarded HTTP surface. Adapters reuse the existing Duffel/Nuitee
 * services from ProvidersModule — no provider call is re-implemented here.
 */
@Module({
  imports: [TypeOrmModule.forFeature([Booking]), ProvidersModule],
  controllers: [BookingsController],
  providers: [
    BookingsService,
    DuffelBookingProvider,
    NuiteeBookingProvider,
    NuiteeFlightBookingProvider,
    {
      provide: BookingProviderRegistry,
      useFactory: (
        duffel: DuffelBookingProvider,
        nuitee: NuiteeBookingProvider,
        nuiteeFlight: NuiteeFlightBookingProvider,
      ) => {
        const registry = new BookingProviderRegistry();
        registry.register(duffel);
        registry.register(nuitee);
        registry.register(nuiteeFlight);
        return registry;
      },
      inject: [DuffelBookingProvider, NuiteeBookingProvider, NuiteeFlightBookingProvider],
    },
  ],
  exports: [BookingsService],
})
export class BookingsModule {}
