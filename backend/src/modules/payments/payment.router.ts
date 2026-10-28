import { Injectable } from '@nestjs/common';
import { MockEgyptGateway } from './mock.egypt.gateway';
import { PaymentGateway } from './payment.gateway';

/**
 * Payment router (spec point 31/O.7): routes by paymentRegion, never by
 * provider name. Switching the Egypt gateway implementation does not touch
 * booking services.
 */

@Injectable()
export class PaymentRouter {
  private readonly gateways: PaymentGateway[] = [];

  constructor(mockEgyptGateway: MockEgyptGateway) {
    this.gateways = [mockEgyptGateway];
  }

  /** Returns the active gateway for a market or null when checkout must stay disabled. */
  forMarket(paymentRegion: string): PaymentGateway | null {
    return this.gateways.find(g => g.supportsMarket.includes(paymentRegion)) ?? null;
  }

  listGateways(): { gatewayId: string; markets: string[] }[] {
    return this.gateways.map(g => ({
      gatewayId: g.gatewayId,
      markets: [...g.supportsMarket],
    }));
  }
}
