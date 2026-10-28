import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Provider } from '../../database/entities/provider.entity';
import { ProviderRegistryImpl } from '../../common/providers/provider.registry.impl';
import { ProviderInstances } from './provider.instances';

export type ProviderVertical = 'flight' | 'hotel' | 'car';

/**
 * Keeps the in-memory ProviderRegistryImpl in sync with the persisted
 * `providers` table. The table is the single source of truth for which
 * provider serves each vertical and in which order (admin workstream ADM-B1).
 */
@Injectable()
export class RegistrySyncService {
  private readonly logger = new Logger(RegistrySyncService.name);

  constructor(
    @InjectRepository(Provider)
    private readonly providers: Repository<Provider>,
    private readonly registry: ProviderRegistryImpl,
    private readonly instances: ProviderInstances,
  ) {}

  /** Known adapters: key must equal the instance `providerId`. */
  static readonly DEFAULTS: Array<{
    key: string;
    name: string;
    vertical: ProviderVertical;
    priority: number;
    isFallback: boolean;
    /**
     * Fresh installs only. A provider that serves a curated/fake catalogue
     * must never be switched on by default: its results would read as live
     * inventory in the app (3B decision — hotels are Nuitee-only).
     */
    isActive?: boolean;
  }> = [
    { key: 'duffel-flight', name: 'Duffel Flights', vertical: 'flight', priority: 1, isFallback: false },
    { key: 'nuitee-flight', name: 'Nuitee Flights', vertical: 'flight', priority: 2, isFallback: true },
    { key: 'mock-flight', name: 'Mock Flights', vertical: 'flight', priority: 3, isFallback: true },
    { key: 'nuitee', name: 'Nuitee Hotels', vertical: 'hotel', priority: 1, isFallback: false },
    // Duffel Stays is not live on this account: the adapter falls back to a
    // curated fake catalogue, so it must stay OFF. An honest empty answer is
    // the only truthful result when Nuitee has no stay.
    { key: 'duffel-hotel', name: 'Duffel Hotels', vertical: 'hotel', priority: 2, isFallback: true, isActive: false },
    { key: 'mock-hotel', name: 'Mock Hotels', vertical: 'hotel', priority: 3, isFallback: true, isActive: false },
    { key: 'mock-car', name: 'Mock Cars', vertical: 'car', priority: 1, isFallback: false },
  ];

  /** Inserts missing default rows; never touches user-edited existing rows. */
  async seedDefaults(): Promise<void> {
    for (const def of RegistrySyncService.DEFAULTS) {
      const existing = await this.providers.findOne({
        where: { providerKey: def.key },
      });
      if (existing) continue;
      await this.providers.save(
        this.providers.create({
          providerKey: def.key,
          name: def.name,
          vertical: def.vertical,
          priority: def.priority,
          isFallback: def.isFallback,
          isActive: def.isActive ?? true,
          config: {},
          healthStatus: 'unknown',
        }),
      );
    }
  }

  /** Rebuilds registry lists from active DB rows, ordered by priority. */
  async syncFromDatabase(): Promise<void> {
    const rows = await this.providers.find({
      where: { isActive: true },
      order: { priority: 'ASC' },
    });
    const byVertical: Record<string, any[]> = {
      flight: [],
      hotel: [],
      car: [],
    };
    for (const row of rows) {
      const instance = this.instances.get(row.providerKey);
      if (!instance) continue;
      const vertical = row.vertical ?? '';
      if (!(vertical in byVertical)) continue;
      byVertical[vertical].push(instance);
    }
    this.registry.setFlightProviders(byVertical.flight);
    this.registry.setHotelProviders(byVertical.hotel);
    this.registry.setCarProviders(byVertical.car);
  }

  /** Seeds + rebuilds in one call; used at boot and after admin mutations. */
  async refresh(): Promise<void> {
    await this.seedDefaults();
    await this.syncFromDatabase();
  }

  /** Fallback used when the DB is unreachable: legacy hardcoded ordering. */
  applyLegacyOrdering(legacy: {
    flight: any[];
    hotel: any[];
    car: any[];
  }): void {
    this.registry.setFlightProviders(legacy.flight);
    this.registry.setHotelProviders(legacy.hotel);
    this.registry.setCarProviders(legacy.car);
    this.logger.warn(
      'Provider registry fell back to legacy hardcoded ordering (database unavailable or empty).',
    );
  }
}
