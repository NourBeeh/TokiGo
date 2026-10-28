import { ProviderRegistryImpl } from '../src/common/providers/provider.registry.impl';

describe('ProviderRegistry', () => {
  it('should register and retrieve flight providers', () => {
    const registry = new ProviderRegistryImpl();
    const mockProvider = { name: 'Mock' };
    registry.registerFlight(mockProvider);
    expect(registry.getFlightProviders().length).toBe(1);
  });
});
