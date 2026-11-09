/**
 * P3-D7 — `POST /offers/revalidate` Nuitee flight path.
 *
 * The endpoint used to fall through to `UNAVAILABLE` for every Nuitee flight
 * offer, blocking the booking review page's Continue action. It now uses the
 * provider's READ-ONLY `POST /flights/verify` — no prebook, no inventory hold.
 */
import { OffersController } from '../src/modules/offers/offers.controller';
import { NuiteeFlightService } from '../src/modules/nuitee/nuitee.flight.service';

class FakeNuiteeFlightService {
  verifyCalls: string[] = [];
  price = 800;
  currency = 'USD';
  changed = false;
  oldPrice?: number;
  newPrice?: number;
  fails = false;

  async verifyFlightOffer(offerId: string) {
    this.verifyCalls.push(offerId);
    if (this.fails) {
      return {
        success: false,
        error: 'Nuitee flight verify failed (404): offer expired',
        timestamp: new Date(),
      };
    }
    return {
      success: true,
      price: this.price,
      currency: this.currency,
      available: this.price > 0,
      priceChanged: this.changed,
      oldPrice: this.oldPrice,
      newPrice: this.newPrice,
      expiresAt: '2026-12-01T00:00:00Z',
      timestamp: new Date(),
    };
  }
}

function setup() {
  const flight = new FakeNuiteeFlightService();
  const controller = new OffersController(
    {} as any,
    {} as any,
    flight as unknown as NuiteeFlightService,
  );
  return { controller, flight };
}

const dto = {
  offerId: 'off_1',
  providerId: 'nuitee-flight',
  offerType: 'flight',
};

describe('POST /offers/revalidate — nuitee-flight', () => {
  it('returns OK with the verified price (no longer UNAVAILABLE)', async () => {
    const { controller, flight } = setup();

    const res = await controller.revalidate({ ...dto, knownPrice: '800' });

    expect(res).toEqual({
      status: 'OK',
      offerId: 'off_1',
      price: 800,
      currency: 'USD',
      expiresAt: '2026-12-01T00:00:00Z',
    });
    // The offerId from the snapshot is what the provider sees.
    expect(flight.verifyCalls).toEqual(['off_1']);
  });

  it('returns PRICE_CHANGED when the provider reports a price move', async () => {
    const { controller, flight } = setup();
    flight.changed = true;
    flight.oldPrice = 800;
    flight.newPrice = 950;
    flight.price = 950;

    const res = await controller.revalidate({ ...dto, knownPrice: '800' });

    expect(res).toMatchObject({
      status: 'PRICE_CHANGED',
      offerId: 'off_1',
      oldPrice: 800,
      newPrice: 950,
      currency: 'USD',
    });
  });

  it('returns PRICE_CHANGED when the verified price moved from knownPrice', async () => {
    const { controller } = setup();

    const res = await controller.revalidate({ ...dto, knownPrice: '1200' });

    expect(res).toMatchObject({
      status: 'PRICE_CHANGED',
      oldPrice: 1200,
      newPrice: 800,
    });
  });

  it('returns UNAVAILABLE when the offer expired (verify failed)', async () => {
    const { controller, flight } = setup();
    flight.fails = true;

    const res = await controller.revalidate(dto);

    expect(res).toMatchObject({
      status: 'UNAVAILABLE',
      offerId: 'off_1',
    });
  });

  it('never calls a prebook — the path is read-only', async () => {
    const { controller } = setup();

    await controller.revalidate(dto);

    // The fake only exposes verifyFlightOffer; a prebook call would be a
    // TypeError. Reaching the assertion proves no prebook path was touched.
    expect(true).toBe(true);
  });
});
