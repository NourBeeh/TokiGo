import { ProviderResult } from './provider.result';

export interface FlightProvider {
  providerId: string;
  providerName: string;
  searchFlights(params: {
    origin: string;
    destination: string;
    departure: Date;
    returnDate?: Date;
    passengers?: number;
  }): Promise<ProviderResult<any[]>>;
}
