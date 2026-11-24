import { Injectable, Logger } from '@nestjs/common';
import { ProviderRegistryImpl } from '../../common/providers/provider.registry.impl';
import { CacheService } from '../cache/cache.service';
import { PricingService } from '../../common/market/pricing.service';
import { DEFAULT_MARKET } from '../../common/market/market-context';
import { countryFor } from '../nuitee/nuitee.cities';
import {
  HOTEL_SEARCH_CACHE_TTL_SECONDS,
  HOTEL_SEARCH_LOCK_TTL_MS,
  HOTEL_SEARCH_WAIT_MS,
  hotelSearchCacheKey,
} from './hotel-search-key';
import { CacheLockService } from '../../common/cache/cache-lock.service';
import { buildFlightItineraryGroups } from './flight-itinerary';

/** Per-provider search budget (spec points 12/15) — one slow provider never
 *  hangs the whole fan-out; the rest of the results still return. */
const PROVIDER_TIMEOUT_MS = 20_000;

/** Live search results cache (spec point 44): short TTL only. Cached prices
 *  are presentation snapshots — never booking truth (enforced by expiry +
 *  the offers/revalidate path before any booking flow).
 *
 *  120s was shorter than a normal Home → Search → Back round trip, so the same
 *  city re-queried the provider every time. Booking revalidates the offer
 *  before any charge, so a longer presentation TTL is safe. Override with
 *  SEARCH_CACHE_TTL_SECONDS. */
function searchCacheTtlSeconds(): number {
  const configured = Number(process.env.SEARCH_CACHE_TTL_SECONDS);
  return Number.isFinite(configured) && configured > 0 ? configured : 300;
}

/**
 * Phase 3B — Search orchestration (spec point 12 + 13):
 * fan out to every eligible provider with a per-provider timeout, classify
 * partial failures correctly (a provider returning {success:false} or
 * throwing is a failure — it must never be counted as a success),
 * normalize + deduplicate deterministically while preserving provider
 * identity (provider-specific ids stay verbatim inside each offer and its
 * metadata), and attach the market-aware display price without touching
 * provider amounts (spec points 5-6).
 */
@Injectable()
export class SearchService {
  private readonly logger = new Logger(SearchService.name);

  /**
   * Per-provider search budget (spec points 12/15). Injectable only for
   * tests via this field — deliberately NOT a constructor parameter, or
   * Nest's DI would try to resolve `Number` as a provider and crash boot
   * (found live 2026-09-09: "can't resolve dependencies of the SearchService
   * (... ?) argument Number at index [3]").
   */
  providerTimeoutMs: number = PROVIDER_TIMEOUT_MS;

  /**
   * Cache stampede protection. Instantiated directly (not constructor-injected)
   * so existing `new SearchService(registry, cache, pricing)` call sites and
   * tests keep working; tests can still replace it with a fake.
   */
  private readonly locks = new CacheLockService();

  constructor(
    private readonly registry: ProviderRegistryImpl,
    private readonly cache: CacheService,
    private readonly pricing: PricingService,
  ) {}

  async searchFlights(params: any, market?: string, currency?: string) {
    return this.search('flight', 'searchFlights', params, market, currency);
  }

  async searchHotels(params: any, market?: string, currency?: string) {
    return this.search('hotel', 'searchHotels', params, market, currency);
  }

  async searchCars(params: any, market?: string, currency?: string) {
    return this.search('car', 'searchCars', params, market, currency);
  }

  private async search(
    vertical: 'flight' | 'hotel' | 'car',
    method: 'searchFlights' | 'searchHotels' | 'searchCars',
    params: any,
    market?: string,
    currency?: string,
  ) {
    const isHotel = vertical === 'hotel';
    // Hotel searches use the mandated `hotels:{city}:{checkin}` identity and
    // the fixed 45s live-search TTL; other verticals keep their existing key
    // format and configurable presentation TTL.
    const cacheKey = isHotel
      ? hotelSearchCacheKey(params ?? {}, market, currency)
      : canonicalSearchCacheKey(vertical, params, market, currency);
    const ttlSeconds = isHotel
      ? HOTEL_SEARCH_CACHE_TTL_SECONDS
      : searchCacheTtlSeconds();

    let cached: any = null;
    try {
      cached = await this.cache.get(cacheKey);
    } catch (error) {
      // A cache outage must degrade to the provider, never fail the search.
      this.logger.debug(
        `Cache read failed for ${cacheKey}: ${(error as Error).message}`,
      );
    }
    if (cached) return cached;

    const providers =
      vertical === 'flight'
        ? this.registry.getFlightProviders()
        : vertical === 'hotel'
          ? this.registry.getHotelProviders()
          : this.registry.getCarProviders();
    const providerParams = { ...params };
    delete providerParams.mood;
    // Display currency is a pricing input, never a provider input.
    delete providerParams.currency;

    const fetch = async () => {
      // Fan-out with a per-provider timeout budget: a hung or slow provider
      // resolves as a failure after the budget instead of blocking the whole
      // search (partial-failure isolation, spec point 12).
      const settled = await Promise.allSettled(
        providers.map((p) =>
          withTimeout(
            p[method](providerParams),
            this.providerTimeoutMs,
            p.providerId as string,
          ).catch((err) => {
            // Attribute provider-side errors (incl. duffel SDK exceptions that
            // carry no identity) so failures[] never loses attribution.
            if (err instanceof Error && !('providerId' in err)) {
              (err as any).providerId = p.providerId;
            }
            throw err;
          }),
        ),
      );

      const aggregated = await this.aggregateWithPricing(
        settled,
        vertical,
        market,
        currency,
      );
      // Only fully-successful AND complete aggregations are cached; a
      // partial-failure or incomplete provider result is re-fetched next time.
      // `metadata.complete === false` means Nuitee's page walk stopped early
      // (failed page or page cap), so the hotel set is not the whole market
      // and must never be served as a cache hit.
      // An empty provider set is not a result either — it is an absent
      // catalogue and must not be served as "no availability".
      if (
        aggregated.failures.length === 0 &&
        aggregated.successes.length > 0 &&
        aggregated.successes.every((success: any) => {
          const complete = success?.metadata?.complete;
          return complete !== false;
        })
      ) {
        try {
          await this.cache.set(cacheKey, aggregated, ttlSeconds);
        } catch (error) {
          this.logger.debug(
            `Cache write failed for ${cacheKey}: ${(error as Error).message}`,
          );
        }
      }
      return aggregated;
    };

    // Single-flight + distributed lock: identical concurrent searches share
    // one provider fan-out, across processes too. Lock losers wait briefly
    // for the winner's cache entry before doing their own bounded fetch.
    return this.locks.singleFlight(cacheKey, async () => {
      const locked = await this.locks.withLock(
        `lock:search:${cacheKey}`,
        HOTEL_SEARCH_LOCK_TTL_MS,
        fetch,
      );
      if (locked.acquired) return locked.value;

      const waited = await this.waitForCache(cacheKey, HOTEL_SEARCH_WAIT_MS);
      if (waited) return waited;
      return fetch();
    });
  }

  /** Polls the cache until [timeoutMs] for another process to publish [key]. */
  private async waitForCache(key: string, timeoutMs: number): Promise<any | null> {
    const deadline = Date.now() + timeoutMs;
    while (Date.now() < deadline) {
      await new Promise((resolve) => setTimeout(resolve, 50));
      try {
        const value = await this.cache.get(key);
        if (value) return value;
      } catch {
        // Keep waiting; the cache may recover.
      }
    }
    return null;
  }

  /**
   * Attaches the customer display quote to an offer AND every nested
   * sub-offer. Nuitee returns one hotel row carrying all its room-type offers
   * in `offers`; the client's price filter and details selector compare those
   * sub-offers, so each one needs its own quote. Provider fields are copied
   * untouched; an offer that already carries a quote is not re-priced.
   */
  private async enrichOfferTree(
    offer: any,
    market?: string,
    currency?: string,
  ): Promise<any> {
    if (!offer || typeof offer !== 'object') return offer;
    let enriched = { ...offer };
    if (Array.isArray(offer.offers) && offer.offers.length > 0) {
      const nested: any[] = [];
      for (const child of offer.offers) {
        nested.push(await this.enrichOfferTree(child, market, currency));
      }
      enriched = { ...enriched, offers: nested };
    }
    if (
      typeof enriched.price === 'number' &&
      typeof enriched.currency === 'string' &&
      !enriched.customerPrice
    ) {
      return this.pricing.enrichOffer(enriched, { market, currency });
    }
    return enriched;
  }

  /**
   * Partial-failure aggregation (spec point 12) + display-currency
   * enrichment per offer. Provider truth survives intact inside each offer.
   */
  private async aggregateWithPricing(
    results: PromiseSettledResult<any>[],
    vertical: 'flight' | 'hotel' | 'car',
    market?: string,
    currency?: string,
  ) {
    const successes: any[] = [];
    const failures: any[] = [];
    for (const r of results) {
      if (r.status === 'fulfilled') {
        const value = r.value;

        // 3B fix: a provider that RESOLVED with success:false is a FAILED
        // provider, not a success (the old code counted it as a success and
        // left failures[] empty). Disabled/keyless adapters take this path.
        if (value?.success === false) {
          failures.push({
            providerId: value?.providerId ?? 'unknown',
            error: value?.error ?? 'provider returned success:false',
          });
          continue;
        }

        const offers = Array.isArray(value?.data) ? value.data : [];
        const enrichedOffers: any[] = [];
        for (const offer of offers) {
          enrichedOffers.push(await this.enrichOfferTree(offer, market, currency));
        }
        successes.push({ ...value, data: enrichedOffers });
      } else {
        const reason = (r as PromiseRejectedResult).reason;
        failures.push({
          providerId:
            (reason && typeof reason === 'object' && 'providerId' in reason
              ? String((reason as any).providerId)
              : undefined) ?? 'unknown',
          error: reason instanceof Error ? reason.message : String(reason),
        });
      }
    }

    // Phase 2D — flights are NOT deduped away. Every valid fare offer is
    // preserved inside one grouped row per identical itinerary, so a cheaper
    // fare from a second provider is still selectable. `successes` keeps the
    // raw provider buckets untouched.
    if (vertical === 'flight') {
      const grouping = buildFlightItineraryGroups(successes);
      return {
        successes,
        failures,
        duplicatesDropped: grouping.duplicatesDropped,
        invalidOffersDropped: grouping.invalidOffersDropped,
        results: grouping.results,
      };
    }

    // Hotels/cars keep the Phase 2C deterministic dedup: the FIRST provider in
    // registry order wins a duplicate key, every later duplicate is dropped;
    // ties break by array order so the same inputs always produce the same
    // list.
    const seen = new Set<string>();
    const dedupedSuccesses: any[] = [];
    let duplicatesDropped = 0;
    for (const s of successes) {
      const kept: any[] = [];
      for (const offer of (s?.data ?? []) as any[]) {
        const key = canonicalKey(offer);
        if (key === null || !seen.has(key)) {
          if (key !== null) seen.add(key);
          kept.push(offer);
        } else {
          duplicatesDropped++;
        }
      }
      dedupedSuccesses.push({ ...s, data: kept });
    }

    return {
      successes: dedupedSuccesses,
      failures,
      duplicatesDropped,
    };
  }
}

/**
 * Stable cache key for a search.
 *
 * `JSON.stringify(params)` used to be the key, which meant `{city, country}`
 * and `{country, city}` — the same search — were two cache entries, and a
 * pre-warmed entry never matched the request a real traveller sent. Keys are
 * now canonical: object keys sorted, strings trimmed/lowercased, ISO dates
 * reduced to their day, null/undefined dropped and primitive arrays sorted.
 *
 * Only the KEY is normalised; the provider still receives the caller's params
 * verbatim.
 */
export function canonicalSearchCacheKey(
  vertical: 'flight' | 'hotel' | 'car',
  params: any,
  market?: string,
  currency?: string,
): string {
  const canonical = canonicalize(normalizeForKey(vertical, params));
  const marketKey = String(market ?? DEFAULT_MARKET.marketCountry)
    .trim()
    .toUpperCase();
  // The display currency changes the priced response, so it is part of the
  // cache identity.
  const currencyKey = String(currency ?? '').trim().toUpperCase();
  return `search:${vertical}:${JSON.stringify(canonical)}:${marketKey}:${currencyKey}`;
}

/**
 * Applies the defaults the provider itself would apply, so "the same search
 * expressed differently" produces one key.
 *
 * The Flutter client sends `rooms: null` / omits `country`; the warmer sends
 * `rooms: 1` / an explicit country. Without this, a warmed entry would never be
 * hit by real traffic — the exact failure the canonical key exists to prevent.
 */
function normalizeForKey(vertical: 'flight' | 'hotel' | 'car', params: any): any {
  if (!params || typeof params !== 'object') return params;
  const out: Record<string, any> = { ...params };

  // `market` and `currency` are already key suffixes; leaving them in the
  // params would split an explicit value and an omitted one into two entries.
  delete out.market;
  delete out.currency;

  if (vertical === 'hotel') {
    // Nuitee searches 2 guests in 1 room, and resolves the country from the
    // city when it is absent (falling back to the launch market).
    out.guests = out.guests ?? 2;
    out.rooms = out.rooms ?? 1;
    if (
      typeof out.city === 'string' &&
      (out.country === undefined || out.country === null || out.country === '')
    ) {
      out.country = countryFor(out.city) ?? DEFAULT_MARKET.marketCountry;
    }
  }

  return out;
}

function canonicalize(value: any): any {
  if (value === null || value === undefined) return undefined;

  if (value instanceof Date) return isoDay(value);

  if (typeof value === 'string') {
    const trimmed = value.trim();
    // A date-time and a date-only string describe the same stay; collapse both
    // so a client sending `2026-11-10T00:00:00.000Z` hits the same entry as the
    // warmer's `2026-11-10`.
    if (/^\d{4}-\d{2}-\d{2}([T ].*)?$/.test(trimmed)) {
      return trimmed.slice(0, 10);
    }
    return trimmed.replace(/\s+/g, ' ').toLowerCase();
  }

  if (typeof value === 'number' || typeof value === 'boolean') return value;

  if (Array.isArray(value)) {
    const items = value
      .map((item) => canonicalize(item))
      .filter((item) => item !== undefined);
    // Filters (amenities, airlines) are sets, not sequences.
    return items.every((item) => typeof item !== 'object')
      ? [...items].sort()
      : items;
  }

  if (typeof value === 'object') {
    const out: Record<string, any> = {};
    for (const key of Object.keys(value).sort()) {
      const normalized = canonicalize(value[key]);
      if (normalized !== undefined) out[key] = normalized;
    }
    return out;
  }

  return value;
}

function isoDay(date: Date): string {
  return date.toISOString().slice(0, 10);
}

/** Wraps a provider promise with a timeout budget; the timeout error carries
 *  the providerId so failure classification keeps provider attribution. */
function withTimeout<T>(promise: Promise<T>, ms: number, providerId: string): Promise<T> {
  return Promise.race([
    promise,
    new Promise<T>((_, reject) => {
      const timer = setTimeout(() => {
        const err = new Error(
          `Provider ${providerId} search timed out after ${ms}ms`,
        ) as Error & { providerId?: string };
        err.providerId = providerId;
        reject(err);
      }, ms);
      if (typeof timer.unref === 'function') timer.unref();
    }),
  ]);
}

/**
 * Deterministic canonical dedup key (spec point 13) for hotels/cars.
 *
 * Flights no longer use this key: they are grouped by
 * `flight-itinerary.ts`, which preserves every fare offer instead of dropping
 * a duplicate itinerary.
 *
 * Hotels: provider hotel id, else normalized name+city.
 * Cars: supplier/location/category/title.
 * Unknown shapes fall back to the offer id — never null-key merging.
 */
function canonicalKey(offer: any): string | null {
  if (!offer || typeof offer !== 'object') return null;
  const id = String(offer.id ?? '');
  if (!id) return null;
  const provider = String(offer.providerId ?? '');

  if (offer.type === 'hotel') {
    const hotelId = offer.metadata?.providerHotelId ?? offer.metadata?.providerRateId;
    if (hotelId) return `h|${hotelId}`;
    const name = String(offer.title ?? '').trim().toLowerCase();
    const city = String(offer.city ?? '').trim().toLowerCase();
    return `h|n|${name}|${city}`;
  }
  if (offer.type === 'car') {
    return [
      'c',
      String(offer.supplier ?? offer.providerName ?? ''),
      String(offer.pickupLocation ?? ''),
      String(offer.carType ?? ''),
      String(offer.title ?? ''),
    ].join('|');
  }
  // Packages and unknown types: dedup by provider+id (identity, no merging).
  return `o|${provider}|${id}`;
}
