"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.MOCK_SIGNATURE_SECRET = exports.MockEgyptGateway = void 0;
exports.signMockWebhook = signMockWebhook;
const common_1 = require("@nestjs/common");
const config_1 = require("@nestjs/config");
const crypto = __importStar(require("crypto"));
/**
 * Deterministic mock Egyptian gateway (spec point 32) — plugs into the same
 * PaymentGateway interface a production PSP adapter will implement.
 *
 * Semantics preserved from the spec:
 *  - idempotency: repeating create/confirm/refund with the same key returns
 *    the original result (point 10)
 *  - webhook signing + verification (point 11)
 *  - 3DS-style pending state (CARD_3DS -> PENDING until the simulated
 *    webhook completes it — mirroring async recovery flows, point O.9)
 */
const DEV_FALLBACK_SIGNING_KEY = 'dev-only-insecure-webhook-key';
function signMockWebhook(payload) {
    const secret = process.env.WEBHOOK_SIGNING_KEY ?? DEV_FALLBACK_SIGNING_KEY;
    if (secret === DEV_FALLBACK_SIGNING_KEY) {
        // eslint-disable-next-line no-console
        console.warn('[MockEgyptGateway] WEBHOOK_SIGNING_KEY not set — using INSECURE dev fallback.');
    }
    return crypto
        .createHmac('sha256', secret)
        .update(`${payload.id}:${payload.paymentId}`)
        .digest('hex');
}
let MockEgyptGateway = class MockEgyptGateway {
    gatewayId = 'mock-egypt-gateway';
    supportsMarket = ['EG'];
    signingKey;
    intents = new Map();
    idempotencyResults = new Map();
    constructor(config) {
        this.signingKey =
            (config ? config.get('WEBHOOK_SIGNING_KEY') : undefined) ??
                process.env.WEBHOOK_SIGNING_KEY ??
                'dev-only-insecure-webhook-key';
        if (this.signingKey === 'dev-only-insecure-webhook-key') {
            // eslint-disable-next-line no-console
            console.warn('[MockEgyptGateway] WEBHOOK_SIGNING_KEY not set — using INSECURE dev fallback.');
        }
    }
    async createPaymentIntent(input) {
        const existing = this.idempotencyResults.get(`create:${input.idempotencyKey}`);
        if (existing)
            return existing;
        if (input.amount <= 0) {
            throw new Error('Payment amount must be positive');
        }
        const intent = {
            paymentId: `pay_${randomId()}`,
            bookingId: input.bookingId,
            amount: input.amount,
            currency: input.currency,
            status: 'REQUIRES_CONFIRMATION',
            clientSecret: `secret_${randomId()}`,
            createdAt: new Date().toISOString(),
        };
        this.intents.set(intent.paymentId, intent);
        this.idempotencyResults.set(`create:${input.idempotencyKey}`, intent);
        return intent;
    }
    async confirmPayment(input) {
        const existing = this.idempotencyResults.get(`confirm:${input.idempotencyKey}`);
        if (existing)
            return existing;
        const intent = this.intents.get(input.paymentId);
        if (!intent)
            throw new Error('Payment not found');
        if (intent.status === 'SUCCEEDED')
            return intent;
        if (intent.status === 'REFUNDED')
            throw new Error('Cannot confirm a refunded payment');
        let next;
        switch (input.methodReference) {
            case 'CARD_SUCCESS':
            case 'WALLET':
                next = 'SUCCEEDED';
                break;
            case 'CARD_3DS':
                // Async completion — the simulated webhook finishes it (O.9).
                next = 'PENDING';
                break;
            case 'CARD_DECLINED':
            default:
                next = 'FAILED';
                break;
        }
        const updated = { ...intent, status: next };
        this.intents.set(intent.paymentId, updated);
        this.idempotencyResults.set(`confirm:${input.idempotencyKey}`, updated);
        return updated;
    }
    async refundPayment(input) {
        const existing = this.idempotencyResults.get(`refund:${input.idempotencyKey}`);
        if (existing)
            return existing;
        const intent = this.intents.get(input.paymentId);
        if (!intent)
            throw new Error('Payment not found');
        if (intent.status !== 'SUCCEEDED')
            throw new Error('Only succeeded payments can be refunded');
        if (input.amount > intent.amount)
            throw new Error('Refund exceeds captured amount');
        const updated = { ...intent, status: 'REFUNDED' };
        this.intents.set(intent.paymentId, updated);
        this.idempotencyResults.set(`refund:${input.idempotencyKey}`, updated);
        return updated;
    }
    async retrievePayment(paymentId) {
        return this.intents.get(paymentId) ?? null;
    }
    /** Simulated PSP webhook signature verification (spec point 11). */
    verifyWebhook(payload) {
        // HMAC-SHA256 over "id:paymentId", constant-time compare.
        const expected = crypto
            .createHmac('sha256', this.signingKey)
            .update(`${payload.id}:${payload.paymentId}`)
            .digest('hex');
        try {
            return crypto.timingSafeEqual(Buffer.from(payload.signature, 'utf8'), Buffer.from(expected, 'utf8'));
        }
        catch {
            return false;
        }
    }
    /** Test/deterministic hook: complete a 3DS PENDING payment. */
    settlePending(paymentId) {
        const intent = this.intents.get(paymentId);
        if (!intent || intent.status !== 'PENDING')
            return null;
        const updated = { ...intent, status: 'SUCCEEDED' };
        this.intents.set(paymentId, updated);
        return updated;
    }
};
exports.MockEgyptGateway = MockEgyptGateway;
exports.MockEgyptGateway = MockEgyptGateway = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [config_1.ConfigService])
], MockEgyptGateway);
function randomId() {
    return Math.random().toString(36).slice(2, 12) + Date.now().toString(36);
}
exports.MOCK_SIGNATURE_SECRET = process.env.WEBHOOK_SIGNING_KEY ?? 'dev-only-insecure-webhook-key';
//# sourceMappingURL=mock.egypt.gateway.js.map