import { MockCarProvider } from '../src/modules/providers/adapters/mock.car.provider';

/**
 * Car rental adapter contract.
 *
 * OWNER DECISION (2026-10-19): this adapter no longer fabricates a catalogue —
 * the old spec pinned six invented cars with invented daily rates and real
 * supplier names the app has no relationship with. What is pinned now is the
 * honest behaviour: the shared CarProvider interface is honoured, the stable
 * registry key survives (so a real vendor adapter drops in with zero domain/UI
 * changes), and with no vendor connected the answer is an explicit failure
 * carrying ZERO vehicles and ZERO prices.
 */

describe('MockCarProvider (CarProvider contract)', () => {
  const provider = new MockCarProvider();

  const window = {
    pickupTime: new Date('2026-10-01T10:00:00Z'),
    dropoffTime: new Date('2026-10-05T10:00:00Z'), // 4 days
  };

  it('implements the shared CarProvider contract', () => {
    expect(provider.providerId).toBe('mock-car');
    expect(typeof provider.searchCars).toBe('function');
  });

  it('returns no invented vehicles and no invented prices', async () => {
    const result = await provider.searchCars({
      pickupLocation: 'Cairo',
      ...window,
    });

    expect(result.success).toBe(false);
    expect(result.data ?? []).toEqual([]);
    expect(result.error).toBeTruthy();
    expect(result.providerId).toBe('mock-car');
  });

  it('answers the same way for every city, window and language', async () => {
    const results = await Promise.all([
      provider.searchCars({ pickupLocation: 'القاهرة', ...window }),
      provider.searchCars({ pickupLocation: 'Dubai', ...window }),
      provider.searchCars({
        pickupLocation: 'Cairo',
        pickupTime: window.pickupTime,
        dropoffTime: window.pickupTime, // same-day
      }),
    ]);

    for (const result of results) {
      expect(result.success).toBe(false);
      expect(result.data ?? []).toEqual([]);
      expect(result.error).toBeTruthy();
    }
  });
});
