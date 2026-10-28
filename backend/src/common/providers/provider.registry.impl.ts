import { Injectable } from '@nestjs/common';

@Injectable()
export class ProviderRegistryImpl {
  private flightProviders: any[] = [];
  private hotelProviders: any[] = [];
  private carProviders: any[] = [];

  registerFlight(provider: any) {
    this.flightProviders.push(provider);
  }

  registerHotel(provider: any) {
    this.hotelProviders.push(provider);
  }

  registerCar(provider: any) {
    this.carProviders.push(provider);
  }

  /** Atomically replace a vertical's provider list (admin runtime switching). */
  setFlightProviders(providers: any[]) {
    this.flightProviders = [...providers];
  }

  setHotelProviders(providers: any[]) {
    this.hotelProviders = [...providers];
  }

  setCarProviders(providers: any[]) {
    this.carProviders = [...providers];
  }

  getFlightProviders() {
    return this.flightProviders;
  }

  getHotelProviders() {
    return this.hotelProviders;
  }

  getCarProviders() {
    return this.carProviders;
  }

  findFlightProvider(id: string) {
    return this.flightProviders.find(p => p.providerId === id);
  }

  findHotelProvider(id: string) {
    return this.hotelProviders.find(p => p.providerId === id);
  }

  findCarProvider(id: string) {
    return this.carProviders.find(p => p.providerId === id);
  }

  /** Finds a registered provider instance by its providerId across verticals. */
  getProviderByKey(key: string): any | null {
    return (
      [...this.flightProviders, ...this.hotelProviders, ...this.carProviders]
        .find(p => p.providerId === key) ?? null
    );
  }
}
