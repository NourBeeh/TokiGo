"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.BookingException = void 0;
const common_1 = require("@nestjs/common");
const STATUS_BY_CODE = {
    offer_not_found: common_1.HttpStatus.NOT_FOUND,
    booking_not_found: common_1.HttpStatus.NOT_FOUND,
    validation_failed: common_1.HttpStatus.UNPROCESSABLE_ENTITY,
    booking_expired: common_1.HttpStatus.CONFLICT,
    price_changed: common_1.HttpStatus.CONFLICT,
    no_availability: common_1.HttpStatus.CONFLICT,
    duplicate_request: common_1.HttpStatus.CONFLICT,
    unauthorized: common_1.HttpStatus.UNAUTHORIZED,
    capability_unsupported: common_1.HttpStatus.UNPROCESSABLE_ENTITY,
    provider_unavailable: common_1.HttpStatus.SERVICE_UNAVAILABLE,
    provider_error: common_1.HttpStatus.BAD_GATEWAY,
    unknown_error: common_1.HttpStatus.INTERNAL_SERVER_ERROR,
};
class BookingException extends common_1.HttpException {
    code;
    constructor(code, message, details) {
        super({ code, message, ...(details ? { details } : {}) }, STATUS_BY_CODE[code]);
        this.code = code;
    }
    static statusFor(code) {
        return STATUS_BY_CODE[code];
    }
}
exports.BookingException = BookingException;
//# sourceMappingURL=booking.exception.js.map