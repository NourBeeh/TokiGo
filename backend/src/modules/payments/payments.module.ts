import { Module } from '@nestjs/common';
import { PaymentsController } from './payments.controller';
import { PaymentService } from './payment.service';
import { PaymentRouter } from './payment.router';
import { MockEgyptGateway } from './mock.egypt.gateway';
import { LedgerService } from './ledger.service';

@Module({
  controllers: [PaymentsController],
  providers: [PaymentService, PaymentRouter, MockEgyptGateway, LedgerService],
  exports: [PaymentService, LedgerService],
})
export class PaymentsModule {}
