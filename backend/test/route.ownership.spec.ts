import { RequestMethod } from '@nestjs/common';
import { METHOD_METADATA, PATH_METADATA } from '@nestjs/common/constants';
import { HomeController } from '../src/modules/home/home.controller';
import { RecommendedHotelsController } from '../src/modules/recommend/recommended-hotels.controller';

/**
 * Route-ownership regression (2026-10-25).
 *
 * `GET /home/recommended` was registered TWICE — once by HomeController (fixed
 * Cairo list, no country) and once by RecommendedHotelsController (country
 * aware + deterministic scoring). Because HomeModule is imported before
 * RecommendModule, Express served the first match and the recommendation
 * engine was unreachable: every user saw Cairo hotels, and no error was ever
 * raised. Registration order is not a contract, so this test pins the real
 * invariant: exactly ONE handler owns the path.
 */

interface MountedRoute {
  controller: string;
  method: RequestMethod;
  path: string;
}

function joinPath(base: string, path: string): string {
  const parts = [base, path]
    .map((p) => (p ?? '').replace(/^\/+|\/+$/g, ''))
    .filter((p) => p.length > 0);
  return '/' + parts.join('/');
}

function routesOf(controller: any): MountedRoute[] {
  const name = controller.name as string;
  const base = (Reflect.getMetadata(PATH_METADATA, controller) as string) ?? '';
  const proto = controller.prototype as Record<string, unknown>;
  const routes: MountedRoute[] = [];

  for (const key of Object.getOwnPropertyNames(proto)) {
    if (key === 'constructor') continue;
    const handler = proto[key];
    if (typeof handler !== 'function') continue;

    const method = Reflect.getMetadata(METHOD_METADATA, handler) as
      | RequestMethod
      | undefined;
    if (method === undefined) continue;

    const path = (Reflect.getMetadata(PATH_METADATA, handler) as string) ?? '';
    routes.push({ controller: name, method, path: joinPath(base, path) });
  }
  return routes;
}

function signature(route: MountedRoute): string {
  return `${RequestMethod[route.method]} ${route.path}`;
}

describe('Route ownership — GET /home/recommended', () => {
  const home = routesOf(HomeController);
  const recommend = routesOf(RecommendedHotelsController);
  const all = [...home, ...recommend];

  it('is registered by exactly one controller', () => {
    const owners = all.filter(
      (r) => r.method === RequestMethod.GET && r.path === '/home/recommended',
    );
    expect(owners).toHaveLength(1);
    expect(owners[0].controller).toBe('RecommendedHotelsController');
  });

  it('HomeController no longer serves the rail', () => {
    expect(home.some((r) => r.path === '/home/recommended')).toBe(false);
    // The rest of the Home surface is untouched.
    expect(home.map(signature)).toEqual(
      expect.arrayContaining([
        'GET /home/sections',
        'GET /home/flights-for-mood',
        'POST /home/refresh',
      ]),
    );
  });

  it('RecommendedHotelsController owns it with the documented method', () => {
    expect(recommend.map(signature)).toContain('GET /home/recommended');
    expect(recommend.every((r) => r.method === RequestMethod.GET)).toBe(true);
  });

  it('no other path is registered twice either', () => {
    const seen = new Map<string, string>();
    const duplicates: string[] = [];
    for (const route of all) {
      const key = signature(route);
      const previous = seen.get(key);
      if (previous) duplicates.push(`${key} (${previous} + ${route.controller})`);
      else seen.set(key, route.controller);
    }
    expect(duplicates).toEqual([]);
  });
});
