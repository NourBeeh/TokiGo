"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.BookingsModule = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const booking_entity_1 = require("./booking.entity");
const bookings_service_1 = require("./bookings.service");
const bookings_controller_1 = require("./bookings.controller");
const booking_provider_registry_1 = require("./booking-provider.registry");
const duffel_booking_provider_1 = require("./adapters/duffel-booking.provider");
const nuitee_booking_provider_1 = require("./adapters/nuitee-booking.provider");
const nuitee_flight_booking_provider_1 = require("./adapters/nuitee-flight-booking.provider");
const providers_module_1 = require("../providers/providers.module");
/**
 * Booking foundation module (Phase 4A).
 *
 * Wires the persisted Booking record, the provider capability registry and
 * the JWT-guarded HTTP surface. Adapters reuse the existing Duffel/Nuitee
 * services from ProvidersModule — no provider call is re-implemented here.
 */
let BookingsModule = class BookingsModule {
};
exports.BookingsModule = BookingsModule;
exports.BookingsModule = BookingsModule = __decorate([
    (0, common_1.Module)({
        imports: [typeorm_1.TypeOrmModule.forFeature([booking_entity_1.Booking]), providers_module_1.ProvidersModule],
        controllers: [bookings_controller_1.BookingsController],
        providers: [
            bookings_service_1.BookingsService,
            duffel_booking_provider_1.DuffelBookingProvider,
            nuitee_booking_provider_1.NuiteeBookingProvider,
            nuitee_flight_booking_provider_1.NuiteeFlightBookingProvider,
            {
                provide: booking_provider_registry_1.BookingProviderRegistry,
                useFactory: (duffel, nuitee, nuiteeFlight) => {
                    const registry = new booking_provider_registry_1.BookingProviderRegistry();
                    registry.register(duffel);
                    registry.register(nuitee);
                    registry.register(nuiteeFlight);
                    return registry;
                },
                inject: [duffel_booking_provider_1.DuffelBookingProvider, nuitee_booking_provider_1.NuiteeBookingProvider, nuitee_flight_booking_provider_1.NuiteeFlightBookingProvider],
            },
        ],
        exports: [bookings_service_1.BookingsService],
    })
], BookingsModule);
//# sourceMappingURL=bookings.module.js.map