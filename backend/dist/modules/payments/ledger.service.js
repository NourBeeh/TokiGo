"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.LedgerService = void 0;
const common_1 = require("@nestjs/common");
let LedgerService = class LedgerService {
    entries = [];
    append(entry) {
        const record = {
            ...entry,
            id: `led_${Math.random().toString(36).slice(2, 10)}${Date.now().toString(36)}`,
            occurredAt: new Date().toISOString(),
        };
        this.entries.push(record);
        return record;
    }
    forBooking(bookingId) {
        return this.entries.filter(e => e.bookingId === bookingId);
    }
    /** Balanced trail check: customer charges minus refunds equal net receipts. */
    bookingBalance(bookingId) {
        const booking = this.forBooking(bookingId);
        const charged = booking
            .filter(e => e.type === 'CHARGE' || e.type === 'CAPTURE')
            .reduce((s, e) => s + e.amount, 0);
        const refunded = booking
            .filter(e => e.type === 'REFUND')
            .reduce((s, e) => s + e.amount, 0);
        const currency = booking[0]?.currency ?? null;
        return { charged, refunded, net: charged - refunded, currency };
    }
};
exports.LedgerService = LedgerService;
exports.LedgerService = LedgerService = __decorate([
    (0, common_1.Injectable)()
], LedgerService);
//# sourceMappingURL=ledger.service.js.map