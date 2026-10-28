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
exports.DuffelController = void 0;
const common_1 = require("@nestjs/common");
const duffel_service_1 = require("./duffel.service");
const jwt_auth_guard_1 = require("../auth/jwt-auth.guard");
const duffel_dto_1 = require("../../common/dto/duffel.dto");
/**
 * Raw Duffel endpoints.
 *
 * `search-flights` is public: it only reads prices and carries no user data.
 * `create-booking` moves money at the airline, so it is JWT-guarded exactly
 * like `/bookings` — it used to accept an unauthenticated `any[]` body and
 * forward it straight to the provider.
 *
 * The app itself books through `/bookings`; these routes exist for provider
 * parity and diagnostics.
 */
let DuffelController = class DuffelController {
    duffelService;
    constructor(duffelService) {
        this.duffelService = duffelService;
    }
    async searchFlights(body) {
        return this.duffelService.searchFlights({
            origin: body.origin,
            destination: body.destination,
            departure: new Date(body.departureDate),
            passengers: body.passengers,
        });
    }
    async createBooking(body) {
        return this.duffelService.createOrder(body.offerId, body.passengers, body.payments);
    }
};
exports.DuffelController = DuffelController;
__decorate([
    (0, common_1.Post)('search-flights'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [duffel_dto_1.DuffelFlightSearchDto]),
    __metadata("design:returntype", Promise)
], DuffelController.prototype, "searchFlights", null);
__decorate([
    (0, common_1.Post)('create-booking'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [duffel_dto_1.DuffelCreateBookingDto]),
    __metadata("design:returntype", Promise)
], DuffelController.prototype, "createBooking", null);
exports.DuffelController = DuffelController = __decorate([
    (0, common_1.Controller)('api/duffel'),
    __metadata("design:paramtypes", [duffel_service_1.DuffelService])
], DuffelController);
//# sourceMappingURL=duffel.controller.js.map