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
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.GeoController = void 0;
const common_1 = require("@nestjs/common");
const geo_service_1 = require("./geo.service");
let GeoController = class GeoController {
    geoService;
    constructor(geoService) {
        this.geoService = geoService;
    }
    /**
     * Best-effort country detection. Accepts optional GPS coordinates as query
     * params (lat/lng from the Flutter location service with user permission)
     * and combines them with the caller IP. Never throws — returns found:false
     * when nothing could be determined so clients can degrade gracefully.
     */
    async country(req, lat, lng) {
        const rawIp = this.clientIp(req);
        const ip = rawIp && !this.isLoopback(rawIp) ? rawIp : undefined;
        const latitude = lat !== undefined && lat !== '' && !Number.isNaN(Number(lat))
            ? Number(lat)
            : undefined;
        const longitude = lng !== undefined && lng !== '' && !Number.isNaN(Number(lng))
            ? Number(lng)
            : undefined;
        const result = await this.geoService.resolve({ ip, latitude, longitude });
        if (!result) {
            return { found: false, countryCode: null, source: null, confidence: null };
        }
        return { found: true, ...result };
    }
    clientIp(req) {
        // Trust X-Forwarded-For only when explicitly behind a trusted proxy.
        // Otherwise an attacker can spoof their IP/country by setting the header.
        if (process.env.TRUST_PROXY === 'true') {
            const forwarded = req.headers['x-forwarded-for']?.toString();
            if (forwarded)
                return forwarded.split(',')[0].trim();
        }
        return req.ip ?? req.socket?.remoteAddress;
    }
    isLoopback(ip) {
        return ip === '::1' || ip === '127.0.0.1' || ip.startsWith('::ffff:127.');
    }
};
exports.GeoController = GeoController;
__decorate([
    (0, common_1.Get)('country'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Query)('lat')),
    __param(2, (0, common_1.Query)('lng')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String, String]),
    __metadata("design:returntype", Promise)
], GeoController.prototype, "country", null);
exports.GeoController = GeoController = __decorate([
    (0, common_1.Controller)('geo'),
    __metadata("design:paramtypes", [geo_service_1.GeoService])
], GeoController);
//# sourceMappingURL=geo.controller.js.map