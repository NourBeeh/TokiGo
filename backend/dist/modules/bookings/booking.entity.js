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
Object.defineProperty(exports, "__esModule", { value: true });
exports.Booking = exports.BOOKING_STATUSES = void 0;
const typeorm_1 = require("typeorm");
/**
 * Booking foundation (Phase 4A).
 *
 * The persisted, JWT-scoped booking record. It is the ONLY source of booking
 * truth: the client's Hive snapshot is never trusted as a final price, and
 * `authoritativePrice` always originates from a provider-side revalidation
 * performed at prepare/create time — never from the request body.
 *
 * Provider snapshot (`offerSnapshot`) is mandatory to persist because some
 * providers hand back single-use handoff ids (Nuitee `prebookId` /
 * `transactionId`) that are NOT recoverable if the response is lost. Losing
 * them would strand a payable quote — so they live in this row, never in
 * Flutter, and are never returned raw to the client.
 *
 * Idempotency: logical uniqueness on (userId, idempotencyKey) guarantees a
 * retried create can never produce a second booking. A null key (prepare
 * stage) is allowed and does not collide (Postgres treats NULLs as distinct).
 *
 * No payment secrets or provider credentials are ever stored here (spec
 * non-negotiable) — payment is a later phase.
 */
exports.BOOKING_STATUSES = [
    'prepared',
    'revalidated',
    'confirming',
    'confirmed',
    'failed',
    'cancelled',
    'expired',
];
let Booking = class Booking {
    id;
    /** Owning user — ALWAYS derived from the JWT, never from the request body. */
    userId;
    searchId;
    offerId;
    /** Provider identity is mandatory — an offer without one cannot be booked. */
    providerId;
    providerName;
    /** Vertical: flight | hotel | car | package. */
    type;
    status;
    currency;
    /** Provider-side authoritative amount (never a client-supplied price). */
    authoritativePrice;
    /** Previous authoritative amount when a revalidation moved the price. */
    previousPrice;
    priceBreakdown;
    /**
     * Provider handoff snapshot (single-use ids, raw offer facts). Mandatory in
     * practice for providers with prebook handoff ids. Never returned raw.
     */
    offerSnapshot;
    travelers;
    /** Provider confirmation reference (PNR / confirmation number). */
    bookingReference;
    providerMetadata;
    /** Client-generated idempotency key (unique per user). */
    idempotencyKey;
    /** Quote expiry when the provider communicates one. */
    expiresAt;
    createdAt;
    updatedAt;
};
exports.Booking = Booking;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], Booking.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)(),
    __metadata("design:type", String)
], Booking.prototype, "userId", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', nullable: true }),
    __metadata("design:type", Object)
], Booking.prototype, "searchId", void 0);
__decorate([
    (0, typeorm_1.Column)(),
    __metadata("design:type", String)
], Booking.prototype, "offerId", void 0);
__decorate([
    (0, typeorm_1.Column)(),
    __metadata("design:type", String)
], Booking.prototype, "providerId", void 0);
__decorate([
    (0, typeorm_1.Column)(),
    __metadata("design:type", String)
], Booking.prototype, "providerName", void 0);
__decorate([
    (0, typeorm_1.Column)(),
    __metadata("design:type", String)
], Booking.prototype, "type", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', default: 'prepared' }),
    __metadata("design:type", String)
], Booking.prototype, "status", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', default: 'USD' }),
    __metadata("design:type", String)
], Booking.prototype, "currency", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'real', default: 0 }),
    __metadata("design:type", Number)
], Booking.prototype, "authoritativePrice", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'real', nullable: true }),
    __metadata("design:type", Object)
], Booking.prototype, "previousPrice", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'jsonb', nullable: true }),
    __metadata("design:type", Object)
], Booking.prototype, "priceBreakdown", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'jsonb', default: () => "'{}'" }),
    __metadata("design:type", Object)
], Booking.prototype, "offerSnapshot", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'jsonb', default: () => "'[]'" }),
    __metadata("design:type", Array)
], Booking.prototype, "travelers", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', nullable: true }),
    __metadata("design:type", Object)
], Booking.prototype, "bookingReference", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'jsonb', nullable: true }),
    __metadata("design:type", Object)
], Booking.prototype, "providerMetadata", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', nullable: true }),
    __metadata("design:type", Object)
], Booking.prototype, "idempotencyKey", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'timestamptz', nullable: true }),
    __metadata("design:type", Object)
], Booking.prototype, "expiresAt", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)(),
    __metadata("design:type", Date)
], Booking.prototype, "createdAt", void 0);
__decorate([
    (0, typeorm_1.UpdateDateColumn)(),
    __metadata("design:type", Date)
], Booking.prototype, "updatedAt", void 0);
exports.Booking = Booking = __decorate([
    (0, typeorm_1.Entity)('bookings'),
    (0, typeorm_1.Index)('idx_bookings_user_idempotency', ['userId', 'idempotencyKey'], {
        unique: true,
    })
], Booking);
//# sourceMappingURL=booking.entity.js.map