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
exports.HomeController = void 0;
const common_1 = require("@nestjs/common");
const home_service_1 = require("./home.service");
const home_flights_service_1 = require("./home.flights.service");
let HomeController = class HomeController {
    homeService;
    flights;
    constructor(homeService, flights) {
        this.homeService = homeService;
        this.flights = flights;
    }
    async getSections() {
        return this.homeService.getSections();
    }
    /**
     * NOTE: `GET /home/recommended` is NOT served here. The single owner is
     * `RecommendedHotelsController` (modules/recommend), which is country-aware,
     * scores deterministically and caches the snapshot. This controller used to
     * register the same path, and because HomeModule is imported before
     * RecommendModule, Express silently routed every Home call to the fixed
     * Cairo list and the recommendation engine was unreachable.
     */
    /**
     * Phase 2 — the real Duffel-backed flight rail for the selected travel mood.
     * `country` is the traveller's country (origin airport is a suggestion),
     * `mood` is one of the authored travel moods and `limit` is clamped to three
     * live searches. Provider failures produce an honest shorter list.
     */
    async getFlightsForMood(country, mood, limit) {
        const parsed = limit !== undefined ? parseInt(limit, 10) : undefined;
        return this.flights.getFlightsForMood({
            country,
            mood,
            limit: Number.isFinite(parsed) ? parsed : undefined,
        });
    }
    async refresh() {
        return this.homeService.refresh();
    }
};
exports.HomeController = HomeController;
__decorate([
    (0, common_1.Get)('sections'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", Promise)
], HomeController.prototype, "getSections", null);
__decorate([
    (0, common_1.Get)('flights-for-mood'),
    __param(0, (0, common_1.Query)('country')),
    __param(1, (0, common_1.Query)('mood')),
    __param(2, (0, common_1.Query)('limit')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String, String]),
    __metadata("design:returntype", Promise)
], HomeController.prototype, "getFlightsForMood", null);
__decorate([
    (0, common_1.Post)('refresh'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", Promise)
], HomeController.prototype, "refresh", null);
exports.HomeController = HomeController = __decorate([
    (0, common_1.Controller)('home'),
    __metadata("design:paramtypes", [home_service_1.HomeService,
        home_flights_service_1.HomeFlightsService])
], HomeController);
//# sourceMappingURL=home.controller.js.map