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
var FxService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.FxService = void 0;
const common_1 = require("@nestjs/common");
const cache_service_1 = require("../../modules/cache/cache.service");
const RATE_TTL_SECONDS = 15 * 60;
// Deterministic fallback rates — used only when the FX source is
// unreachable so search never blocks. Marked clearly by source.
const FALLBACK_RATES = {
    'USD:EGP': 48.5,
    'EUR:EGP': 52.4,
    'GBP:EGP': 61.7,
    'USD:USD': 1,
    'EUR:USD': 1.08,
    'GBP:USD': 1.27,
};
let FxService = FxService_1 = class FxService {
    cache;
    logger = new common_1.Logger(FxService_1.name);
    constructor(cache) {
        this.cache = cache;
    }
    /** Returns a rate snapshot for base->quote (e.g. USD->EGP). */
    async getRate(base, quote) {
        const key = `fx:${base}:${quote}`;
        const cached = await this.cache.get(key);
        if (cached)
            return cached;
        let rate;
        let source = 'fallback-static';
        try {
            const response = await fetch(`https://open.er-api.com/v6/latest/${base}`, { signal: AbortSignal.timeout(4000) });
            if (response.ok) {
                const body = (await response.json());
                const fetched = body?.rates?.[quote];
                if (typeof fetched === 'number' && fetched > 0) {
                    rate = fetched;
                    source = 'open.er-api.com';
                }
            }
        }
        catch (e) {
            this.logger.warn(`FX fetch failed for ${base}->${quote}: ${e.message}`);
        }
        if (rate === undefined) {
            const direct = FALLBACK_RATES[`${base}:${quote}`];
            if (direct !== undefined) {
                rate = direct;
            }
            else {
                // Cross via USD as a last resort.
                const baseUsd = FALLBACK_RATES[`${base}:USD`];
                const usdQuote = FALLBACK_RATES[`USD:${quote}`];
                if (baseUsd && usdQuote) {
                    rate = baseUsd * usdQuote;
                }
                else {
                    rate = 1;
                }
            }
        }
        const snapshot = {
            base,
            quote,
            rate,
            source,
            rateId: `${base}-${quote}-${Date.now()}`,
            capturedAt: new Date().toISOString(),
        };
        await this.cache.set(key, snapshot, RATE_TTL_SECONDS);
        return snapshot;
    }
    /**
     * Converts a provider amount into the customer display currency and
     * returns BOTH sides (spec point 5: never silently rewrite provider money).
     */
    async convertForDisplay(amount, providerCurrency, displayCurrency) {
        if (providerCurrency === displayCurrency) {
            const identity = {
                base: providerCurrency,
                quote: displayCurrency,
                rate: 1,
                source: 'identity',
                rateId: `${providerCurrency}-${displayCurrency}-identity`,
                capturedAt: new Date().toISOString(),
            };
            return {
                providerAmount: amount,
                providerCurrency,
                customerAmount: amount,
                customerCurrency: displayCurrency,
                fx: identity,
            };
        }
        const fx = await this.getRate(providerCurrency, displayCurrency);
        const customerAmount = Math.round(amount * fx.rate * 100) / 100;
        return {
            providerAmount: amount,
            providerCurrency,
            customerAmount,
            customerCurrency: displayCurrency,
            fx,
        };
    }
};
exports.FxService = FxService;
exports.FxService = FxService = FxService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [cache_service_1.CacheService])
], FxService);
//# sourceMappingURL=fx.service.js.map