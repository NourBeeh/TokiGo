import { ProviderResult } from './provider.result';

export interface HotelProvider {
  providerId: string;
  providerName: string;
  searchHotels(params: {
    city: string;
    checkIn: Date;
    checkOut: Date;
    guests?: number;
  }): Promise<ProviderResult<any[]>>;
}
