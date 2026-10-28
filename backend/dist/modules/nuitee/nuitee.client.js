"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.NuiteeClient = exports.NUITEE_BASE_URL = void 0;
const common_1 = require("@nestjs/common");
/**
 * Nuitee Connect REST transport.
 *
 * Owns exactly three things: the API key, the request headers and the
 * JSON/error handling of a single HTTP call. Domain mapping lives in
 * `nuitee.mapper.ts`; orchestration lives in `nuitee.service.ts`.
 *
 * Sandbox and production share ONE base URL (api.liteapi.travel) — the
 * environment is determined by the API key itself (`sand_***` = sandbox).
 *
 * The key is read from NUITEE_API_KEY in the environment only — never shipped
 * to Flutter (spec non-negotiable).
 */
exports.NUITEE_BASE_URL = 'https://api.liteapi.travel/v3.0';
/** Every Nuitee call is bounded so a slow vendor cannot hold a request open. */
const REQUEST_TIMEOUT_MS = 15_000;
class NuiteeClient {
    logger = new common_1.Logger(NuiteeClient.name);
    apiKey;
    constructor(configService) {
        this.apiKey = configService.get('NUITEE_API_KEY');
        if (!this.apiKey) {
            this.logger.warn('NUITEE_API_KEY is not defined — Nuitee hotel provider is disabled');
        }
        else {
            const mode = this.apiKey.startsWith('sand_') ? 'sandbox' : 'live';
            this.logger.log(`Nuitee hotel provider enabled (${mode} key detected)`);
        }
    }
    /** False when no key was configured — callers must answer honestly. */
    get enabled() {
        return Boolean(this.apiKey);
    }
    headers() {
        return {
            'Content-Type': 'application/json',
            'X-API-Key': this.apiKey,
        };
    }
    /**
     * One authenticated call. Non-JSON or non-2xx responses throw an Error whose
     * message names the vendor path and status — never a silent empty list.
     */
    async request(path, init) {
        const response = await fetch(`${exports.NUITEE_BASE_URL}${path}`, {
            method: init.method,
            headers: this.headers(),
            body: init.body === undefined ? undefined : JSON.stringify(init.body),
            signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
        });
        const text = await response.text();
        let body;
        try {
            body = JSON.parse(text);
        }
        catch {
            throw new Error(`Nuitee returned non-JSON (${response.status}): ${text.slice(0, 120)}`);
        }
        if (!response.ok) {
            const detail = body?.error?.message ??
                body?.message ??
                JSON.stringify(body).slice(0, 160);
            throw new Error(`Nuitee ${path} failed (${response.status}): ${String(detail)}`);
        }
        return body;
    }
}
exports.NuiteeClient = NuiteeClient;
//# sourceMappingURL=nuitee.client.js.map