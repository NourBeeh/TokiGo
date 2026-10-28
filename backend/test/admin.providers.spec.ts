import { ProviderRegistryImpl } from '../src/common/providers/provider.registry.impl';
import { ProviderInstances } from '../src/modules/providers/provider.instances';
import { RegistrySyncService } from '../src/modules/providers/registry.sync.service';
import { AdminService } from '../src/modules/admin/admin.service';

/* Reuse of the same minimal TypeORM double style as admin.home.spec.ts. */
function fakeRepo(initial: any[] = []) {
  const rows: any[] = [...initial];
  const matches = (row: any, where: any) =>
    Object.keys(where).every((key) => row[key] === where[key]);
  return {
    rows,
    async find(opts?: any) {
      let out = rows.filter((r) => matches(r, opts?.where ?? {}));
      const order = opts?.order ?? {};
      for (const key of Object.keys(order).reverse()) {
        const dir = order[key];
        out = [...out].sort((a, b) =>
          dir === 'DESC' ? (b[key] > a[key] ? 1 : -1) : a[key] > b[key] ? 1 : -1,
        );
      }
      const take = opts?.take;
      return take === undefined ? out : out.slice(0, take);
    },
    async findOne(opts?: any) {
      return rows.find((r) => matches(r, opts?.where ?? {})) ?? null;
    },
    create(value: any) {
      return { ...value };
    },
    async save(value: any) {
      const index = rows.findIndex((r) => r.id === value.id);
      if (index >= 0) {
        rows[index] = { ...rows[index], ...value };
        return rows[index];
      }
      const created = { id: value.id ?? `gen-${rows.length + 1}`, ...value };
      rows.push(created);
      return created;
    },
    async update(where: any, patch: any) {
      rows.filter((r) => matches(r, where)).forEach((r) => Object.assign(r, patch));
    },
    async delete(where: any) {
      for (let i = rows.length - 1; i >= 0; i--) {
        if (matches(rows[i], where)) rows.splice(i, 1);
      }
    },
  } as any;
}

function makeProviderRow(key: string, vertical: string, priority: number, isActive = true) {
  return {
    id: `row-${key}`,
    providerKey: key,
    name: key,
    vertical,
    priority,
    isActive,
    config: {},
    healthStatus: 'unknown',
  };
}

function makeStub(id: string, ok = true) {
  return {
    providerId: id,
    async searchFlights() {
      if (!ok) throw new Error('boom');
      return { success: true, data: [] };
    },
    async searchHotels() {
      if (!ok) throw new Error('boom');
      return { success: true, data: [] };
    },
    async searchCars() {
      if (!ok) throw new Error('boom');
      return { success: true, data: [] };
    },
  };
}

function makeSync(providersRepo: any) {
  const registry = new ProviderRegistryImpl();
  const instances = new ProviderInstances();
  const sync = new RegistrySyncService(providersRepo, registry, instances);
  return { registry, instances, sync };
}

describe('RegistrySyncService — DB-driven registry', () => {
  it('seeds only missing default providers (idempotent)', async () => {
    const repo = fakeRepo([makeProviderRow('nuitee', 'hotel', 1)]);
    const { sync } = makeSync(repo);
    await sync.seedDefaults();
    const keys = repo.rows.map((r) => r.providerKey).sort();
    expect(keys).toContain('nuitee');
    expect(keys).toContain('duffel-flight');
    expect(keys).toContain('mock-car');
    // The pre-existing row was untouched (no duplicate).
    expect(repo.rows.filter((r) => r.providerKey === 'nuitee')).toHaveLength(1);
  });

  it('registers only active providers, ordered by priority', async () => {
    const repo = fakeRepo([
      makeProviderRow('nuitee', 'hotel', 2),
      makeProviderRow('duffel-hotel', 'hotel', 1),
      makeProviderRow('mock-hotel', 'hotel', 3, false), // disabled
    ]);
    const { registry, instances, sync } = makeSync(repo);
    instances.register('nuitee', makeStub('nuitee'));
    instances.register('duffel-hotel', makeStub('duffel-hotel'));
    instances.register('mock-hotel', makeStub('mock-hotel'));
    await sync.syncFromDatabase();

    const registered = registry.getHotelProviders().map((p) => p.providerId);
    expect(registered).toEqual(['duffel-hotel', 'nuitee']);
    expect(registry.getFlightProviders()).toEqual([]);
    expect(registry.getCarProviders()).toEqual([]);
  });

  it('re-syncing reflects admin toggles at runtime', async () => {
    const repo = fakeRepo([
      makeProviderRow('nuitee', 'hotel', 1),
      makeProviderRow('duffel-hotel', 'hotel', 2),
    ]);
    const { registry, instances, sync } = makeSync(repo);
    const nuitee = makeStub('nuitee');
    const duffel = makeStub('duffel-hotel');
    instances.register('nuitee', nuitee);
    instances.register('duffel-hotel', duffel);

    await sync.syncFromDatabase();
    expect(registry.getHotelProviders().map((p) => p.providerId)).toEqual([
      'nuitee',
      'duffel-hotel',
    ]);

    // Admin disables Nuitee -> registry rebuilds without it.
    repo.rows.find((r) => r.providerKey === 'nuitee').isActive = false;
    await sync.syncFromDatabase();
    expect(registry.getHotelProviders().map((p) => p.providerId)).toEqual([
      'duffel-hotel',
    ]);
  });

  it('falls back to legacy ordering when the database is unavailable', () => {
    const { registry, sync } = makeSync(fakeRepo());
    const legacyFlight = [makeStub('mock-flight')];
    sync.applyLegacyOrdering({ flight: legacyFlight, hotel: [], car: [] });
    expect(registry.getFlightProviders().map((p) => p.providerId)).toEqual([
      'mock-flight',
    ]);
  });
});

describe('AdminService — provider management', () => {
  function makeAdmin(providersRepo: any) {
    const registry = new ProviderRegistryImpl();
    const instances = new ProviderInstances();
    const sync = new RegistrySyncService(providersRepo, registry, instances);
    const service = new AdminService(
      fakeRepo(),
      fakeRepo(),
      fakeRepo(),
      providersRepo,
      instances,
      sync,
      registry,
    );
    return { service, registry, instances };
  }

  it('disabling a provider removes it from the registry immediately', async () => {
    const repo = fakeRepo([makeProviderRow('nuitee', 'hotel', 1)]);
    const { service, registry, instances } = makeAdmin(repo);
    instances.register('nuitee', makeStub('nuitee'));
    await service.refreshRegistry();
    expect(registry.getHotelProviders()).toHaveLength(1);

    await service.setProviderStatus('nuitee', false);
    expect(registry.getHotelProviders()).toHaveLength(0);
    expect(repo.rows[0].isActive).toBe(false);
  });

  it('re-prioritising providers reorders the registry', async () => {
    const repo = fakeRepo([
      makeProviderRow('nuitee', 'hotel', 1),
      makeProviderRow('duffel-hotel', 'hotel', 2),
    ]);
    const { service, registry, instances } = makeAdmin(repo);
    instances.register('nuitee', makeStub('nuitee'));
    instances.register('duffel-hotel', makeStub('duffel-hotel'));
    await service.refreshRegistry();
    expect(registry.getHotelProviders()[0].providerId).toBe('nuitee');

    await service.setProviderPriority('duffel-hotel', 0);
    expect(registry.getHotelProviders()[0].providerId).toBe('duffel-hotel');
  });

  it('health check persists status and latency for a healthy provider', async () => {
    const repo = fakeRepo([makeProviderRow('nuitee', 'hotel', 1)]);
    const { service, instances } = makeAdmin(repo);
    instances.register('nuitee', makeStub('nuitee'));

    const row = await service.runHealthCheck('nuitee');
    expect(row.healthStatus).toBe('healthy');
    expect(typeof row.latencyMs).toBe('number');
    expect(row.lastCheckedAt).toBeInstanceOf(Date);
  });

  it('health check flags a failing provider as unhealthy', async () => {
    const repo = fakeRepo([makeProviderRow('mock-car', 'car', 1)]);
    const { service, instances } = makeAdmin(repo);
    instances.register('mock-car', makeStub('mock-car', false));

    const row = await service.runHealthCheck('mock-car');
    expect(row.healthStatus).toBe('unhealthy');
  });

  it('merges provider config patches', async () => {
    const repo = fakeRepo([makeProviderRow('nuitee', 'hotel', 1)]);
    const { service } = makeAdmin(repo);
    await service.setProviderConfig('nuitee', { timeoutMs: 5000 });
    await service.setProviderConfig('nuitee', { retries: 2 });
    expect(repo.rows[0].config).toEqual({ timeoutMs: 5000, retries: 2 });
  });
});
