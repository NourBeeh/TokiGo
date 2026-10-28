"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.MockFlightProvider = void 0;
class MockFlightProvider {
    providerId = 'mock-flight';
    providerName = 'Mock Flight Provider';
    async searchFlights(params) {
        return {
            success: true,
            providerId: this.providerId,
            providerName: this.providerName,
            data: [],
            timestamp: new Date(),
        };
    }
}
exports.MockFlightProvider = MockFlightProvider;
//# sourceMappingURL=mock.flight.provider.js.map