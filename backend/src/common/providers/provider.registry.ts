export interface ProviderRegistry {
  registerFlight(provider: any): void;
  registerHotel(provider: any): void;
  registerCar(provider: any): void;
  getFlightProviders(): any[];
  getHotelProviders(): any[];
  getCarProviders(): any[];
}
