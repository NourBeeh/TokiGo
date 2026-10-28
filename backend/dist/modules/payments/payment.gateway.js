"use strict";
/**
 * Payment abstraction (spec points 31-33, O.7) — gateway routing by
 * paymentRegion. The Egypt gateway is implemented first as a
 * deterministic mock with real idempotency/webhook semantics, ready to be
 * swapped for a production PSP adapter without touching booking services.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.routesForMarket = routesForMarket;
function routesForMarket(paymentRegion) {
    // Config-driven routing table (spec point 33): EG first; SA/AE activate
    // only after gateway onboarding approval.
    switch (paymentRegion) {
        case 'EG':
            return 'EG';
        default:
            return null;
    }
}
//# sourceMappingURL=payment.gateway.js.map