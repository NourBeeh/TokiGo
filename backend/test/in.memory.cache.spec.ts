import { InMemoryCacheProvider } from '../src/common/cache/in.memory.cache.provider';

/**
 * Cache invalidation is used to drop the Nearby Stays snapshot after an
 * inventory sync. The pattern must treat `*` as "any run of characters" at
 * every position and must not let a literal `.` behave as a regex wildcard.
 */
describe('InMemoryCacheProvider.invalidate', () => {
  it('removes every key under a prefix wildcard', async () => {
    const cache = new InMemoryCacheProvider();
    await cache.set('home:nearby-stays:v1:abc', 1);
    await cache.set('home:nearby-stays:v1:def', 2);
    await cache.set('home:other', 3);

    await cache.invalidate('home:nearby-stays:*');

    expect(await cache.get('home:nearby-stays:v1:abc')).toBeNull();
    expect(await cache.get('home:nearby-stays:v1:def')).toBeNull();
    expect(await cache.get('home:other')).toBe(3);
  });

  it('supports several wildcards and keeps dots literal', async () => {
    const cache = new InMemoryCacheProvider();
    await cache.set('a.b:1:x', 1);
    await cache.set('aXb:1:x', 2);
    await cache.set('a.b:2:x', 3);

    await cache.invalidate('a.b:*:x');

    expect(await cache.get('a.b:1:x')).toBeNull();
    expect(await cache.get('a.b:2:x')).toBeNull();
    // The `.` is literal, so a different character must not match.
    expect(await cache.get('aXb:1:x')).toBe(2);
  });

  it('expires an entry once its TTL has passed', async () => {
    const cache = new InMemoryCacheProvider();
    await cache.set('k', 'v', 1);
    expect(await cache.get('k')).toBe('v');
    await new Promise((resolve) => setTimeout(resolve, 1100));
    expect(await cache.get('k')).toBeNull();
  });
});
