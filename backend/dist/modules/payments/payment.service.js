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
exports.PaymentService = void 0;
const common_1 = require("@nestjs/common");
const payment_router_1 = require("./payment.router");
const ledger_service_1 = require("./ledger.service");
const payment_gateway_1 = require("./payment.gateway");
/**
 * Payment orchestrator (spec point 31): one customer-payment abstraction
 * consumed by booking services. All money-changing operations are
 * idempotent and every movement lands in the ledger.
 */
let PaymentService = class PaymentService {
    router;
    ledger;
    processedWebhooks = new Set();
    // Ownership tracking: paymentId/bookingId -> owning userId (fail-closed).
    paymentOwners = new Map();
    bookingOwners = new Map();
    constructor(router, ledger) {
        this.router = router;
        this.ledger = ledger;
    }
    async createPayment(input, userId) {
        const region = (0, payment_gateway_1.routesForMarket)(input.market);
        const gateway = region ? this.router.forMarket(region) : null;
        if (!gateway) {
            return {
                status: 'UNAVAILABLE',
                reason: `No payment gateway configured for market ${input.market}`,
            };
        }
        const intent = await gateway.createPaymentIntent({
            bookingId: input.bookingId,
            idempotencyKey: input.idempotencyKey,
            amount: input.amount,
            currency: input.currency,
            market: input.market,
        });
        // Record ownership so later refund/confirm/ledger calls can be authorized.
        if (userId) {
            this.paymentOwners.set(intent.paymentId, userId);
            this.bookingOwners.set(input.bookingId, userId);
        }
        this.ledger.append({
            bookingId: input.bookingId,
            paymentId: intent.paymentId,
            gateway: gateway.gatewayId,
            side: 'CUSTOMER',
            type: 'CHARGE',
            amount: input.amount,
            currency: input.currency,
            externalReference: intent.paymentId,
        });
        return { status: 'OK', intent };
    }
    async confirmPayment(input, userId) {
        // Ownership check (fail-closed) — only when a caller identity is supplied.
        if (userId) {
            const owner = this.paymentOwners.get(input.paymentId);
            if (owner && owner !== userId) {
                throw new common_1.ForbiddenException('Payment does not belong to the caller.');
            }
            if (input.bookingId && this.bookingOwners.get(input.bookingId) && this.bookingOwners.get(input.bookingId) !== userId) {
                throw new common_1.ForbiddenException('Booking does not belong to the caller.');
            }
        }
        const gateway = this.router.forMarket((0, payment_gateway_1.routesForMarket)(input.market) ?? input.market);
        if (!gateway) {
            return { status: 'UNAVAILABLE' };
        }
        const intent = await gateway.confirmPayment({
            paymentId: input.paymentId,
            methodReference: input.methodReference,
            idempotencyKey: input.idempotencyKey,
        });
        return { status: 'OK', intent };
    }
    async refundPayment(input, userId) {
        // Ownership check (fail-closed) — only when a caller identity is supplied.
        if (userId) {
            const owner = this.paymentOwners.get(input.paymentId);
            if (owner && owner !== userId) {
                throw new common_1.ForbiddenException('Payment does not belong to the caller.');
            }
            if (input.bookingId && this.bookingOwners.get(input.bookingId) && this.bookingOwners.get(input.bookingId) !== userId) {
                throw new common_1.ForbiddenException('Booking does not belong to the caller.');
            }
        }
        const gateway = this.router.forMarket((0, payment_gateway_1.routesForMarket)(input.market) ?? input.market);
        if (!gateway) {
            return { status: 'UNAVAILABLE' };
        }
        const intent = await gateway.refundPayment({
            paymentId: input.paymentId,
            amount: input.amount,
            reason: input.reason,
            idempotencyKey: input.idempotencyKey,
        });
        // Refunds append a reversal entry — the original charge stays intact
        // (spec point 36: never update financial history destructively).
        this.ledger.append({
            bookingId: input.bookingId,
            paymentId: input.paymentId,
            gateway: gateway.gatewayId,
            side: 'REFUND',
            type: 'REFUND',
            amount: input.amount,
            currency: intent.currency,
            externalReference: input.paymentId,
            metadata: { reason: input.reason },
        });
        return { status: 'OK', intent };
    }
    async handleWebhook(payload) {
        const gateway = this.router.forMarket((0, payment_gateway_1.routesForMarket)(payload.market ?? 'EG') ?? 'EG');
        if (!gateway || !gateway.verifyWebhook(payload)) {
            return { status: 'REJECTED' };
        }
        // Replay protection: a webhook id must be processed at most once.
        if (this.processedWebhooks.has(payload.id)) {
            return { status: 'REJECTED' };
        }
        // Existence check: the payment must actually exist in the gateway.
        const existing = await gateway.retrievePayment(payload.paymentId);
        if (!existing) {
            return { status: 'REJECTED' };
        }
        this.processedWebhooks.add(payload.id);
        // Verified webhooks settle async (3DS) payments — the split-brain
        // recovery path (spec point O.9): payment success never assumes
        // booking success; booking services react to the status change.
        const mock = gateway;
        if (typeof mock.settlePending === 'function') {
            mock.settlePending(payload.paymentId);
        }
        return { status: 'PROCESSED' };
    }
    bookingTimeline(bookingId, userId) {
        if (userId) {
            const owner = this.bookingOwners.get(bookingId);
            // Fail-closed only when we have recorded ownership for this booking.
            // Unknown (legacy) bookings are allowed to keep backward compat with
            // pre-existing ledger entries, but only for the recording owner.
            if (owner && owner !== userId) {
                throw new common_1.ForbiddenException('Booking does not belong to the caller.');
            }
        }
        return this.ledger.forBooking(bookingId);
    }
};
exports.PaymentService = PaymentService;
exports.PaymentService = PaymentService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [payment_router_1.PaymentRouter,
        ledger_service_1.LedgerService])
], PaymentService);
//# sourceMappingURL=payment.service.js.map