"use strict";
/**
 * MarketContext (spec point 3) — the business context object that controls
 * POS/market, display currency, locale, payment region and tax region.
 *
 * Egypt is the first production market: EG / EGP / ar-EG.
 * The market selector changes this context; it must never select a travel
 * provider directly — provider routing consumes it as a separate policy.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.DEFAULT_MARKET = exports.MARKET_CONFIGS = void 0;
exports.marketFor = marketFor;
exports.MARKET_CONFIGS = {
    EG: {
        marketCountry: 'EG',
        displayCurrency: 'EGP',
        locale: 'ar-EG',
        paymentRegion: 'EG',
        posCountry: 'EG',
        taxRegion: 'EG',
        timezone: 'Africa/Cairo',
    },
    // Prepared but NOT enabled (spec point O.13 Phase 10): enable only after
    // written gateway/provider commercial confirmation.
    SA: {
        marketCountry: 'SA',
        displayCurrency: 'SAR',
        locale: 'ar-SA',
        paymentRegion: 'SA',
        posCountry: 'SA',
        taxRegion: 'SA',
        timezone: 'Asia/Riyadh',
    },
    AE: {
        marketCountry: 'AE',
        displayCurrency: 'AED',
        locale: 'ar-AE',
        paymentRegion: 'AE',
        posCountry: 'AE',
        taxRegion: 'AE',
        timezone: 'Asia/Dubai',
    },
};
exports.DEFAULT_MARKET = exports.MARKET_CONFIGS.EG;
function marketFor(countryCode) {
    if (!countryCode)
        return exports.DEFAULT_MARKET;
    return exports.MARKET_CONFIGS[countryCode.toUpperCase()] ?? exports.DEFAULT_MARKET;
}
//# sourceMappingURL=market-context.js.map