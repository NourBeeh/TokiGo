import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { PaymentsController } from './payments.controller';
import { PaymentService } from './payment.service';
import { PaymentRouter } from './payment.router';
import { MockEgyptGateway } from './mock.egypt.gateway';
import { LedgerService } from './ledger.service';
import { PaymentAttemptService } from './payment-attempt.service';
import { PaymentAttempt } from '../../database/entities/payment-attempt.entity';
import { PaymentTransaction } from '../../database/entities/payment-transaction.entity';
import { WebhookEvent } from '../../database/entities/webhook-event.entity';
import { ProcessedWebhook } from '../../database/entities/processed_webhook.entity';
import { Booking } from '../bookings/booking.entity';

/**
 * Customer-payment module (P4-2, corrected by P4-2R).
 *
 * Every durable artefact the orchestrator touches is registered here so
 * PostgreSQL — not a process-local map — is the source of truth:
 *   - `PaymentAttempt`     durable ownership / idempotency / state machine
 *   - `PaymentTransaction` the CUSTOMER / SUPPLIER ledger
 *   - `WebhookEvent`       the authoritative replay store for post-P4-2 events
 *   - `ProcessedWebhook`   the RETIRED legacy replay table, retained as an
 *                          archive and checked before any webhook effect
 *   - `Booking`            ownership + the authoritative price/currency
 */
@Module({
  imports: [
    TypeOrmModule.forFeature([
      PaymentAttempt,
      PaymentTransaction,
      WebhookEvent,
      ProcessedWebhook,
      Booking,
    ]),
  ],
  controllers: [PaymentsController],
  providers: [
    PaymentService,
    PaymentAttemptService,
    PaymentRouter,
    MockEgyptGateway,
    LedgerService,
  ],
  exports: [PaymentService, PaymentAttemptService, LedgerService],
})
export class PaymentsModule {}
