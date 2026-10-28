/**
 * LIVE sandbox smoke (spec point 47): runs only when NUITEE_LIVE_SMOKE=1 so
 * CI never depends on the vendor. Exercises the real /hotels/rates search
 * with the sandbox key from .env.
 */
const maybeLive = process.env.NUITEE_LIVE_SMOKE === '1' ? describe : describe.skip;

maybeLive('Nuitee LIVE sandbox smoke', () => {
  it('searchHotels returns real mapped offers for Cairo', async () => {
    const fs = require('fs');
    const path = require('path');
    for (const line of fs.readFileSync(path.join(__dirname, '..', '.env'), 'utf8').split('\n')) {
      const m = line.match(/^([A-Z_]+)=(.*)$/);
      if (m) process.env[m[1]] = m[2];
    }
    const { NuiteeService } = await import('../src/modules/nuitee/nuitee.service');
    const config = { get: (n: string) => process.env[n] };
    const service = new NuiteeService(config as any);

    const result = await service.searchHotels({
      city: 'Cairo',
      checkIn: new Date('2026-10-01'),
      checkOut: new Date('2026-10-03'),
      guests: 2,
      rooms: 1,
    });

    expect(result.success).toBe(true);
    expect(result.data.length).toBeGreaterThan(0);
    const first = result.data[0];
    expect(first.providerId).toBe('nuitee');
    expect(first.type).toBe('hotel');
    expect(first.price).toBeGreaterThan(0);
    expect(first.title).toBeTruthy();
    console.log('LIVE first offer:', first.title, first.price, first.currency, 'rating:', first.rating);
  }, 30_000);
});
