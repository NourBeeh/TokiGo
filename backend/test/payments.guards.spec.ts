import { PaymentsController } from '../src/modules/payments/payments.controller';
import { DuffelController } from '../src/modules/duffel/duffel.controller';
import { JwtAuthGuard } from '../src/modules/auth/jwt-auth.guard';
import { RolesGuard } from '../src/common/guards/roles.guard';
import { ROLES_KEY } from '../src/common/decorators/roles.decorator';

/**
 * Guard wiring (2026-10-25).
 *
 * The payment endpoints could be called anonymously: with any `bookingId` an
 * unknown caller could create an intent, confirm it or request a refund for
 * somebody else's booking. The DTO validation added earlier only checked the
 * SHAPE of the body — it never asked who was calling.
 *
 * These tests read the real Nest metadata (`__guards__` on the handler), so
 * deleting `@UseGuards(JwtAuthGuard)` from any of these routes fails the suite
 * without needing an HTTP server.
 *
 * Deliberately public:
 * - `/payments/webhook` — the gateway cannot hold a user token; it is
 *   authenticated by its HMAC signature inside the service.
 *
 * P0-S6 removed `POST /api/duffel/create-booking` entirely (caller-supplied
 * payments); `search-flights` stays JWT-guarded.
 */

const GUARDS = '__guards__';

function guardsOf(handler: (...args: any[]) => any): any[] {
  return Reflect.getMetadata(GUARDS, handler) ?? [];
}

function isJwtGuarded(handler: (...args: any[]) => any): boolean {
  return guardsOf(handler).includes(JwtAuthGuard);
}

describe('payments controller — who may call it', () => {
  const controller = PaymentsController.prototype;

  it.each([
    ['intent', controller.create],
    ['confirm', controller.confirm],
    ['refund', controller.refund],
    ['ledger', controller.timeline],
  ])('%s is JWT-guarded', (_name, handler) => {
    expect(isJwtGuarded(handler)).toBe(true);
  });

  it('webhook stays public (signature-authenticated by the gateway)', () => {
    expect(guardsOf(controller.webhook)).toHaveLength(0);
  });

  it('refund requires an admin, not merely a signed-in customer', () => {
    expect(guardsOf(controller.refund)).toContain(RolesGuard);
    expect(Reflect.getMetadata(ROLES_KEY, controller.refund)).toEqual(['admin']);
  });
});

describe('duffel controller — money routes require a member', () => {
  const controller = DuffelController.prototype;

  it('create-booking no longer exists (direct provider payments removed)', () => {
    // P0-S6: guarding the route was not enough — it forwarded a caller-supplied
    // payments[] straight to the airline, bypassing the authoritative payment
    // lifecycle. The route itself is gone.
    expect(
      (controller as unknown as Record<string, unknown>).createBooking,
    ).toBeUndefined();
  });

  it('search-flights requires a member (provider cost abuse guard)', () => {
    expect(isJwtGuarded(controller.searchFlights)).toBe(true);
  });
});
