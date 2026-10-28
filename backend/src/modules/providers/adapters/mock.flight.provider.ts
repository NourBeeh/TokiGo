import { FlightProvider } from '../../../common/providers/flight.provider';
import { ProviderResult } from '../../../common/providers/provider.result';

export class MockFlightProvider implements FlightProvider {
  providerId = 'mock-flight';
  providerName = 'Mock Flight Provider';

  async searchFlights(params: any): Promise<ProviderResult<any[]>> {
    return {
      success: true,
      providerId: this.providerId,
      providerName: this.providerName,
      data: [],
      timestamp: new Date(),
    };
  }
}
