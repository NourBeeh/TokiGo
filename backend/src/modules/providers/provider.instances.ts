import { Injectable } from '@nestjs/common';

/**
 * providerKey -> provider instance map for every known adapter, active or not.
 *
 * The registry only holds ACTIVE providers (admin-managed), while health
 * checks and rebuilds must be able to reach disabled instances too — hence
 * this separate registry of everything the module constructs.
 */
@Injectable()
export class ProviderInstances {
  private readonly map = new Map<string, any>();

  register(key: string, instance: any) {
    this.map.set(key, instance);
  }

  get(key: string): any | null {
    return this.map.get(key) ?? null;
  }

  keys(): string[] {
    return [...this.map.keys()];
  }
}
