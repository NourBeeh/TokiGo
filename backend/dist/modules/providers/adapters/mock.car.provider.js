"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.MockCarProvider = void 0;
const common_1 = require("@nestjs/common");
/**
 * Car rental adapter — placeholder for a vendor that is not connected yet.
 *
 * OWNER DECISION (2026-10-19): **no fabricated inventory.** This adapter used
 * to answer every search with a hardcoded catalogue of six cars carrying
 * invented daily rates (21–95 USD), supplier names TokiGo has no relationship
 * with (Avis, Europcar, Hertz, Sixt), invented cancellation and mileage
 * policies, stock Unsplash photos and a made-up `originalPrice` (a fake 15%
 * discount on top of another invented number). All of it is gone.
 *
 * With no car vendor connected, the honest answer is "no cars" — never a
 * catalogue that looks bookable. The provider keeps its registry key
 * ('mock-car') and its CarProvider contract, so a real vendor adapter drops in
 * with zero domain/UI changes; the client already gates the car surface
 * (`_carRentalLive` in car_search_page.dart).
 */
let MockCarProvider = class MockCarProvider {
    providerId = 'mock-car';
    providerName = 'Car rental (not connected)';
    async searchCars(_params) {
        return {
            success: false,
            providerId: this.providerId,
            providerName: this.providerName,
            error: 'No car rental provider is connected yet — no vehicles or prices can be offered.',
            data: [],
            timestamp: new Date(),
        };
    }
};
exports.MockCarProvider = MockCarProvider;
exports.MockCarProvider = MockCarProvider = __decorate([
    (0, common_1.Injectable)()
], MockCarProvider);
//# sourceMappingURL=mock.car.provider.js.map