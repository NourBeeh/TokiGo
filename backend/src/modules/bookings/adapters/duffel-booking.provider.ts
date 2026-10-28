import { Injectable } from '@nestjs/common';
import {
  BookingProvider,
  BookingRevalidation,
  CancelBookingInput,
  CreatedBooking,
  CreateBookingInput,
} from '../../../common/providers/booking-provider.interface';
import { ProviderResult } from '../../../common/providers/provider.result';
import { DuffelService } from '../../duffel/duffel.service';

/**
 * Booking capability adapter for the Duffel flight provider (Phase 4A).
 *
 * Reuses the EXISTING DuffelService methods (`revalidateOffer`, `createOrder`)
 * — it does not re-implement any provider call. Duffel flights can be booked
 * and revalidated; cancellation is unsupported, so `cancel` is false and the
 * service will surface a structured capability error instead of calling a
 * non-existent path.
 *
 * Payment is deliberately NOT part of this adapter (spec: 4A ships no
 * payment). `createOrder` runs in `instant` mode per existing behaviour.
 */
@Injectable()
export class DuffelBookingProvider implements BookingProvider {
  constructor(private readonly duffel: DuffelService) {}

  readonly providerId = 'duffel-flight';

  get providerName(): string {
    return this.duffel.providerName;
  }

  readonly bookingCapability = {
    book: true,
    cancel: false,
    revalidate: true,
  } as const;

  async revalidateBooking(
    offerId: string,
  ): Promise<ProviderResult<BookingRevalidation>> {
    const result = await this.duffel.revalidateOffer(offerId);
    if (!result.success || !result.data) {
      return {
        success: false,
        providerId: this.providerId,
        providerName: this.providerName,
        error: result.error ?? 'Duffel revalidation failed',
        timestamp: result.timestamp,
      };
    }
    const data = result.data;
    return {
      success: true,
      providerId: this.providerId,
      providerName: this.providerName,
      data: {
        price: Number(data.price ?? 0),
        currency: String(data.currency ?? 'USD'),
        available: data.available !== false && Number(data.price ?? 0) > 0,
        expiresAt: data.expiresAt,
      },
      timestamp: result.timestamp,
    };
  }

  async createBooking(
    input: CreateBookingInput,
  ): Promise<ProviderResult<CreatedBooking>> {
    try {
      const order: any = await this.duffel.createOrder(
        input.offerId,
        input.travelers ?? [],
        [],
      );
      const reference =
        order?.booking_reference ?? order?.id ?? String(order?.id ?? '');
      return {
        success: true,
        providerId: this.providerId,
        providerName: this.providerName,
        data: {
          reference: String(reference),
          providerBookingId: order?.id,
          status: order?.status,
          amount: order?.total_amount ? Number(order.total_amount) : undefined,
          currency: order?.total_currency,
          raw: order,
        },
        timestamp: new Date(),
      };
    } catch (error) {
      return {
        success: false,
        providerId: this.providerId,
        providerName: this.providerName,
        error: (error as Error).message,
        timestamp: new Date(),
      };
    }
  }

  async cancelBooking(
    _input: CancelBookingInput,
  ): Promise<ProviderResult<{ cancelled: boolean }>> {
    return {
      success: false,
      providerId: this.providerId,
      providerName: this.providerName,
      error: 'Duffel cancellation is not supported',
      timestamp: new Date(),
    };
  }
}
