import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { PaymentsController } from './payments.controller';
import { PaymentService } from './payment.service';
import { PaymentRouter } from './payment.router';
import { MockEgyptGateway } from './mock.egypt.gateway';
import { LedgerService } from './ledger.service';
import { ProcessedWebhook } from '../../database/entities/processed_webhook.entity';

@Module({
  imports: [TypeOrmModule.forFeature([ProcessedWebhook])],
  controllers: [PaymentsController],
  providers: [PaymentService, PaymentRouter, MockEgyptGateway, LedgerService],
  exports: [PaymentService, LedgerService],
})
export class PaymentsModule {}
