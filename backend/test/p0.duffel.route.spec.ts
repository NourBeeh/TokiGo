import { METHOD_METADATA, PATH_METADATA } from '@nestjs/common/constants';
import { RequestMethod } from '@nestjs/common';
import { DuffelController } from '../src/modules/duffel/duffel.controller';

/**
 * P0-S6 — the unsafe direct Duffel booking route must stay gone.
 *
 * `POST /api/duffel/create-booking` took a caller-supplied `payments[]` array
 * and forwarded it verbatim to the airline, bypassing `payment_attempts`, the
 * ledger and every server-side amount check. It has been removed; only the
 * read-only search route remains.
 */

interface MountedRoute {
  method?: RequestMethod;
  path: string;
}

function routesOf(controller: any): MountedRoute[] {
  const base = (Reflect.getMetadata(PATH_METADATA, controller) as string) ?? '';
  const routes: MountedRoute[] = [];

  for (const key of Object.getOwnPropertyNames(controller.prototype)) {
    if (key === 'constructor') continue;
    const handler = controller.prototype[key];
    if (typeof handler !== 'function') continue;

    const method = Reflect.getMetadata(METHOD_METADATA, handler) as
      | RequestMethod
      | undefined;
    if (method === undefined) continue;

    const handlerPath =
      (Reflect.getMetadata(PATH_METADATA, handler) as string) ?? '';
    const parts = [base, handlerPath]
      .map((p) => (p ?? '').replace(/^\/+|\/+$/g, ''))
      .filter(Boolean);
    routes.push({ method, path: '/' + parts.join('/') });
  }

  return routes;
}

describe('P0-S6 Duffel direct booking route', () => {
  it('no longer exposes POST /api/duffel/create-booking', () => {
    const routes = routesOf(DuffelController);
    expect(
      routes.filter((r) => r.path === '/api/duffel/create-booking'),
    ).toEqual([]);
  });

  it('still exposes the read-only flight search route', () => {
    expect(routesOf(DuffelController)).toContainEqual({
      method: RequestMethod.POST,
      path: '/api/duffel/search-flights',
    });
  });

  it('does not accept a client-supplied payments array anywhere', () => {
    const source = DuffelController.toString();
    expect(source).not.toContain('payments');
  });
});
