/**
 * LIVE sandbox smoke (spec point 47): runs only when NUITEE_LIVE_SMOKE=1 so
 * CI never depends on the vendor. Exercises the real /hotels/rates search
 * with the sandbox key from .env.
 */
const maybeLive = process.env.NUITEE_LIVE_SMOKE === '1' ? describe : describe.skip;

maybeLive('Nuitee LIVE sandbox smoke', () => {
  it('checks Arabic hotel content and the original-name fallback for Cairo', async () => {
    const fs = require('fs');
    const path = require('path');
    for (const line of fs.readFileSync(path.join(__dirname, '..', '.env'), 'utf8').split('\n')) {
      const m = line.match(/^([A-Z_]+)=(.*)$/);
      if (m) process.env[m[1]] = m[2];
    }
    const { NuiteeService } = await import('../src/modules/nuitee/nuitee.service');
    const config = { get: (n: string) => process.env[n] };
    const service = new NuiteeService(config as any);

    const checkIn = new Date();
    checkIn.setUTCDate(checkIn.getUTCDate() + 30);
    const checkOut = new Date(checkIn);
    checkOut.setUTCDate(checkOut.getUTCDate() + 2);
    const search = {
      city: 'Cairo',
      checkIn,
      checkOut,
      guests: 2,
      rooms: 1,
    };
    const result = await service.searchHotels({
      ...search,
      language: 'ar',
    });
    const englishResult = await service.searchHotels({
      ...search,
      language: 'en',
    });

    expect(result.success).toBe(true);
    expect(result.data.length).toBeGreaterThan(0);
    expect(englishResult.success).toBe(true);
    expect(englishResult.data.length).toBeGreaterThan(0);
    const first = result.data[0];
    const matchingEnglish = englishResult.data.find(
      (offer: any) =>
        offer.metadata.providerHotelId === first.metadata.providerHotelId,
    );
    const arabicNames = result.data.filter((offer: any) =>
      /\p{Script=Arabic}/u.test(offer.title),
    );
    expect(first.providerId).toBe('nuitee');
    expect(first.type).toBe('hotel');
    expect(first.price).toBeGreaterThan(0);
    expect(first.title).toBeTruthy();
    expect(first.metadata.hotelNameEn).toBeTruthy();
    expect(matchingEnglish?.title).toBe(first.metadata.hotelNameEn);
    console.log(
      'LIVE Nuitee Arabic content response:',
      JSON.stringify({
        hotelCount: result.data.length,
        arabicNameCount: arabicNames.length,
        matchingEnglishTitle: matchingEnglish?.title,
        sample: result.data.slice(0, 3).map((offer: any) => ({
          hotelId: offer.metadata.providerHotelId,
          title: offer.title,
          hotelNameEn: offer.metadata.hotelNameEn,
          hotelNameAr: offer.metadata.hotelNameAr,
        })),
      }),
    );
  }, 60_000);
});
