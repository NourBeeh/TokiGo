import { Module, OnModuleInit } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Provider } from '../../database/entities/provider.entity';
import { ProviderRegistryImpl } from '../../common/providers/provider.registry.impl';
import { ProviderInstances } from './provider.instances';
import { RegistrySyncService } from './registry.sync.service';
import { MockFlightProvider } from './adapters/mock.flight.provider';
import { MockHotelProvider } from './adapters/mock.hotel.provider';
import { MockCarProvider } from './adapters/mock.car.provider';
import { SearchController } from './search.controller';
import { SearchService } from './search.service';
import { DuffelService } from '../duffel/duffel.service';
import { DuffelHotelService } from '../duffel/duffel.hotel.service';
import { NuiteeService } from '../nuitee/nuitee.service';
import { NuiteeFlightService } from '../nuitee/nuitee.flight.service';
import { FxService } from '../../common/market/fx.service';
import { PricingService } from '../../common/market/pricing.service';

@Module({
  imports: [TypeOrmModule.forFeature([Provider])],
  controllers: [SearchController],
  providers: [
    ProviderRegistryImpl,
    ProviderInstances,
    RegistrySyncService,
    SearchService,
    MockFlightProvider,
    MockHotelProvider,
    MockCarProvider,
    DuffelService,
    DuffelHotelService,
    NuiteeService,
    NuiteeFlightService,
    FxService,
    PricingService,
  ],
  exports: [
    ProviderRegistryImpl,
    ProviderInstances,
    RegistrySyncService,
    SearchService,
    DuffelService,
    DuffelHotelService,
    NuiteeService,
    NuiteeFlightService,
    FxService,
    PricingService,
  ],
})
export class ProvidersModule implements OnModuleInit {
  constructor(
    private readonly registry: ProviderRegistryImpl,
    private readonly instances: ProviderInstances,
    private readonly sync: RegistrySyncService,
    private readonly mockFlightProvider: MockFlightProvider,
    private readonly duffelService: DuffelService,
    private readonly duffelHotelService: DuffelHotelService,
    private readonly mockHotelProvider: MockHotelProvider,
    private readonly mockCarProvider: MockCarProvider,
    private readonly nuiteeService: NuiteeService,
    private readonly nuiteeFlightService: NuiteeFlightService,
  ) {}

  async onModuleInit() {
    // Every constructed adapter is registered by its stable providerId — the
    // same key the `providers` table uses. Health checks must reach disabled
    // providers too, so registration is unconditional.
    this.instances.register('mock-flight', this.mockFlightProvider);
    this.instances.register('duffel-flight', this.duffelService);
    this.instances.register('nuitee-flight', this.nuiteeFlightService);
    this.instances.register('mock-hotel', this.mockHotelProvider);
    this.instances.register('nuitee', this.nuiteeService);
    this.instances.register('duffel-hotel', this.duffelHotelService);
    this.instances.register('mock-car', this.mockCarProvider);

    try {
      await this.sync.refresh();
      return;
    } catch (error) {
      // DB unavailable: keep the search endpoints working exactly as before
      // (ADM-B1 requirement — zero behaviour change when the DB is down). The
      // legacy ordering: Nuitee is now DEFAULT for both hotels AND flights
      // (owner decision 2026-10-22), Duffel is DISABLED temporarily.
      this.sync.applyLegacyOrdering({
        flight: [this.nuiteeFlightService],
        hotel: [this.nuiteeService],
        car: [this.mockCarProvider],
      });
    }
  }
}
