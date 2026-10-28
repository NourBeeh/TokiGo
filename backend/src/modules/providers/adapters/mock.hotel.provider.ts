import { HotelProvider } from '../../../common/providers/hotel.provider';
import { ProviderResult } from '../../../common/providers/provider.result';

export class MockHotelProvider implements HotelProvider {
  providerId = 'mock-hotel';
  providerName = 'Mock Hotel Provider';

  async searchHotels(params: any): Promise<ProviderResult<any[]>> {
    return {
      success: true,
      providerId: this.providerId,
      providerName: this.providerName,
      data: [],
      timestamp: new Date(),
    };
  }
}
