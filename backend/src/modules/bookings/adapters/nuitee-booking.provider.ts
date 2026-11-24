import { Injectable } from '@nestjs/common';
import {
  BookingProvider,
  BookingRevalidation,
  CancelBookingInput,
  CreatedBooking,
  CreateBookingInput,
  RevalidationContext,
} from '../../../common/providers/booking-provider.interface';
import { ProviderResult } from '../../../common/providers/provider.result';
import { classifyBookingTransportFailure } from '../../../common/providers/booking-failure';
import {
  bookingProviderTags,
  confirmationStateOfStatus,
} from '../../../common/providers/booking-confirmation';
import { NuiteeService } from '../../nuitee/nuitee.service';
import {
  NuiteeBookingGuest,
  NuiteeBookingHolder,
} from '../../nuitee/nuitee.types';

/**
 * Booking capability adapter for the Nuitee Connect hotel provider (Phase 4A).
 *
 * Reuses the EXISTING NuiteeService methods (`prebookHotel`, `bookHotel`).
 *
 * The prebook handoff (`prebookId`) is single-use-per-booking and NOT
 * recoverable if lost, so `revalidateBooking` surfaces it through `handoff`
 * and the booking service persists it in `offerSnapshot` until create.
 * `transactionId` is NOT part of this flow: the merchant-of-record model uses
 * `usePaymentSdk: false`, where Nuitee does not issue one.
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
    _context?: RevalidationContext,
  ): Promise<ProviderResult<BookingRevalidation>> {
    // `offerId` is the room-type offer id (Nuitee `roomTypes[].offerId`), the
    // identity prebook accepts — never a per-room rate id.
    const result = await this.nuitee.prebookHotel({ offerId });
    if (!result.success) {
      return {
        success: false,
        providerId: this.providerId,
        providerName: this.providerName,
        error: result.error ?? 'Nuitee prebook failed',
        timestamp: new Date(),
      };
    }
    // The documented prebook response always carries `price` and `currency`;
    // a missing one is not a usable quote.
    const price = Number(result.newPrice ?? 0);
    const currency = result.currency;
    if (!currency || !Number.isFinite(price) || price <= 0) {
      return {
        success: false,
        providerId: this.providerId,
        providerName: this.providerName,
        error: 'Nuitee prebook returned no usable price',
        timestamp: new Date(),
      };
    }
    return {
      success: true,
      providerId: this.providerId,
      providerName: this.providerName,
      data: {
        price,
        currency,
        available: true,
        expiresAt: result.expiresAt,
        priceChanged: result.priceChanged,
        oldPrice: result.oldPrice,
        ...(result.terms ? { terms: result.terms } : {}),
        ...(result.termsVersion ? { termsVersion: result.termsVersion } : {}),
        ...(Array.isArray(result.changedTerms) && result.changedTerms.length > 0
          ? { changedTerms: result.changedTerms }
          : {}),
        handoff: {
          offerId,
          prebookId: result.prebookId,
          // Present only if Nuitee actually returned it; never required.
          ...(result.transactionId
            ? { transactionId: result.transactionId }
            : {}),
          // The room count is what the guest list must map 1:1 to.
          ...(result.roomCount ? { roomCount: result.roomCount } : {}),
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
    if (!prebookId) {
      return {
        success: false,
        providerId: this.providerId,
        providerName: this.providerName,
        error: 'Missing Nuitee prebook handoff (prebookId)',
        failureKind: 'definitive',
        timestamp: new Date(),
      };
    }

    const travelers = input.travelers ?? [];
    const holder = this.holderFrom(travelers);
    if (!holder) {
      return {
        success: false,
        providerId: this.providerId,
        providerName: this.providerName,
        error:
          'Nuitee booking requires the holder first/last name, email and phone',
        failureKind: 'definitive',
        timestamp: new Date(),
      };
    }

    const roomCount =
      typeof snapshot.roomCount === 'number' && snapshot.roomCount > 0
        ? snapshot.roomCount
        : undefined;
    const guests = this.guestsFrom(travelers, roomCount);
    if (!guests.ok) {
      return {
        success: false,
        providerId: this.providerId,
        providerName: this.providerName,
        error: guests.error,
        failureKind: 'definitive',
        timestamp: new Date(),
      };
    }

    const tags = bookingProviderTags(input);
    const result = await this.nuitee.bookHotel({
      prebookId: String(prebookId),
      holder,
      guests: guests.value,
      // Nuitee's documented idempotency key. A duplicate submission returns
      // their 4005 code, which the transport classifies as ambiguous — so the
      // booking stays reconciliation-pending instead of double-booking.
      ...(input.bookingId ? { clientReference: input.bookingId } : {}),
      // Non-sensitive labels bind the provider booking to this TokiGo
      // booking/payment/price version (Nuitee allows at most five tags).
      ...(Object.keys(tags).length > 0 ? { customTags: tags } : {}),
    });

    if (!result.success || !result.data) {
      return {
        success: false,
        providerId: this.providerId,
        providerName: this.providerName,
        error: result.error ?? 'Nuitee booking failed',
        failureKind: classifyBookingTransportFailure({
          failureKind: result.failureKind,
          error: result.error,
        }),
        timestamp: result.timestamp ?? new Date(),
      };
    }

    const data = result.data;
    return {
      success: true,
      providerId: this.providerId,
      providerName: this.providerName,
      data: {
        // The hotel confirmation code is not issued at booking time; fall back
        // to the provider booking id, and never invent a reference.
        reference: String(data.hotelConfirmationCode ?? data.bookingId ?? ''),
        providerBookingId: data.bookingId,
        status: data.status,
        // Only an explicit CONFIRMED status may confirm the TokiGo booking.
        // CREATED/PENDING/unknown stay reconciliation-pending.
        confirmationState: confirmationStateOfStatus(data.status),
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

  /**
   * The holder is the payer/booking owner: the traveller explicitly flagged as
   * holder, else the first traveller carrying a complete contact set. A
   * missing email/phone is never filled with a placeholder.
   */
  private holderFrom(travelers: any[]): NuiteeBookingHolder | null {
    const flagged = travelers.find(
      (t: any) => t?.isHolder === true || t?.holder === true,
    );
    const candidates = flagged ? [flagged, ...travelers] : travelers;
    for (const t of candidates) {
      const firstName = clean(t?.firstName);
      const lastName = clean(t?.lastName);
      const email = clean(t?.email);
      const phone = clean(t?.phone);
      if (firstName && lastName && email && phone) {
        return { firstName, lastName, email, phone };
      }
    }
    return null;
  }

  /**
   * Nuitee wants ONE primary guest per booked room, keyed by
   * `occupancyNumber` (1-based). Travellers carry the room they belong to; a
   * list that cannot be mapped 1:1 onto the booked rooms is rejected rather
   * than assigned rooms by guesswork.
   */
  private guestsFrom(
    travelers: any[],
    roomCount?: number,
  ):
    | { ok: true; value: NuiteeBookingGuest[] }
    | { ok: false; error: string } {
    if (travelers.length === 0) {
      return { ok: false, error: 'Nuitee booking requires at least one guest' };
    }

    const withRoom = travelers.filter(
      (t: any) =>
        Number.isInteger(Number(t?.occupancyNumber)) &&
        Number(t.occupancyNumber) > 0,
    );
    const hasRoomMapping = withRoom.length === travelers.length;
    const byRoom = new Map<number, any>();

    if (hasRoomMapping) {
      for (const t of travelers) {
        const room = Number(t.occupancyNumber);
        // The first traveller of a room is its primary guest.
        if (!byRoom.has(room)) byRoom.set(room, t);
      }
    } else {
      if (roomCount && travelers.length > roomCount) {
        return {
          ok: false,
          error:
            'Nuitee booking needs an occupancyNumber per traveller to assign rooms',
        };
      }
      const rooms = roomCount ?? travelers.length;
      travelers.forEach((t: any, index: number) => {
        const room = Math.min(index + 1, rooms);
        if (!byRoom.has(room)) byRoom.set(room, t);
      });
    }

    if (byRoom.size === 0) {
      return {
        ok: false,
        error: 'Nuitee booking requires at least one room guest',
      };
    }
    if (roomCount && byRoom.size !== roomCount) {
      return {
        ok: false,
        error: `Nuitee booking has ${roomCount} room(s) but ${byRoom.size} guest room assignment(s)`,
      };
    }

    const guests: NuiteeBookingGuest[] = [];
    for (const room of [...byRoom.keys()].sort((a, b) => a - b)) {
      const t = byRoom.get(room);
      const firstName = clean(t?.firstName);
      const lastName = clean(t?.lastName);
      const email = clean(t?.email);
      if (!firstName || !lastName || !email) {
        return {
          ok: false,
          error: `Room ${room} guest is missing a first/last name or email`,
        };
      }
      guests.push({
        occupancyNumber: room,
        firstName,
        lastName,
        email,
        phone: clean(t?.phone),
        remarks: clean(t?.remarks),
      });
    }
    return { ok: true, value: guests };
  }
}

function clean(value: any): string | undefined {
  return typeof value === 'string' && value.trim().length > 0
    ? value.trim()
    : undefined;
}
