import { ProviderResult } from './provider.result';

export interface CarProvider {
  providerId: string;
  providerName: string;
  searchCars(params: {
    pickupLocation: string;
    pickupTime: Date;
    dropoffTime: Date;
  }): Promise<ProviderResult<any[]>>;
}
