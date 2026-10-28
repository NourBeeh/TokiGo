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
Object.defineProperty(exports, "__esModule", { value: true });
exports.PricingService = exports.PRICING_VERSION = void 0;
const common_1 = require("@nestjs/common");
const fx_service_1 = require("./fx.service");
const market_context_1 = require("./market-context");
exports.PRICING_VERSION = '2026.09.1';
// Display-only rounding: customer totals round to whole units for EGP-style
// currencies to avoid awkward piasters; recorded explicitly as a line.
const WHOLE_UNIT_CURRENCIES = new Set(['EGP']);
let PricingService = class PricingService {
    fxService;
    constructor(fxService) {
        this.fxService = fxService;
    }
    /**
     * Builds the authoritative customer quote for one provider-priced offer.
     * markupPct/paymentFeePct are configuration knobs (0 = disabled).
     */
    async quote(providerAmount, providerCurrency, opts = {}) {
        const market = (0, market_context_1.marketFor)(opts.market ?? market_context_1.DEFAULT_MARKET.marketCountry);
        const displayCurrency = market.displayCurrency;
        const converted = await this.fxService.convertForDisplay(providerAmount, providerCurrency, displayCurrency);
        const markupPct = opts.markupPct ?? 0;
        const paymentFeePct = opts.paymentFeePct ?? 0;
        const base = converted.customerAmount;
        const markup = Math.round(base * (markupPct / 100) * 100) / 100;
        const paymentFee = Math.round(base * (paymentFeePct / 100) * 100) / 100;
        const subtotal = base + markup + paymentFee;
        const rounding = WHOLE_UNIT_CURRENCIES.has(displayCurrency) && !Number.isInteger(subtotal)
            ? Math.ceil(subtotal) - subtotal
            : 0;
        const customerTotal = Math.round((subtotal + rounding) * 100) / 100;
        const lines = [
            { type: 'BASE', label: 'Base fare', amount: base, currency: displayCurrency },
        ];
        if (markup > 0) {
            lines.push({ type: 'MARKUP', label: 'Service fee', amount: markup, currency: displayCurrency });
        }
        if (paymentFee > 0) {
            lines.push({
                type: 'PAYMENT_FEE',
                label: 'Payment fee',
                amount: paymentFee,
                currency: displayCurrency,
            });
        }
        if (rounding > 0) {
            lines.push({
                type: 'TAX',
                label: 'Rounding',
                amount: rounding,
                currency: displayCurrency,
            });
        }
        return {
            providerAmount: converted.providerAmount,
            providerCurrency: converted.providerCurrency,
            customerAmount: customerTotal,
            customerCurrency: displayCurrency,
            lines,
            fx: converted.fx,
            pricingVersion: exports.PRICING_VERSION,
            expiresAt: new Date(Date.now() + (opts.ttlMinutes ?? 30) * 60 * 1000).toISOString(),
            market: market.marketCountry,
        };
    }
    /**
     * Enriches a provider-mapped offer with the customer display price while
     * preserving every provider field untouched (spec point 5/O.6).
     */
    async enrichOffer(offer, opts = {}) {
        const quote = await this.quote(offer.price, offer.currency, opts);
        return { ...offer, customerPrice: quote };
    }
    async enrichOffers(offers, opts = {}) {
        const enriched = [];
        for (const offer of offers) {
            enriched.push(await this.enrichOffer(offer, opts));
        }
        return enriched;
    }
};
exports.PricingService = PricingService;
exports.PricingService = PricingService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [fx_service_1.FxService])
], PricingService);
//# sourceMappingURL=pricing.service.js.map