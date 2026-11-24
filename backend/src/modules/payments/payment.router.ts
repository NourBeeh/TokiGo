import { Injectable } from '@nestjs/common';
import { MockEgyptGateway } from './mock.egypt.gateway';
import { PaymentGateway } from './payment.gateway';
import { isProductionRuntime } from '../../common/runtime/runtime';

/**
 * Payment router (spec point 31/O.7): routes by paymentRegion, never by
 * provider name. Switching the Egypt gateway implementation does not touch
 * booking services.
 *
 * PRODUCTION FAIL-CLOSED (3C.1): the only registered gateway is the
 * deterministic mock. There is no verified real PSP adapter or merchant
 * account, so production refuses to start rather than expose a gateway that
 * treats a client-declared `CARD_SUCCESS` as money.
 */

@Injectable()
export class PaymentRouter {
  private readonly gateways: PaymentGateway[] = [];

  constructor(mockEgyptGateway: MockEgyptGateway) {
    if (isProductionRuntime()) {
      throw new Error(
        'No verified production payment gateway is configured. Refusing to ' +
          'start with the mock Egyptian gateway; a real PSP adapter and ' +
          'merchant credentials must be verified first.',
      );
    }
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
