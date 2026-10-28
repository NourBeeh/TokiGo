import { Injectable } from '@nestjs/common';
import { BookingProvider } from '../../common/providers/booking-provider.interface';

/**
 * providerId → BookingProvider adapter registry (Phase 4A).
 *
 * Resolves the booking capability of an offer's provider without the service
 * ever switching on concrete classes. Unknown provider ids resolve to null so
 * the service can raise a normalised `offer_not_found`/capability error.
 */
@Injectable()
export class BookingProviderRegistry {
  private readonly providers = new Map<string, BookingProvider>();

  register(provider: BookingProvider): void {
    this.providers.set(provider.providerId, provider);
  }

  resolve(providerId: string): BookingProvider | null {
    return this.providers.get(providerId) ?? null;
  }

  has(providerId: string): boolean {
    return this.providers.has(providerId);
  }

  keys(): string[] {
    return [...this.providers.keys()];
  }
}
