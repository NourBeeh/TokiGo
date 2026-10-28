import { InMemoryCacheProvider } from '../src/common/cache/in.memory.cache.provider';

describe('InMemoryCacheProvider TTL', () => {
  it('should expire after TTL', async () => {
    const cache = new InMemoryCacheProvider();
    await cache.set('key', 'value', 1);
    const v1 = await cache.get('key');
    expect(v1).toBe('value');
    await new Promise(r => setTimeout(r, 1100));
    const v2 = await cache.get('key');
    expect(v2).toBeNull();
  });
});
