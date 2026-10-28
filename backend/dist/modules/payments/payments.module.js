"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.PaymentsModule = void 0;
const common_1 = require("@nestjs/common");
const payments_controller_1 = require("./payments.controller");
const payment_service_1 = require("./payment.service");
const payment_router_1 = require("./payment.router");
const mock_egypt_gateway_1 = require("./mock.egypt.gateway");
const ledger_service_1 = require("./ledger.service");
let PaymentsModule = class PaymentsModule {
};
exports.PaymentsModule = PaymentsModule;
exports.PaymentsModule = PaymentsModule = __decorate([
    (0, common_1.Module)({
        controllers: [payments_controller_1.PaymentsController],
        providers: [payment_service_1.PaymentService, payment_router_1.PaymentRouter, mock_egypt_gateway_1.MockEgyptGateway, ledger_service_1.LedgerService],
        exports: [payment_service_1.PaymentService, ledger_service_1.LedgerService],
    })
], PaymentsModule);
//# sourceMappingURL=payments.module.js.map