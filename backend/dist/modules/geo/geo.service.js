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
var GeoService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.GeoService = void 0;
const common_1 = require("@nestjs/common");
const config_1 = require("@nestjs/config");
const cache_service_1 = require("../cache/cache.service");
const GEO_TTL_SECONDS = 24 * 60 * 60; // a user's country rarely changes daily
const REQUEST_TIMEOUT_MS = 4_000;
/**
 * Detects the user's country from, in priority order:
 *  1. GPS coordinates (when supplied) — most accurate, needs device permission.
 *  2. IP geolocation (always available, no permission needed).
 *
 * The two results are cross-checked to build a confidence level, and every
 * lookup is cached for 24h. Failures are silent (return null) so no user flow
 * ever breaks because geolocation is down.
 *
 * Provider: ip-api.com (free, regional rate-limit ~45/min) — configurable via
 * GEO_API_URL. Uses the platform `fetch` (Node 18+), no new dependency.
 *
 * @private note: ip-api.com free tier is HTTP-only; keep it as the dev/cache
 * default and point GEO_API_URL at a paid/production endpoint when needed.
 */
let GeoService = GeoService_1 = class GeoService {
    config;
    cache;
    logger = new common_1.Logger(GeoService_1.name);
    apiUrl;
    constructor(config, cache) {
        this.config = config;
        this.cache = cache;
        this.apiUrl = this.config.get('GEO_API_URL') ?? 'http://ip-api.com/json';
    }
    /** Primary entry: resolves the best country from whatever is available. */
    async resolve(opts) {
        const ipResult = opts.ip ? await this.countryFromIp(opts.ip) : null;
        const gpsResult = opts.latitude !== undefined && opts.longitude !== undefined
            ? await this.countryFromCoords(opts.latitude, opts.longitude)
            : null;
        if (ipResult && gpsResult) {
            const agree = ipResult.countryCode === gpsResult.countryCode;
            return {
                countryCode: gpsResult.countryCode,
                country: gpsResult.country,
                source: 'both',
                ipCountry: ipResult.countryCode,
                gpsCountry: gpsResult.countryCode,
                confidence: agree ? 'high' : 'medium',
                ip: opts.ip,
            };
        }
        if (gpsResult) {
            return { ...gpsResult, source: 'gps', confidence: 'high' };
        }
        if (ipResult) {
            return { ...ipResult, source: 'ip', confidence: 'low' };
        }
        return null;
    }
    async countryFromIp(ip) {
        const key = `geo:ip:${ip}`;
        const cached = await this.cache.get(key);
        if (cached)
            return cached;
        const result = await this.lookup(ip);
        if (result)
            await this.cache.set(key, result, GEO_TTL_SECONDS);
        return result;
    }
    async countryFromCoords(latitude, longitude) {
        const key = `geo:gps:${latitude.toFixed(2)},${longitude.toFixed(2)}`;
        const cached = await this.cache.get(key);
        if (cached)
            return cached;
        const result = await this.lookup(`${latitude},${longitude}`);
        if (result)
            await this.cache.set(key, result, GEO_TTL_SECONDS);
        return result;
    }
    /** One bounded HTTP call; any failure returns null (never throws). */
    async lookup(query) {
        const controller = new AbortController();
        const timer = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
        try {
            const response = await fetch(`${this.apiUrl}/${encodeURIComponent(query)}?fields=status,country,countryCode,query`, { signal: controller.signal });
            if (!response.ok)
                return null;
            const data = (await response.json());
            if (data?.status !== 'success' || !data.countryCode || !data.country) {
                return null;
            }
            return { countryCode: data.countryCode, country: data.country };
        }
        catch (error) {
            this.logger.warn(`Geo lookup failed for "${query}": ${error.message}`);
            return null;
        }
        finally {
            clearTimeout(timer);
        }
    }
};
exports.GeoService = GeoService;
exports.GeoService = GeoService = GeoService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [config_1.ConfigService,
        cache_service_1.CacheService])
], GeoService);
//# sourceMappingURL=geo.service.js.map