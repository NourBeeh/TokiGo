"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var SearchService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.SearchService = void 0;
const common_1 = require("@nestjs/common");
const provider_registry_impl_1 = require("../../common/providers/provider.registry.impl");
const cache_service_1 = require("../cache/cache.service");
const pricing_service_1 = require("../../common/market/pricing.service");
const market_context_1 = require("../../common/market/market-context");
/** Per-provider search budget (spec points 12/15) — one slow provider never
 *  hangs the whole fan-out; the rest of the results still return. */
const PROVIDER_TIMEOUT_MS = 20_000;
/** Live search results cache (spec point 44): short TTL only. Cached prices
 *  are presentation snapshots — never booking truth (enforced by expiry +
 *  the offers/revalidate path before any booking flow). */
const SEARCH_CACHE_TTL_SECONDS = 120;
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
let SearchService = SearchService_1 = class SearchService {
    registry;
    cache;
    pricing;
    logger = new common_1.Logger(SearchService_1.name);
    /**
     * Per-provider search budget (spec points 12/15). Injectable only for
     * tests via this field — deliberately NOT a constructor parameter, or
     * Nest's DI would try to resolve `Number` as a provider and crash boot
     * (found live 2026-09-09: "can't resolve dependencies of the SearchService
     * (... ?) argument Number at index [3]").
     */
    providerTimeoutMs = PROVIDER_TIMEOUT_MS;
    constructor(registry, cache, pricing) {
        this.registry = registry;
        this.cache = cache;
        this.pricing = pricing;
    }
    async searchFlights(params, market) {
        return this.search('flight', 'searchFlights', params, market);
    }
    async searchHotels(params, market) {
        return this.search('hotel', 'searchHotels', params, market);
    }
    async searchCars(params, market) {
        return this.search('car', 'searchCars', params, market);
    }
    async search(vertical, method, params, market) {
        const cacheKey = `search:${vertical}:${JSON.stringify(params)}:${market ?? market_context_1.DEFAULT_MARKET.marketCountry}`;
        const cached = await this.cache.get(cacheKey);
        if (cached)
            return cached;
        const providers = vertical === 'flight'
            ? this.registry.getFlightProviders()
            : vertical === 'hotel'
                ? this.registry.getHotelProviders()
                : this.registry.getCarProviders();
        const providerParams = { ...params };
        delete providerParams.mood;
        // Fan-out with a per-provider timeout budget: a hung or slow provider
        // resolves as a failure after the budget instead of blocking the whole
        // search (partial-failure isolation, spec point 12).
        const settled = await Promise.allSettled(providers.map((p) => withTimeout(p[method](providerParams), this.providerTimeoutMs, p.providerId).catch((err) => {
            // Attribute provider-side errors (incl. duffel SDK exceptions that
            // carry no identity) so failures[] never loses attribution.
            if (err instanceof Error && !('providerId' in err)) {
                err.providerId = p.providerId;
            }
            throw err;
        })));
        const aggregated = await this.aggregateWithPricing(settled, market);
        // Only fully-successful aggregations are cached; a partial-failure
        // response is re-fetched next time (the failing provider may recover).
        if (aggregated.failures.length === 0) {
            await this.cache.set(cacheKey, aggregated, SEARCH_CACHE_TTL_SECONDS);
        }
        return aggregated;
    }
    /**
     * Partial-failure aggregation (spec point 12) + display-currency
     * enrichment per offer. Provider truth survives intact inside each offer.
     */
    async aggregateWithPricing(results, market) {
        const successes = [];
        const failures = [];
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
                const enrichedOffers = [];
                for (const offer of offers) {
                    if (typeof offer?.price === 'number' &&
                        typeof offer?.currency === 'string' &&
                        !offer?.customerPrice) {
                        enrichedOffers.push(await this.pricing.enrichOffer(offer, { market }));
                    }
                    else {
                        enrichedOffers.push(offer);
                    }
                }
                successes.push({ ...value, data: enrichedOffers });
            }
            else {
                const reason = r.reason;
                failures.push({
                    providerId: (reason && typeof reason === 'object' && 'providerId' in reason
                        ? String(reason.providerId)
                        : undefined) ?? 'unknown',
                    error: reason instanceof Error ? reason.message : String(reason),
                });
            }
        }
        // Deterministic dedup (spec point 13): the FIRST provider in registry
        // order wins a duplicate key, every later duplicate is dropped; ties
        // break by array order so the same inputs always produce the same list.
        const seen = new Set();
        const dedupedSuccesses = [];
        let duplicatesDropped = 0;
        for (const s of successes) {
            const kept = [];
            for (const offer of (s?.data ?? [])) {
                const key = canonicalKey(offer);
                if (key === null || !seen.has(key)) {
                    if (key !== null)
                        seen.add(key);
                    kept.push(offer);
                }
                else {
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
};
exports.SearchService = SearchService;
exports.SearchService = SearchService = SearchService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [provider_registry_impl_1.ProviderRegistryImpl,
        cache_service_1.CacheService,
        pricing_service_1.PricingService])
], SearchService);
/** Wraps a provider promise with a timeout budget; the timeout error carries
 *  the providerId so failure classification keeps provider attribution. */
function withTimeout(promise, ms, providerId) {
    return Promise.race([
        promise,
        new Promise((_, reject) => {
            const timer = setTimeout(() => {
                const err = new Error(`Provider ${providerId} search timed out after ${ms}ms`);
                err.providerId = providerId;
                reject(err);
            }, ms);
            if (typeof timer.unref === 'function')
                timer.unref();
        }),
    ]);
}
/**
 * Deterministic canonical dedup key (spec point 13).
 * Flights: carrier/flight-number/times/origin/destination.
 * Hotels: provider hotel id, else normalized name+city.
 * Cars: supplier/location/category/title.
 * Unknown shapes fall back to the offer id — never null-key merging.
 */
function canonicalKey(offer) {
    if (!offer || typeof offer !== 'object')
        return null;
    const id = String(offer.id ?? '');
    if (!id)
        return null;
    const provider = String(offer.providerId ?? '');
    if (offer.type === 'flight') {
        const parts = [
            'f',
            String(offer.airline ?? ''),
            String(offer.flightNumber ?? ''),
            String(offer.departureTime ?? ''),
            String(offer.origin ?? ''),
            String(offer.destination ?? ''),
        ];
        return parts.join('|');
    }
    if (offer.type === 'hotel') {
        const hotelId = offer.metadata?.providerHotelId ?? offer.metadata?.providerRateId;
        if (hotelId)
            return `h|${hotelId}`;
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
//# sourceMappingURL=search.service.js.map