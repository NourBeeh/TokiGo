import { Injectable } from '@nestjs/common';
import { CarProvider } from '../../../common/providers/car.provider';
import { ProviderResult } from '../../../common/providers/provider.result';

/**
 * Car rental adapter — placeholder for a vendor that is not connected yet.
 *
 * OWNER DECISION (2026-10-19): **no fabricated inventory.** This adapter used
 * to answer every search with a hardcoded catalogue of six cars carrying
 * invented daily rates (21–95 USD), supplier names TokiGo has no relationship
 * with (Avis, Europcar, Hertz, Sixt), invented cancellation and mileage
 * policies, stock Unsplash photos and a made-up `originalPrice` (a fake 15%
 * discount on top of another invented number). All of it is gone.
 *
 * With no car vendor connected, the honest answer is "no cars" — never a
 * catalogue that looks bookable. The provider keeps its registry key
 * ('mock-car') and its CarProvider contract, so a real vendor adapter drops in
 * with zero domain/UI changes; the client already gates the car surface
 * (`_carRentalLive` in car_search_page.dart).
 */
@Injectable()
export class MockCarProvider implements CarProvider {
  providerId = 'mock-car';
  providerName = 'Car rental (not connected)';

  async searchCars(_params: {
    pickupLocation: string;
    pickupTime: Date;
    dropoffTime: Date;
  }): Promise<ProviderResult<any[]>> {
    return {
      success: false,
      providerId: this.providerId,
      providerName: this.providerName,
      error:
        'No car rental provider is connected yet — no vehicles or prices can be offered.',
      data: [],
      timestamp: new Date(),
    };
  }
}
