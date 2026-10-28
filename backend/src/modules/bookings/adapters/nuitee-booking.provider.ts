import { Injectable } from '@nestjs/common';
import {
  BookingProvider,
  BookingRevalidation,
  CancelBookingInput,
  CreatedBooking,
  CreateBookingInput,
} from '../../../common/providers/booking-provider.interface';
import { ProviderResult } from '../../../common/providers/provider.result';
import { NuiteeService } from '../../nuitee/nuitee.service';

/**
 * Booking capability adapter for the Nuitee Connect hotel provider (Phase 4A).
 *
 * Reuses the EXISTING NuiteeService methods (`prebookHotel`, `bookHotel`).
 * The prebook handoff (`prebookId` / `transactionId`) is single-use and NOT
 * recoverable if lost, so `revalidateBooking` surfaces it through `handoff`
 * and the booking service persists it in `offerSnapshot` until create.
 *
 * Cancellation is unsupported → `cancel` false → structured capability error.
 * Payment stays out of scope (spec: no payment in 4A).
 */
@Injectable()
export class NuiteeBookingProvider implements BookingProvider {
  constructor(private readonly nuitee: NuiteeService) {}

  readonly providerId = 'nuitee';

  get providerName(): string {
    return this.nuitee.providerName;
  }

  readonly bookingCapability = {
    book: true,
    cancel: false,
    revalidate: true,
  } as const;

  async revalidateBooking(
    offerId: string,
  ): Promise<ProviderResult<BookingRevalidation>> {
    const result = await this.nuitee.prebookHotel({ rateId: offerId });
    if (!result.success) {
      return {
        success: false,
        providerId: this.providerId,
        providerName: this.providerName,
        error: result.error ?? 'Nuitee prebook failed',
        timestamp: new Date(),
      };
    }
    const price = Number(result.newPrice ?? 0);
    return {
      success: true,
      providerId: this.providerId,
      providerName: this.providerName,
      data: {
        price,
        currency: result.currency ?? 'USD',
        available: price > 0,
        expiresAt: result.expiresAt,
        priceChanged: result.priceChanged,
        oldPrice: result.oldPrice,
        handoff: {
          rateId: offerId,
          prebookId: result.prebookId,
          transactionId: result.transactionId,
        },
      },
      timestamp: new Date(),
    };
  }

  async createBooking(
    input: CreateBookingInput,
  ): Promise<ProviderResult<CreatedBooking>> {
    const snapshot = input.offerSnapshot ?? {};
    const prebookId = snapshot.prebookId;
    const transactionId = snapshot.transactionId;
    if (!prebookId || !transactionId) {
      return {
        success: false,
        providerId: this.providerId,
        providerName: this.providerName,
        error: 'Missing Nuitee prebook handoff (prebookId/transactionId)',
        timestamp: new Date(),
      };
    }

    const travelers = input.travelers ?? [];
    const names = travelers
      .map((t: any) => `${t?.firstName ?? ''} ${t?.lastName ?? ''}`.trim())
      .filter(Boolean);
    const holderName = names[0] ?? 'TokiGo Guest';
    const holderEmail = travelers[0]?.email;

    const result = await this.nuitee.bookHotel({
      prebookId: String(prebookId),
      transactionId: String(transactionId),
      holderName,
      holderEmail,
      guestNames: names.length ? names : [holderName],
    });

    if (!result.success || !result.data) {
      return {
        success: false,
        providerId: this.providerId,
        providerName: this.providerName,
        error: result.error ?? 'Nuitee booking failed',
        timestamp: result.timestamp ?? new Date(),
      };
    }

    const data = result.data;
    return {
      success: true,
      providerId: this.providerId,
      providerName: this.providerName,
      data: {
        reference: String(data.reference ?? data.bookingId ?? ''),
        providerBookingId: data.bookingId,
        status: data.status,
        amount: data.total,
        currency: data.currency,
        raw: data,
      },
      timestamp: result.timestamp ?? new Date(),
    };
  }

  async cancelBooking(
    _input: CancelBookingInput,
  ): Promise<ProviderResult<{ cancelled: boolean }>> {
    return {
      success: false,
      providerId: this.providerId,
      providerName: this.providerName,
      error: 'Nuitee cancellation is not supported',
      timestamp: new Date(),
    };
  }
}
