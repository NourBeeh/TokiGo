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
exports.AiRerankDto = exports.RerankCandidateDto = void 0;
exports.contextIsSafe = contextIsSafe;
exports.candidateMetaIsSafe = candidateMetaIsSafe;
const class_validator_1 = require("class-validator");
/**
 * AI rerank contract (Phase 1C — Personalization Spine).
 *
 * The client sends a SAFE, minimal context plus a small set of REAL
 * candidates produced by the existing recommendation/search infrastructure.
 * The AI may only reorder those candidates — it can never introduce ids,
 * prices, availability, providers, or any product facts. Everything outside
 * the whitelists below is rejected by validation before any AI call.
 */
/** Context keys the AI is allowed to see. Anything else is a 400. */
const CONTEXT_WHITELIST = new Set([
    'userState',
    'countryCode',
    'recentSearchLabels',
    'viewedTitles',
    'favoriteTitles',
    'upcomingDestination',
    'topDestinations',
    'preferredStars',
    'budgetMax',
    'hasTrips',
]);
/** Metadata keys a candidate may carry. */
const CANDIDATE_META_WHITELIST = new Set(['city', 'rating', 'reviews', 'reason']);
class RerankCandidateDto {
    /** Provider/recommendation id — the only key the AI may return. */
    id;
    title;
    /** Optional real price from the provider (display only, never mutated). */
    price;
    metadata;
}
exports.RerankCandidateDto = RerankCandidateDto;
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.Length)(1, 120),
    __metadata("design:type", String)
], RerankCandidateDto.prototype, "id", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.Length)(1, 160),
    __metadata("design:type", String)
], RerankCandidateDto.prototype, "title", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsNumber)(),
    __metadata("design:type", Number)
], RerankCandidateDto.prototype, "price", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsObject)(),
    __metadata("design:type", Object)
], RerankCandidateDto.prototype, "metadata", void 0);
class AiRerankDto {
    /**
     * Safe personalization context. Validated against CONTEXT_WHITELIST so no
     * tokens, emails, payment data, or precise GPS can reach the AI.
     */
    context;
    /** Real candidates (≤ 30) from provider/recommendation infrastructure. */
    candidates;
    /** Section reasons the composer is prepared to explain. */
    allowedReasons;
}
exports.AiRerankDto = AiRerankDto;
__decorate([
    (0, class_validator_1.IsObject)(),
    __metadata("design:type", Object)
], AiRerankDto.prototype, "context", void 0);
__decorate([
    (0, class_validator_1.IsArray)(),
    (0, class_validator_1.ArrayMaxSize)(30),
    (0, class_validator_1.ValidateNested)({ each: true }),
    __metadata("design:type", Array)
], AiRerankDto.prototype, "candidates", void 0);
__decorate([
    (0, class_validator_1.IsArray)(),
    (0, class_validator_1.IsString)({ each: true }),
    __metadata("design:type", Array)
], AiRerankDto.prototype, "allowedReasons", void 0);
/** Validates that [context] contains only whitelisted keys. */
function contextIsSafe(context) {
    for (const key of Object.keys(context ?? {})) {
        if (!CONTEXT_WHITELIST.has(key))
            return false;
    }
    return true;
}
/** Validates that candidate metadata carries only whitelisted keys. */
function candidateMetaIsSafe(meta) {
    if (!meta)
        return true;
    for (const key of Object.keys(meta)) {
        if (!CANDIDATE_META_WHITELIST.has(key))
            return false;
    }
    return true;
}
//# sourceMappingURL=ai.rerank.dto.js.map