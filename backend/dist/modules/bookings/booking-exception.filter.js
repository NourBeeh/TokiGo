"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.BookingExceptionFilter = void 0;
const common_1 = require("@nestjs/common");
const booking_exception_1 = require("./booking.exception");
/**
 * Turns every booking-surface failure into a uniform `{code, message}` body
 * with a real HTTP status (Phase 4A). Applied at the controller scope only —
 * other controllers keep their existing behaviour.
 *
 * Nest's ValidationPipe emits a `BadRequestException` whose body is an array
 * of messages; that is normalised here into `code: 'validation_failed'`.
 */
let BookingExceptionFilter = class BookingExceptionFilter {
    catch(exception, host) {
        const response = host.switchToHttp().getResponse();
        let status = common_1.HttpStatus.INTERNAL_SERVER_ERROR;
        let code = 'unknown_error';
        let message = 'Unexpected booking error';
        let details;
        if (exception instanceof booking_exception_1.BookingException) {
            status = exception.getStatus();
            const body = exception.getResponse();
            code = body.code;
            message = body.message;
            details = body.details;
        }
        else if (exception instanceof common_1.HttpException) {
            status = exception.getStatus();
            const body = exception.getResponse();
            const bodyMessage = typeof body === 'string' ? body : body?.message;
            if (status === common_1.HttpStatus.BAD_REQUEST || status === common_1.HttpStatus.UNPROCESSABLE_ENTITY) {
                code = 'validation_failed';
                message = Array.isArray(bodyMessage)
                    ? bodyMessage.join(', ')
                    : bodyMessage ?? 'Validation failed';
            }
            else if (status === common_1.HttpStatus.UNAUTHORIZED || status === common_1.HttpStatus.FORBIDDEN) {
                code = 'unauthorized';
                message = 'Authentication required';
            }
            else if (status === common_1.HttpStatus.NOT_FOUND) {
                code = 'booking_not_found';
                message = Array.isArray(bodyMessage)
                    ? bodyMessage.join(', ')
                    : bodyMessage ?? 'Not found';
            }
            else {
                message = Array.isArray(bodyMessage)
                    ? bodyMessage.join(', ')
                    : bodyMessage ?? exception.message;
            }
        }
        else if (exception instanceof Error) {
            // Do not leak internal error messages to the client.
            // eslint-disable-next-line no-console
            console.error('[booking]', exception);
            message = 'Unexpected booking error';
        }
        response.status(status).json({ code, message, ...(details ? { details } : {}) });
    }
};
exports.BookingExceptionFilter = BookingExceptionFilter;
exports.BookingExceptionFilter = BookingExceptionFilter = __decorate([
    (0, common_1.Catch)()
], BookingExceptionFilter);
//# sourceMappingURL=booking-exception.filter.js.map