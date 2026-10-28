"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.AiProviderFailure = exports.AI_FALLBACK_PROVIDER = exports.AI_PROVIDER = void 0;
exports.isFallbackEligible = isFallbackEligible;
exports.categoryOf = categoryOf;
exports.upstreamStatusOf = upstreamStatusOf;
const common_1 = require("@nestjs/common");
/** DI token so Phase 9 can bind Grok/Gemini/DeepSeek providers without
 *  touching the controller or the service. */
exports.AI_PROVIDER = Symbol('AI_PROVIDER');
/**
 * DI token for the optional secondary provider used by the Phase 10C fallback
 * policy. The bound value is `null` when `AI_FALLBACK_PROVIDER` is empty, which
 * disables fallback entirely and restores single-provider behaviour.
 */
exports.AI_FALLBACK_PROVIDER = Symbol('AI_FALLBACK_PROVIDER');
/**
 * Categories a second provider may be able to serve.
 *
 * Single source of truth for the Phase 10C policy: `retryable` is derived from
 * the category so the two can never disagree.
 */
const RETRYABLE_CATEGORIES = new Set([
    'network',
    'timeout',
    'upstream_5xx',
    'empty_completion',
]);
/**
 * A provider-level failure that states its kind and whether another provider
 * may be tried.
 *
 * Extends [ServiceUnavailableException] so `/ai/query` keeps answering 503 for
 * every provider problem exactly as before — the HTTP contract is unchanged.
 * The [category] is what lets [AiService] both honour the fallback policy and
 * log a useful reason: without it a 4xx and a 5xx upstream are
 * indistinguishable, because both previously collapsed into the same bare 503.
 *
 * [upstreamStatus] is the status the upstream provider returned, when the call
 * completed. It carries no response body, so no upstream payload or credential
 * can travel with the error.
 */
class AiProviderFailure extends common_1.ServiceUnavailableException {
    constructor(message, params) {
        super(message);
        this.category = params.category;
        this.upstreamStatus = params.upstreamStatus;
        this.retryable = RETRYABLE_CATEGORIES.has(params.category);
    }
    /** What kind of failure this was, from the fixed vocabulary. */
    category;
    /** True when the failure is transient and a secondary provider may help. */
    retryable;
    /** Upstream HTTP status, when the request reached the provider. */
    upstreamStatus;
}
exports.AiProviderFailure = AiProviderFailure;
/** True when [error] is a provider failure that permits a fallback attempt. */
function isFallbackEligible(error) {
    return error instanceof AiProviderFailure && error.retryable;
}
/**
 * Classifies [error] for logging.
 *
 * Anything that is not an [AiProviderFailure] is a defect rather than a known
 * provider condition, so it is reported as `unexpected` — never by echoing the
 * thrown message, which could contain arbitrary text.
 */
function categoryOf(error) {
    return error instanceof AiProviderFailure ? error.category : 'unexpected';
}
/** Upstream status when known, for observability only. */
function upstreamStatusOf(error) {
    return error instanceof AiProviderFailure ? error.upstreamStatus : undefined;
}
//# sourceMappingURL=ai.provider.js.map