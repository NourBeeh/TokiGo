import { RequestMethod } from '@nestjs/common';
import { METHOD_METADATA, PATH_METADATA } from '@nestjs/common/constants';
import { HomeController } from '../src/modules/home/home.controller';
import { NearbyStaysController } from '../src/modules/nearby/nearby-stays.controller';

/**
 * Home route surface after the legacy Home removal.
 *
 * The old `/home/recommended` rail, the mood flight rail and `/home/refresh`
 * were removed with the old Home system. Only the destination feed used by
 * Explore and the promotional Nearby Stays endpoint remain.
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

describe('Home route surface after legacy removal', () => {
  const home = routesOf(HomeController);
  const nearby = routesOf(NearbyStaysController);
  const all = [...home, ...nearby];

  it('HomeController serves only the destination feed', () => {
    expect(home.map(signature)).toEqual(['GET /home/sections']);
  });

  it('the removed legacy endpoints are gone', () => {
    for (const path of <string>[
      '/home/recommended',
      '/home/flights-for-mood',
      '/home/refresh',
    ]) {
      expect(all.some((r) => r.path === path)).toBe(false);
    }
  });

  it('nearby stays has exactly one owner', () => {
    const owners = all.filter((r) => r.path === '/home/nearby-stays');
    expect(owners).toHaveLength(1);
    expect(owners[0].controller).toBe('NearbyStaysController');
  });

  it('no path is registered twice', () => {
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
