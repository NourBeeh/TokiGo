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
exports.BookingsController = void 0;
const common_1 = require("@nestjs/common");
const jwt_auth_guard_1 = require("../auth/jwt-auth.guard");
const booking_exception_filter_1 = require("./booking-exception.filter");
const bookings_service_1 = require("./bookings.service");
const booking_dto_1 = require("../../common/dto/booking.dto");
/**
 * Booking foundation API (Phase 4A).
 *
 * SECURITY MODEL: every route is JWT-guarded and derives the caller identity
 * from the token ([userId] below) — a request can never read or mutate another
 * user's booking. No route accepts a price or a userId from the body.
 *
 * Errors are normalised to `{code, message}` by [BookingExceptionFilter].
 */
let BookingsController = class BookingsController {
    bookings;
    constructor(bookings) {
        this.bookings = bookings;
    }
    /** Prepare: capability-check + provider revalidation → authoritative price. */
    async prepare(req, dto) {
        return this.bookings.prepare(userId(req), dto);
    }
    /** Revalidate a prepared booking against the live provider offer. */
    async revalidate(req, dto) {
        return this.bookings.revalidate(userId(req), dto.bookingId);
    }
    /** Confirm (create) a booking — idempotent on the supplied key. */
    async create(req, dto) {
        return this.bookings.create(userId(req), dto);
    }
    async get(req, id) {
        return this.bookings.get(userId(req), id);
    }
    async status(req, id) {
        return this.bookings.getStatus(userId(req), id);
    }
    /** Capability-gated cancellation (unsupported providers → structured error). */
    async cancel(req, id) {
        return this.bookings.cancel(userId(req), id);
    }
};
exports.BookingsController = BookingsController;
__decorate([
    (0, common_1.Post)('prepare'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, booking_dto_1.PrepareBookingDto]),
    __metadata("design:returntype", Promise)
], BookingsController.prototype, "prepare", null);
__decorate([
    (0, common_1.Post)('revalidate'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, booking_dto_1.RevalidateBookingDto]),
    __metadata("design:returntype", Promise)
], BookingsController.prototype, "revalidate", null);
__decorate([
    (0, common_1.Post)(),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, booking_dto_1.CreateBookingDto]),
    __metadata("design:returntype", Promise)
], BookingsController.prototype, "create", null);
__decorate([
    (0, common_1.Get)(':id'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", Promise)
], BookingsController.prototype, "get", null);
__decorate([
    (0, common_1.Get)(':id/status'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", Promise)
], BookingsController.prototype, "status", null);
__decorate([
    (0, common_1.Post)(':id/cancel'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", Promise)
], BookingsController.prototype, "cancel", null);
exports.BookingsController = BookingsController = __decorate([
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, common_1.UseFilters)(booking_exception_filter_1.BookingExceptionFilter),
    (0, common_1.Controller)('bookings'),
    __metadata("design:paramtypes", [bookings_service_1.BookingsService])
], BookingsController);
/** Passport attaches the JWT-validated user entity to the request. */
function userId(req) {
    return req.user.id;
}
//# sourceMappingURL=bookings.controller.js.map