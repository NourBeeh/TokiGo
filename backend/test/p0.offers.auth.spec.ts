import {
  GUARDS_METADATA,
  METHOD_METADATA,
  PATH_METADATA,
} from '@nestjs/common/constants';
import { RequestMethod, UnauthorizedException } from '@nestjs/common';
import { OffersController } from '../src/modules/offers/offers.controller';
import { OptionalJwtAuthGuard } from '../src/modules/auth/optional-jwt-auth.guard';

/**
 * P0-S3 — offer revalidation must not be anonymously-abusable.
 *
 * The endpoint was fully public. For `providerId: 'nuitee'` it called
 * `prebookHotel`, which freezes a quote at the provider — a real inventory
 * hold an anonymous caller could create at will.
 *
 * The mobile client posts to this endpoint WITHOUT an Authorization header
 * (`offer_revalidation_service.dart`) and the Home live-validation pass runs
 * before sign-in, so a hard guard would break legitimate flows. The fix
 * resolves identity optionally and refuses only the hold-creating branch.
 */

// Set by @Throttle({ default: { ttl, limit } }) — internal metadata keys.
const THROTTLER_TTL_DEFAULT = 'THROTTLER:TTLdefault';
const THROTTLER_LIMIT_DEFAULT = 'THROTTLER:LIMITdefault';

interface Harness {
  controller: OffersController;
  nuiteeService: { prebookHotel: jest.Mock };
  nuiteeFlightService: { verifyFlightOffer: jest.Mock };
}

function makeHarness(): Harness {
  const nuiteeService = {
    prebookHotel: jest.fn().mockResolvedValue({
      success: true,
      providerId: 'nuitee',
      prebookId: 'pb-1',
      newPrice: 100,
      currency: 'USD',
    }),
  };
  const nuiteeFlightService = {
    verifyFlightOffer: jest.fn().mockResolvedValue({
      success: true,
      price: 100,
      currency: 'USD',
    }),
  };
  const controller = new OffersController(
    { revalidateOffer: jest.fn() } as any,
    nuiteeService as any,
    nuiteeFlightService as any,
  );
  return { controller, nuiteeService, nuiteeFlightService };
}

const anonymousRequest = {} as any;
const authenticatedRequest = { user: { id: 'user-1' } } as any;

describe('P0-S3 offer revalidation authorization', () => {
  it('refuses an anonymous Nuitee hotel prebook', async () => {
    const { controller, nuiteeService } = makeHarness();

    await expect(
      controller.revalidate(anonymousRequest, {
        offerId: 'rate-1',
        providerId: 'nuitee',
        offerType: 'hotel',
      } as any),
    ).rejects.toBeInstanceOf(UnauthorizedException);

    expect(nuiteeService.prebookHotel).not.toHaveBeenCalled();
  });

  it('still allows the read-only Nuitee flight check anonymously', async () => {
    const { controller, nuiteeService, nuiteeFlightService } = makeHarness();

    const result = await controller.revalidate(anonymousRequest, {
      offerId: 'offer-1',
      providerId: 'nuitee-flight',
      offerType: 'flight',
    } as any);

    expect(nuiteeFlightService.verifyFlightOffer).toHaveBeenCalledWith('offer-1');
    expect(nuiteeService.prebookHotel).not.toHaveBeenCalled();
    expect(result).toMatchObject({ status: 'OK', offerId: 'offer-1' });
  });

  it('allows the Nuitee hotel prebook for an authenticated caller', async () => {
    const { controller, nuiteeService } = makeHarness();

    const result = await controller.revalidate(authenticatedRequest, {
      offerId: 'rate-1',
      providerId: 'nuitee',
      offerType: 'hotel',
    } as any);

    expect(nuiteeService.prebookHotel).toHaveBeenCalledWith({
      offerId: 'rate-1',
    });
    expect(result).toMatchObject({ status: 'OK', offerId: 'rate-1' });
  });

  it('maps the FLAT Nuitee prebook result (no data wrapper) and surfaces changed terms', async () => {
    const { controller, nuiteeService } = makeHarness();
    nuiteeService.prebookHotel.mockResolvedValueOnce({
      success: true,
      providerId: 'nuitee',
      prebookId: 'pb-1',
      newPrice: 120,
      currency: 'USD',
      cancellationChanged: true,
      boardChanged: true,
    });

    const result = await controller.revalidate(authenticatedRequest, {
      offerId: 'offer-1',
      providerId: 'nuitee',
      offerType: 'hotel',
      knownPrice: 100,
    } as any);

    expect(result).toMatchObject({
      status: 'PRICE_CHANGED',
      offerId: 'offer-1',
      oldPrice: 100,
      newPrice: 120,
      currency: 'USD',
      cancellationChanged: true,
      boardChanged: true,
    });
  });

  it('refuses a Nuitee prebook without a usable price instead of reporting a zero OK', async () => {
    const { controller, nuiteeService } = makeHarness();
    nuiteeService.prebookHotel.mockResolvedValueOnce({
      success: true,
      providerId: 'nuitee',
      prebookId: 'pb-1',
      currency: 'USD',
    });

    const result = await controller.revalidate(authenticatedRequest, {
      offerId: 'offer-1',
      providerId: 'nuitee',
      offerType: 'hotel',
    } as any);

    expect(result).toMatchObject({
      status: 'UNAVAILABLE',
      offerId: 'offer-1',
    });
  });

  it('mounts the route with optional auth, POST, and its own throttle budget', () => {
    const handler = OffersController.prototype.revalidate;

    expect(Reflect.getMetadata(PATH_METADATA, handler)).toBe('revalidate');
    expect(Reflect.getMetadata(METHOD_METADATA, handler)).toBe(RequestMethod.POST);
    expect(Reflect.getMetadata(GUARDS_METADATA, handler)).toContain(
      OptionalJwtAuthGuard,
    );
    expect(Reflect.getMetadata(THROTTLER_TTL_DEFAULT, handler)).toBe(60_000);
    expect(Reflect.getMetadata(THROTTLER_LIMIT_DEFAULT, handler)).toBe(10);
  });
});
