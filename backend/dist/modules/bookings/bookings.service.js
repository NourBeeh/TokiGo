"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.BookingsService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const booking_entity_1 = require("./booking.entity");
const booking_provider_registry_1 = require("./booking-provider.registry");
const booking_exception_1 = require("./booking.exception");
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
let BookingsService = class BookingsService {
    bookings;
    registry;
    constructor(bookings, registry) {
        this.bookings = bookings;
        this.registry = registry;
    }
    async prepare(userId, dto) {
        const provider = this.requireCapability(dto.providerId, 'book');
        const revalidation = await provider.revalidateBooking(dto.offerId);
        if (!revalidation.success || !revalidation.data) {
            throw new booking_exception_1.BookingException('provider_unavailable', revalidation.error ?? 'Provider revalidation failed');
        }
        const { price, currency, available, expiresAt, handoff } = revalidation.data;
        if (!available || price <= 0) {
            throw new booking_exception_1.BookingException('no_availability', 'This offer is no longer available');
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
    async revalidate(userId, bookingId) {
        const booking = await this.findOwn(userId, bookingId);
        if (!['prepared', 'revalidated'].includes(booking.status)) {
            throw new booking_exception_1.BookingException('validation_failed', `Booking cannot be revalidated in status '${booking.status}'`);
        }
        const provider = this.requireCapability(booking.providerId, 'revalidate');
        const revalidation = await provider.revalidateBooking(booking.offerId);
        if (!revalidation.success || !revalidation.data) {
            throw new booking_exception_1.BookingException('provider_unavailable', revalidation.error ?? 'Provider revalidation failed');
        }
        const { price, currency, available, expiresAt, handoff } = revalidation.data;
        if (!available || price <= 0) {
            throw new booking_exception_1.BookingException('no_availability', 'This offer is no longer available');
        }
        const oldPrice = booking.authoritativePrice;
        const priceChanged = Math.abs(oldPrice - price) > PRICE_TOLERANCE;
        booking.previousPrice = priceChanged ? oldPrice : booking.previousPrice ?? null;
        booking.authoritativePrice = price;
        booking.currency = currency;
        booking.status = 'revalidated';
        booking.offerSnapshot = { ...booking.offerSnapshot, ...(handoff ?? {}) };
        if (expiresAt)
            booking.expiresAt = new Date(expiresAt);
        return this.toResponse(await this.bookings.save(booking));
    }
    async create(userId, dto) {
        const booking = await this.findOwn(userId, dto.bookingId);
        // Idempotent replay: the same key already confirmed this booking.
        if (booking.idempotencyKey === dto.idempotencyKey && booking.status === 'confirmed') {
            return this.toResponse(booking);
        }
        if (booking.status === 'confirming') {
            throw new booking_exception_1.BookingException('duplicate_request', 'A booking confirmation is already in progress');
        }
        if (['cancelled', 'expired'].includes(booking.status)) {
            throw new booking_exception_1.BookingException('booking_expired', `Booking can no longer be confirmed (status '${booking.status}')`);
        }
        // Reserve the idempotency key before any provider call. The unique index
        // on (userId, idempotencyKey) makes a concurrent retry fail closed.
        booking.status = 'confirming';
        booking.idempotencyKey = dto.idempotencyKey;
        booking.travelers = dto.travelers ?? [];
        try {
            await this.bookings.save(booking);
        }
        catch (error) {
            if (this.isUniqueViolation(error)) {
                throw new booking_exception_1.BookingException('duplicate_request', 'Duplicate booking request');
            }
            throw error;
        }
        const provider = this.registry.resolve(booking.providerId);
        if (!provider || !provider.bookingCapability.book) {
            await this.fail(booking);
            throw new booking_exception_1.BookingException('capability_unsupported', `Provider '${booking.providerId}' cannot create bookings`);
        }
        // Revalidate immediately before commit — never book a stale price.
        const revalidation = await provider.revalidateBooking(booking.offerId);
        if (!revalidation.success || !revalidation.data) {
            await this.fail(booking);
            throw new booking_exception_1.BookingException('provider_unavailable', revalidation.error ?? 'Provider revalidation failed');
        }
        const live = revalidation.data;
        if (!live.available || live.price <= 0) {
            await this.fail(booking);
            throw new booking_exception_1.BookingException('no_availability', 'This offer is no longer available');
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
            throw new booking_exception_1.BookingException('price_changed', 'The price changed; please review and accept the new amount', { previousPrice: booking.previousPrice, currentPrice: live.price });
        }
        const created = await provider.createBooking({
            offerId: booking.offerId,
            offerSnapshot: booking.offerSnapshot,
            travelers: booking.travelers,
        });
        if (!created.success || !created.data) {
            await this.fail(booking);
            throw new booking_exception_1.BookingException('provider_error', created.error ?? 'Provider booking failed');
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
    async get(userId, bookingId) {
        return this.toResponse(await this.findOwn(userId, bookingId));
    }
    async getStatus(userId, bookingId) {
        return this.toResponse(await this.findOwn(userId, bookingId));
    }
    async cancel(userId, bookingId) {
        const booking = await this.findOwn(userId, bookingId);
        const provider = this.registry.resolve(booking.providerId);
        if (!provider ||
            !provider.bookingCapability.cancel ||
            typeof provider.cancelBooking !== 'function') {
            throw new booking_exception_1.BookingException('capability_unsupported', `Provider '${booking.providerId}' does not support cancellation`);
        }
        if (booking.status === 'cancelled') {
            return this.toResponse(booking);
        }
        const result = await provider.cancelBooking({
            bookingReference: booking.bookingReference ?? undefined,
            offerSnapshot: booking.offerSnapshot,
        });
        if (!result.success) {
            throw new booking_exception_1.BookingException('provider_error', result.error ?? 'Provider cancellation failed');
        }
        booking.status = 'cancelled';
        return this.toResponse(await this.bookings.save(booking));
    }
    // ------------------------------------------------------------------
    async findOwn(userId, bookingId) {
        const booking = await this.bookings.findOne({
            where: { id: bookingId, userId },
        });
        if (!booking) {
            throw new booking_exception_1.BookingException('booking_not_found', 'Booking not found');
        }
        return booking;
    }
    requireCapability(providerId, action) {
        const provider = this.registry.resolve(providerId);
        if (!provider || !provider.bookingCapability[action]) {
            throw new booking_exception_1.BookingException('capability_unsupported', `Provider '${providerId}' does not support ${action}`);
        }
        return provider;
    }
    async fail(booking) {
        booking.status = 'failed';
        booking.idempotencyKey = null;
        try {
            await this.bookings.save(booking);
        }
        catch {
            // Persisting the failure must never mask the original error.
        }
    }
    isUniqueViolation(error) {
        return (error instanceof typeorm_2.QueryFailedError &&
            error?.driverError?.code === '23505');
    }
    inferType(providerId) {
        if (providerId.includes('flight'))
            return 'flight';
        if (providerId.includes('hotel') || providerId === 'nuitee')
            return 'hotel';
        if (providerId.includes('car'))
            return 'car';
        return 'flight';
    }
    toResponse(booking) {
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
            priceChanged: booking.previousPrice != null &&
                Math.abs(booking.previousPrice - booking.authoritativePrice) > PRICE_TOLERANCE,
            available: !['failed', 'expired', 'cancelled'].includes(booking.status),
            bookingReference: booking.bookingReference ?? null,
            travelers: booking.travelers ?? [],
            expiresAt: booking.expiresAt ?? null,
            createdAt: booking.createdAt,
            updatedAt: booking.updatedAt,
        };
    }
};
exports.BookingsService = BookingsService;
exports.BookingsService = BookingsService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(booking_entity_1.Booking)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        booking_provider_registry_1.BookingProviderRegistry])
], BookingsService);
//# sourceMappingURL=bookings.service.js.map