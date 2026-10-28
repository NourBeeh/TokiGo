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
exports.PaymentRouter = void 0;
const common_1 = require("@nestjs/common");
const mock_egypt_gateway_1 = require("./mock.egypt.gateway");
/**
 * Payment router (spec point 31/O.7): routes by paymentRegion, never by
 * provider name. Switching the Egypt gateway implementation does not touch
 * booking services.
 */
let PaymentRouter = class PaymentRouter {
    gateways = [];
    constructor(mockEgyptGateway) {
        this.gateways = [mockEgyptGateway];
    }
    /** Returns the active gateway for a market or null when checkout must stay disabled. */
    forMarket(paymentRegion) {
        return this.gateways.find(g => g.supportsMarket.includes(paymentRegion)) ?? null;
    }
    listGateways() {
        return this.gateways.map(g => ({
            gatewayId: g.gatewayId,
            markets: [...g.supportsMarket],
        }));
    }
};
exports.PaymentRouter = PaymentRouter;
exports.PaymentRouter = PaymentRouter = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [mock_egypt_gateway_1.MockEgyptGateway])
], PaymentRouter);
//# sourceMappingURL=payment.router.js.map