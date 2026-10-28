import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { Response } from 'express';
import { BookingException } from './booking.exception';

/**
 * Turns every booking-surface failure into a uniform `{code, message}` body
 * with a real HTTP status (Phase 4A). Applied at the controller scope only —
 * other controllers keep their existing behaviour.
 *
 * Nest's ValidationPipe emits a `BadRequestException` whose body is an array
 * of messages; that is normalised here into `code: 'validation_failed'`.
 */
@Catch()
export class BookingExceptionFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost): void {
    const response = host.switchToHttp().getResponse<Response>();

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let code = 'unknown_error';
    let message = 'Unexpected booking error';
    let details: Record<string, any> | undefined;

    if (exception instanceof BookingException) {
      status = exception.getStatus();
      const body = exception.getResponse() as {
        code: string;
        message: string;
        details?: Record<string, any>;
      };
      code = body.code;
      message = body.message;
      details = body.details;
    } else if (exception instanceof HttpException) {
      status = exception.getStatus();
      const body = exception.getResponse();
      const bodyMessage =
        typeof body === 'string' ? body : (body as any)?.message;

      if (status === HttpStatus.BAD_REQUEST || status === HttpStatus.UNPROCESSABLE_ENTITY) {
        code = 'validation_failed';
        message = Array.isArray(bodyMessage)
          ? bodyMessage.join(', ')
          : bodyMessage ?? 'Validation failed';
      } else if (status === HttpStatus.UNAUTHORIZED || status === HttpStatus.FORBIDDEN) {
        code = 'unauthorized';
        message = 'Authentication required';
      } else if (status === HttpStatus.NOT_FOUND) {
        code = 'booking_not_found';
        message = Array.isArray(bodyMessage)
          ? bodyMessage.join(', ')
          : bodyMessage ?? 'Not found';
      } else {
        message = Array.isArray(bodyMessage)
          ? bodyMessage.join(', ')
          : bodyMessage ?? exception.message;
      }
    } else if (exception instanceof Error) {
      // Do not leak internal error messages to the client.
      // eslint-disable-next-line no-console
      console.error('[booking]', exception);
      message = 'Unexpected booking error';
    }

    response.status(status).json({ code, message, ...(details ? { details } : {}) });
  }
}
