import { PaymentsController } from '../src/modules/payments/payments.controller';
import { DuffelController } from '../src/modules/duffel/duffel.controller';
import { JwtAuthGuard } from '../src/modules/auth/jwt-auth.guard';

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
 * - `/api/duffel/search-flights` — reads prices only, owns no user data.
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
});

describe('duffel controller — money routes require a member', () => {
  const controller = DuffelController.prototype;

  it('create-booking is JWT-guarded', () => {
    expect(isJwtGuarded(controller.createBooking)).toBe(true);
  });

  it('search-flights requires a member (provider cost abuse guard)', () => {
    expect(isJwtGuarded(controller.searchFlights)).toBe(true);
  });
});
