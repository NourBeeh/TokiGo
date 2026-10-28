"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.MockHotelProvider = void 0;
class MockHotelProvider {
    providerId = 'mock-hotel';
    providerName = 'Mock Hotel Provider';
    async searchHotels(params) {
        return {
            success: true,
            providerId: this.providerId,
            providerName: this.providerName,
            data: [],
            timestamp: new Date(),
        };
    }
}
exports.MockHotelProvider = MockHotelProvider;
//# sourceMappingURL=mock.hotel.provider.js.map