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
exports.WebhookDto = exports.RefundDto = exports.ConfirmPaymentDto = exports.CreatePaymentDto = void 0;
const class_validator_1 = require("class-validator");
/**
 * Payment contracts (Stage-2 refactor, 2026-10-25).
 *
 * These used to be plain classes declared INSIDE the controller with no
 * decorators at all. The global ValidationPipe runs with `whitelist: true` and
 * `forbidNonWhitelisted: true`, and an undecorated class has ZERO allowed
 * properties — so every `/payments/*` POST was rejected with
 * 400 "property X should not exist" before the handler ever ran. Checkout
 * therefore always fell back to "Payment unavailable for this market".
 *
 * The fields below are exactly what the Flutter checkout sends
 * (`lib/features/booking/application/services/checkout_payment_service.dart`);
 * adding a field to that client without adding it here is a 400, and that is
 * the intended behaviour.
 */
/** Intent: what the customer is about to pay for. */
class CreatePaymentDto {
    bookingId;
    /** Minor-unit-free decimal amount as the client quoted it. */
    amount;
    /** ISO-4217, e.g. EGP / USD. */
    currency;
    /** Market the payment is routed through (EG, AE, …). */
    market;
    /** Client-generated; the gateway deduplicates on it (spec point 10). */
    idempotencyKey;
}
exports.CreatePaymentDto = CreatePaymentDto;
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MinLength)(1),
    __metadata("design:type", String)
], CreatePaymentDto.prototype, "bookingId", void 0);
__decorate([
    (0, class_validator_1.IsNumber)(),
    (0, class_validator_1.Min)(0),
    __metadata("design:type", Number)
], CreatePaymentDto.prototype, "amount", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.Matches)(/^[A-Z]{3}$/, { message: 'currency must be an ISO-4217 code' }),
    __metadata("design:type", String)
], CreatePaymentDto.prototype, "currency", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.Matches)(/^[A-Za-z]{2,3}$/, { message: 'market must be a 2-3 letter code' }),
    __metadata("design:type", String)
], CreatePaymentDto.prototype, "market", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MinLength)(1),
    __metadata("design:type", String)
], CreatePaymentDto.prototype, "idempotencyKey", void 0);
/** Confirm: the customer picked a method for an existing intent. */
class ConfirmPaymentDto {
    paymentId;
    methodReference;
    market;
    idempotencyKey;
    bookingId;
}
exports.ConfirmPaymentDto = ConfirmPaymentDto;
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MinLength)(1),
    __metadata("design:type", String)
], ConfirmPaymentDto.prototype, "paymentId", void 0);
__decorate([
    (0, class_validator_1.IsIn)(['CARD_SUCCESS', 'CARD_3DS', 'CARD_DECLINED', 'WALLET']),
    __metadata("design:type", String)
], ConfirmPaymentDto.prototype, "methodReference", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.Matches)(/^[A-Za-z]{2,3}$/, { message: 'market must be a 2-3 letter code' }),
    __metadata("design:type", String)
], ConfirmPaymentDto.prototype, "market", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MinLength)(1),
    __metadata("design:type", String)
], ConfirmPaymentDto.prototype, "idempotencyKey", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MinLength)(1),
    __metadata("design:type", String)
], ConfirmPaymentDto.prototype, "bookingId", void 0);
/** Refund: full or partial, always tied to the original intent. */
class RefundDto {
    paymentId;
    amount;
    reason;
    market;
    idempotencyKey;
    bookingId;
}
exports.RefundDto = RefundDto;
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MinLength)(1),
    __metadata("design:type", String)
], RefundDto.prototype, "paymentId", void 0);
__decorate([
    (0, class_validator_1.IsNumber)(),
    (0, class_validator_1.Min)(0),
    __metadata("design:type", Number)
], RefundDto.prototype, "amount", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], RefundDto.prototype, "reason", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.Matches)(/^[A-Za-z]{2,3}$/, { message: 'market must be a 2-3 letter code' }),
    __metadata("design:type", String)
], RefundDto.prototype, "market", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MinLength)(1),
    __metadata("design:type", String)
], RefundDto.prototype, "idempotencyKey", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MinLength)(1),
    __metadata("design:type", String)
], RefundDto.prototype, "bookingId", void 0);
/** Gateway callback. The signature is verified by the gateway, not here. */
class WebhookDto {
    id;
    paymentId;
    type;
    signature;
    occurredAt;
    market;
}
exports.WebhookDto = WebhookDto;
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MinLength)(1),
    __metadata("design:type", String)
], WebhookDto.prototype, "id", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MinLength)(1),
    __metadata("design:type", String)
], WebhookDto.prototype, "paymentId", void 0);
__decorate([
    (0, class_validator_1.IsIn)(['payment.succeeded', 'payment.failed', 'payment.refunded']),
    __metadata("design:type", String)
], WebhookDto.prototype, "type", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.IsNotEmpty)(),
    __metadata("design:type", String)
], WebhookDto.prototype, "signature", void 0);
__decorate([
    (0, class_validator_1.IsISO8601)(),
    __metadata("design:type", String)
], WebhookDto.prototype, "occurredAt", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.Matches)(/^[A-Za-z]{2,3}$/, { message: 'market must be a 2-3 letter code' }),
    __metadata("design:type", String)
], WebhookDto.prototype, "market", void 0);
//# sourceMappingURL=payment.dto.js.map