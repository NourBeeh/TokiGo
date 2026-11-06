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
    /**
     * Cabin class requested by the traveller ('economy' | 'premium_economy' |
     * 'business' | 'first'). Forwardable providers honour it verbatim; it is
     * optional so providers without cabin support may ignore it.
     */
    cabinClass?: string;
    /**
     * Non-stop flights only. Duffel honours it via `max_connections: 0`;
     * providers without the notion ignore it.
     */
    directOnly?: boolean;
  }): Promise<ProviderResult<any[]>>;
}
