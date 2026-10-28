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
exports.PaymentsController = void 0;
const common_1 = require("@nestjs/common");
const payment_service_1 = require("./payment.service");
const jwt_auth_guard_1 = require("../auth/jwt-auth.guard");
const payment_dto_1 = require("../../common/dto/payment.dto");
/**
 * Customer-payment endpoints (Flutter consumes only these).
 *
 * SECURITY MODEL
 * - `intent` / `confirm` / `refund` / `ledger` are JWT-guarded: a payment must
 *   belong to an authenticated traveller. They used to be fully open — with a
 *   `bookingId` an anonymous caller could create intents and refunds for
 *   somebody else's booking.
 * - `webhook` stays PUBLIC by design: the gateway cannot hold a user token.
 *   It is authenticated by its HMAC signature, verified in the service.
 *
 * The DTOs used to be undecorated classes declared here; with the global
 * `forbidNonWhitelisted` pipe that rejected every call as a 400. They now live
 * in `common/dto/payment.dto.ts` as the real contract.
 */
let PaymentsController = class PaymentsController {
    service;
    constructor(service) {
        this.service = service;
    }
    async create(dto, req) {
        return this.service.createPayment(dto, req.user.id);
    }
    async confirm(dto, req) {
        return this.service.confirmPayment(dto, req.user.id);
    }
    async refund(dto, req) {
        return this.service.refundPayment(dto, req.user.id);
    }
    /** Gateway callback — signature-authenticated, never JWT. */
    async webhook(dto) {
        return this.service.handleWebhook(dto);
    }
    async timeline(bookingId, req) {
        return { entries: this.service.bookingTimeline(bookingId, req.user.id) };
    }
};
exports.PaymentsController = PaymentsController;
__decorate([
    (0, common_1.Post)('intent'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [payment_dto_1.CreatePaymentDto, Object]),
    __metadata("design:returntype", Promise)
], PaymentsController.prototype, "create", null);
__decorate([
    (0, common_1.Post)('confirm'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [payment_dto_1.ConfirmPaymentDto, Object]),
    __metadata("design:returntype", Promise)
], PaymentsController.prototype, "confirm", null);
__decorate([
    (0, common_1.Post)('refund'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [payment_dto_1.RefundDto, Object]),
    __metadata("design:returntype", Promise)
], PaymentsController.prototype, "refund", null);
__decorate([
    (0, common_1.Post)('webhook'),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [payment_dto_1.WebhookDto]),
    __metadata("design:returntype", Promise)
], PaymentsController.prototype, "webhook", null);
__decorate([
    (0, common_1.Get)('ledger/:bookingId'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    __param(0, (0, common_1.Param)('bookingId')),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", Promise)
], PaymentsController.prototype, "timeline", null);
exports.PaymentsController = PaymentsController = __decorate([
    (0, common_1.Controller)('payments'),
    __metadata("design:paramtypes", [payment_service_1.PaymentService])
], PaymentsController);
//# sourceMappingURL=payments.controller.js.map