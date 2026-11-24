import { Controller, Post, Body, Get, Param, UseGuards, Req } from '@nestjs/common';
import { Request } from 'express';
import { PaymentService } from './payment.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import {
  ConfirmPaymentDto,
  CreatePaymentDto,
  RefundDto,
  WebhookDto,
} from '../../common/dto/payment.dto';

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
@Controller('payments')
export class PaymentsController {
  constructor(private readonly service: PaymentService) {}

  @Post('intent')
  @UseGuards(JwtAuthGuard)
  async create(@Body() dto: CreatePaymentDto, @Req() req: Request) {
    return this.service.createPayment(dto, (req.user as { id: string }).id);
  }

  @Post('confirm')
  @UseGuards(JwtAuthGuard)
  async confirm(@Body() dto: ConfirmPaymentDto, @Req() req: Request) {
    return this.service.confirmPayment(dto, (req.user as { id: string }).id);
  }

  /**
   * Refunds are an ADMIN action. The JWT identifies the operator; the role
   * guard and the service both require `role === 'admin'`. A customer can
   * never refund their own payment through this route.
   */
  @Post('refund')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('admin')
  async refund(@Body() dto: RefundDto, @Req() req: Request) {
    const user = req.user as { id: string; role?: string };
    return this.service.refundPayment(dto, user.id, user.role);
  }

  /** Gateway callback — signature-authenticated, never JWT. */
  @Post('webhook')
  async webhook(@Body() dto: WebhookDto) {
    return this.service.handleWebhook(dto);
  }

  @Get('ledger/:bookingId')
  @UseGuards(JwtAuthGuard)
  async timeline(@Param('bookingId') bookingId: string, @Req() req: Request) {
    return {
      entries: await this.service.bookingTimeline(
        bookingId,
        (req.user as { id: string }).id,
      ),
    };
  }

  /**
   * Balanced CUSTOMER trail for a booking: captured minus refunded. Derived
   * from the same durable rows as the ledger, so the two can never disagree.
   */
  @Get('ledger/:bookingId/balance')
  @UseGuards(JwtAuthGuard)
  async balance(@Param('bookingId') bookingId: string, @Req() req: Request) {
    return this.service.bookingBalance(
      bookingId,
      (req.user as { id: string }).id,
    );
  }
}
