import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { QueryFailedError, Repository } from 'typeorm';

import { Booking } from './booking.entity';
import { BookingProviderRegistry } from './booking-provider.registry';
import { BookingException } from './booking.exception';
import { BookingProvider } from '../../common/providers/booking-provider.interface';
import {
  CreateBookingDto,
  PrepareBookingDto,
} from '../../common/dto/booking.dto';

/** Wire shape returned to the client — never leaks the provider snapshot. */
export interface BookingResponse {
  id: string;
  userId: string;
  searchId: string | null;
  offerId: string;
  providerId: string;
  providerName: string;
  type: string;
  status: string;
  currency: string;
  authoritativePrice: number;
  previousPrice: number | null;
  priceChanged: boolean;
  available: boolean;
  bookingReference: string | null;
  travelers: any[];
  expiresAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
}

const PRICE_TOLERANCE = 0.01;

/**
 * Booking foundation service (Phase 4A).
 *
 * Rules enforced here:
 *  - provider identity is mandatory and capabilities are checked first;
 *  - the authoritative price ALWAYS comes from a provider revalidation, never
 *    from the client or a Hive snapshot;
 *  - a provider-backed offer is revalidated again immediately before commit;
 *  - create is idempotent on (userId, idempotencyKey) — retries cannot
 *    double-book;
 *  - failures are normalised to a stable `code` (BookingException).
 *
 * No payment, no provider credentials, no secret are handled here.
 */
@Injectable()
export class BookingsService {
  constructor(
    @InjectRepository(Booking)
    private readonly bookings: Repository<Booking>,
    private readonly registry: BookingProviderRegistry,
  ) {}

  async prepare(userId: string, dto: PrepareBookingDto): Promise<BookingResponse> {
    const provider = this.requireCapability(dto.providerId, 'book');

    const revalidation = await provider.revalidateBooking(dto.offerId);
    if (!revalidation.success || !revalidation.data) {
      throw new BookingException(
        'provider_unavailable',
        revalidation.error ?? 'Provider revalidation failed',
      );
    }
    const { price, currency, available, expiresAt, handoff } = revalidation.data;
    if (!available || price <= 0) {
      throw new BookingException(
        'no_availability',
        'This offer is no longer available',
      );
    }

    const booking = this.bookings.create({
      userId,
      searchId: dto.searchId ?? null,
      offerId: dto.offerId,
      providerId: provider.providerId,
      providerName: dto.providerName ?? provider.providerName,
      type: dto.offerType ?? this.inferType(provider.providerId),
      status: 'prepared',
      currency,
      authoritativePrice: price,
      offerSnapshot: { offerId: dto.offerId, ...(handoff ?? {}) },
      travelers: [],
      expiresAt: expiresAt ? new Date(expiresAt) : null,
    });
    return this.toResponse(await this.bookings.save(booking));
  }

  async revalidate(userId: string, bookingId: string): Promise<BookingResponse> {
    const booking = await this.findOwn(userId, bookingId);
    if (!['prepared', 'revalidated'].includes(booking.status)) {
      throw new BookingException(
        'validation_failed',
        `Booking cannot be revalidated in status '${booking.status}'`,
      );
    }

    const provider = this.requireCapability(booking.providerId, 'revalidate');
    const revalidation = await provider.revalidateBooking(booking.offerId);
    if (!revalidation.success || !revalidation.data) {
      throw new BookingException(
        'provider_unavailable',
        revalidation.error ?? 'Provider revalidation failed',
      );
    }
    const { price, currency, available, expiresAt, handoff } = revalidation.data;
    if (!available || price <= 0) {
      throw new BookingException(
        'no_availability',
        'This offer is no longer available',
      );
    }

    const oldPrice = booking.authoritativePrice;
    const priceChanged = Math.abs(oldPrice - price) > PRICE_TOLERANCE;

    booking.previousPrice = priceChanged ? oldPrice : booking.previousPrice ?? null;
    booking.authoritativePrice = price;
    booking.currency = currency;
    booking.status = 'revalidated';
    booking.offerSnapshot = { ...booking.offerSnapshot, ...(handoff ?? {}) };
    if (expiresAt) booking.expiresAt = new Date(expiresAt);

    return this.toResponse(await this.bookings.save(booking));
  }

  async create(userId: string, dto: CreateBookingDto): Promise<BookingResponse> {
    const booking = await this.findOwn(userId, dto.bookingId);

    // Idempotent replay: the same key already confirmed this booking.
    if (booking.idempotencyKey === dto.idempotencyKey && booking.status === 'confirmed') {
      return this.toResponse(booking);
    }
    if (booking.status === 'confirming') {
      throw new BookingException(
        'duplicate_request',
        'A booking confirmation is already in progress',
      );
    }
    if (['cancelled', 'expired'].includes(booking.status)) {
      throw new BookingException(
        'booking_expired',
        `Booking can no longer be confirmed (status '${booking.status}')`,
      );
    }

    // Reserve the idempotency key before any provider call. The unique index
    // on (userId, idempotencyKey) makes a concurrent retry fail closed.
    booking.status = 'confirming';
    booking.idempotencyKey = dto.idempotencyKey;
    booking.travelers = dto.travelers ?? [];
    try {
      await this.bookings.save(booking);
    } catch (error) {
      if (this.isUniqueViolation(error)) {
        throw new BookingException(
          'duplicate_request',
          'Duplicate booking request',
        );
      }
      throw error;
    }

    const provider = this.registry.resolve(booking.providerId);
    if (!provider || !provider.bookingCapability.book) {
      await this.fail(booking);
      throw new BookingException(
        'capability_unsupported',
        `Provider '${booking.providerId}' cannot create bookings`,
      );
    }

    // Revalidate immediately before commit — never book a stale price.
    const revalidation = await provider.revalidateBooking(booking.offerId);
    if (!revalidation.success || !revalidation.data) {
      await this.fail(booking);
      throw new BookingException(
        'provider_unavailable',
        revalidation.error ?? 'Provider revalidation failed',
      );
    }
    const live = revalidation.data;
    if (!live.available || live.price <= 0) {
      await this.fail(booking);
      throw new BookingException(
        'no_availability',
        'This offer is no longer available',
      );
    }
    if (Math.abs(booking.authoritativePrice - live.price) > PRICE_TOLERANCE) {
      // Price moved: release the key, persist the new authoritative price and
      // make the client explicitly re-accept — never charge silently.
      booking.previousPrice = booking.authoritativePrice;
      booking.authoritativePrice = live.price;
      booking.currency = live.currency;
      booking.status = 'revalidated';
      booking.idempotencyKey = null;
      booking.offerSnapshot = { ...booking.offerSnapshot, ...(live.handoff ?? {}) };
      await this.bookings.save(booking);
      throw new BookingException(
        'price_changed',
        'The price changed; please review and accept the new amount',
        { previousPrice: booking.previousPrice, currentPrice: live.price },
      );
    }

    const created = await provider.createBooking({
      offerId: booking.offerId,
      offerSnapshot: booking.offerSnapshot,
      travelers: booking.travelers,
    });
    if (!created.success || !created.data) {
      await this.fail(booking);
      throw new BookingException(
        'provider_error',
        created.error ?? 'Provider booking failed',
      );
    }

    booking.status = 'confirmed';
    booking.bookingReference = created.data.reference;
    booking.providerMetadata = {
      providerBookingId: created.data.providerBookingId,
      providerStatus: created.data.status,
      amount: created.data.amount,
      currency: created.data.currency,
    };
    return this.toResponse(await this.bookings.save(booking));
  }

  async get(userId: string, bookingId: string): Promise<BookingResponse> {
    return this.toResponse(await this.findOwn(userId, bookingId));
  }

  async getStatus(userId: string, bookingId: string): Promise<BookingResponse> {
    return this.toResponse(await this.findOwn(userId, bookingId));
  }

  async cancel(userId: string, bookingId: string): Promise<BookingResponse> {
    const booking = await this.findOwn(userId, bookingId);
    const provider = this.registry.resolve(booking.providerId);
    if (
      !provider ||
      !provider.bookingCapability.cancel ||
      typeof provider.cancelBooking !== 'function'
    ) {
      throw new BookingException(
        'capability_unsupported',
        `Provider '${booking.providerId}' does not support cancellation`,
      );
    }
    if (booking.status === 'cancelled') {
      return this.toResponse(booking);
    }
    const result = await provider.cancelBooking({
      bookingReference: booking.bookingReference ?? undefined,
      offerSnapshot: booking.offerSnapshot,
    });
    if (!result.success) {
      throw new BookingException(
        'provider_error',
        result.error ?? 'Provider cancellation failed',
      );
    }
    booking.status = 'cancelled';
    return this.toResponse(await this.bookings.save(booking));
  }

  // ------------------------------------------------------------------

  private async findOwn(userId: string, bookingId: string): Promise<Booking> {
    const booking = await this.bookings.findOne({
      where: { id: bookingId, userId },
    });
    if (!booking) {
      throw new BookingException('booking_not_found', 'Booking not found');
    }
    return booking;
  }

  private requireCapability(
    providerId: string,
    action: 'book' | 'revalidate' | 'cancel',
  ): BookingProvider {
    const provider = this.registry.resolve(providerId);
    if (!provider || !provider.bookingCapability[action]) {
      throw new BookingException(
        'capability_unsupported',
        `Provider '${providerId}' does not support ${action}`,
      );
    }
    return provider;
  }

  private async fail(booking: Booking): Promise<void> {
    booking.status = 'failed';
    booking.idempotencyKey = null;
    try {
      await this.bookings.save(booking);
    } catch {
      // Persisting the failure must never mask the original error.
    }
  }

  private isUniqueViolation(error: unknown): boolean {
    return (
      error instanceof QueryFailedError &&
      (error as any)?.driverError?.code === '23505'
    );
  }

  private inferType(providerId: string): string {
    if (providerId.includes('flight')) return 'flight';
    if (providerId.includes('hotel') || providerId === 'nuitee') return 'hotel';
    if (providerId.includes('car')) return 'car';
    return 'flight';
  }

  private toResponse(booking: Booking): BookingResponse {
    return {
      id: booking.id,
      userId: booking.userId,
      searchId: booking.searchId ?? null,
      offerId: booking.offerId,
      providerId: booking.providerId,
      providerName: booking.providerName,
      type: booking.type,
      status: booking.status,
      currency: booking.currency,
      authoritativePrice: booking.authoritativePrice,
      previousPrice: booking.previousPrice ?? null,
      priceChanged:
        booking.previousPrice != null &&
        Math.abs(booking.previousPrice - booking.authoritativePrice) > PRICE_TOLERANCE,
      available: !['failed', 'expired', 'cancelled'].includes(booking.status),
      bookingReference: booking.bookingReference ?? null,
      travelers: booking.travelers ?? [],
      expiresAt: booking.expiresAt ?? null,
      createdAt: booking.createdAt,
      updatedAt: booking.updatedAt,
    };
  }
}
