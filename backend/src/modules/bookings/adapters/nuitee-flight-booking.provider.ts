import { Injectable } from '@nestjs/common';
import {
  BookingProvider,
  BookingRevalidation,
  CancelBookingInput,
  CreatedBooking,
  CreateBookingInput,
} from '../../../common/providers/booking-provider.interface';
import { ProviderResult } from '../../../common/providers/provider.result';
import { NuiteeFlightService } from '../../nuitee/nuitee.flight.service';

/**
 * Booking adapter for Nuitee flight provider (Phase 4B — simplified sandbox).
 * Uses sandbox simulated payment (ACC_CREDIT_CARD) and simplified passenger data.
 */
@Injectable()
export class NuiteeFlightBookingProvider implements BookingProvider {
  constructor(private readonly flightService: NuiteeFlightService) {}

  readonly providerId = 'nuitee-flight';

  get providerName(): string {
    return 'Nuitee Flights';
  }

  readonly bookingCapability = {
    book: true,
    cancel: false,
    revalidate: true,
  } as const;

  async revalidateBooking(offerId: string): Promise<ProviderResult<BookingRevalidation>> {
    const prebook = await this.flightService.prebookFlight({
      offerId,
      contact: {
        firstName: 'Test',
        lastName: 'Guest',
        email: 'test@tokigo.app',
        phoneCountryCode: '+20',
        phoneNumber: '1234567890',
      },
      passengers: [
        {
          passengerType: 'ADT',
          firstName: 'Test',
          lastName: 'Guest',
        },
      ],
      usePaymentSdk: false,
    });
    if (!prebook.success) {
      return {
        success: false,
        providerId: this.providerId,
        providerName: this.providerName,
        error: prebook.error ?? 'Nuitee flight prebook failed',
        timestamp: new Date(),
      };
    }
    return {
      success: true,
      providerId: this.providerId,
      providerName: this.providerName,
      data: {
        price: 0,
        currency: 'USD',
        available: true,
        expiresAt: new Date(Date.now() + 30 * 60 * 1000).toISOString(),
        priceChanged: false,
        oldPrice: 0,
        handoff: {
          prebookId: String(prebook.prebookId),
          transactionId: String(prebook.transactionId),
          offerId,
        },
      },
      timestamp: new Date(),
    };
  }

  async createBooking(input: CreateBookingInput): Promise<ProviderResult<CreatedBooking>> {
    const snapshot = (input.offerSnapshot ?? {}) as any;
    const prebookId = snapshot.prebookId;
    if (!prebookId) {
      return {
        success: false,
        providerId: this.providerId,
        providerName: this.providerName,
        error: 'Missing Nuitee flight prebookId in snapshot',
        timestamp: new Date(),
      };
    }

    const bookResult = await this.flightService.bookFlight({
      prebookId: String(prebookId),
      payment: { method: 'ACC_CREDIT_CARD' },
    });

    if (!bookResult.success) {
      return {
        success: false,
        providerId: this.providerId,
        providerName: this.providerName,
        error: bookResult.error ?? 'Nuitee flight booking failed',
        timestamp: new Date(),
      };
    }

    return {
      success: true,
      providerId: this.providerId,
      providerName: this.providerName,
      data: {
        reference: bookResult.bookingRef ?? bookResult.bookingId ?? String(prebookId),
        providerBookingId: bookResult.bookingId,
        status: bookResult.status ?? 'CREATED',
        amount: 0,
        currency: 'USD',
        raw: bookResult,
      },
      timestamp: new Date(),
    };
  }

  async cancelBooking(
    _input: CancelBookingInput,
  ): Promise<ProviderResult<{ cancelled: boolean }>> {
    return {
      success: false,
      providerId: this.providerId,
      providerName: this.providerName,
      error: 'Nuitee flight cancellation not supported',
      timestamp: new Date(),
    };
  }
}
