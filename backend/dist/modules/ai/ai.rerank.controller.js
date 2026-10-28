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
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
var AiRerankController_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.AiRerankController = void 0;
const common_1 = require("@nestjs/common");
const ai_provider_1 = require("./ai.provider");
const jwt_auth_guard_1 = require("../auth/jwt-auth.guard");
const ai_rerank_dto_1 = require("../../common/dto/ai.rerank.dto");
/**
 * AI rerank endpoint (Phase 1C — Personalization Spine).
 *
 * Optional enhancement ONLY: the Home composer's deterministic ordering is
 * always the baseline. When the AI answers within the timeout with a
 * well-formed response, its ordering is applied — but only to the ids the
 * request already contained. Any invented id, malformed JSON, provider
 * failure, or timeout degrades to `fallback: true` (the client keeps its
 * deterministic order) without any UI failure.
 *
 * Safety: the context and candidate metadata are validated against strict
 * whitelists BEFORE any AI call — no tokens, PII, payment data, or precise
 * GPS can reach the prompt. The AI never receives or produces product facts
 * beyond reordering the given ids.
 */
let AiRerankController = class AiRerankController {
    static { AiRerankController_1 = this; }
    ai;
    logger = new common_1.Logger(AiRerankController_1.name);
    /** Hard ceiling on the AI call — rerank must never block Home. */
    static aiTimeoutMs = 15_000;
    constructor(ai) {
        this.ai = ai;
    }
    async rerank(dto) {
        if (!(0, ai_rerank_dto_1.contextIsSafe)(dto.context)) {
            throw new common_1.BadRequestException('Context contains non-whitelisted keys.');
        }
        for (const candidate of dto.candidates ?? []) {
            if (!(0, ai_rerank_dto_1.candidateMetaIsSafe)(candidate.metadata)) {
                throw new common_1.BadRequestException('Candidate metadata contains non-whitelisted keys.');
            }
        }
        const knownIds = new Set((dto.candidates ?? []).map((c) => c.id));
        if (knownIds.size === 0) {
            return { rankedCandidateIds: [], sectionReason: 'discovery', fallback: true };
        }
        if (!this.ai) {
            return this.deterministic(dto);
        }
        const prompt = [
            'You are the TokiGo Home reranker.',
            'Reorder the candidate ids by personal relevance to the user context.',
            'Return ONLY a JSON object, no prose:',
            '{"rankedCandidateIds": ["<id1>", "<id2", ...], "sectionReason": "<one of the allowed reasons>", "confidence": 0.0-1.0}',
            'NEVER invent ids, prices, availability, or providers.',
            'Every returned id MUST come from the candidate list.',
            `Allowed sectionReason values: ${JSON.stringify(dto.allowedReasons ?? [])}.`,
            `User context: ${JSON.stringify(dto.context ?? {})}`,
            `Candidates: ${JSON.stringify((dto.candidates ?? []).map((c) => ({
                id: c.id,
                title: c.title,
                ...(c.price !== undefined ? { price: c.price } : {}),
                ...(c.metadata ?? {}),
            })))}`,
        ].join('\n');
        try {
            const response = await withTimeout(this.ai.generate(prompt), AiRerankController_1.aiTimeoutMs);
            const parsed = extractRerank(response.text ?? '');
            if (!parsed) {
                return this.deterministic(dto);
            }
            // Strict validation: any unknown id invalidates the WHOLE response so
            // a hallucinated id can never leak into the Home composition.
            const ranked = (parsed.rankedCandidateIds ?? []).filter((id) => knownIds.has(id));
            if (ranked.length === 0) {
                return this.deterministic(dto);
            }
            const reasonAllowed = (dto.allowedReasons ?? []).includes(parsed.sectionReason);
            return {
                rankedCandidateIds: ranked,
                sectionReason: reasonAllowed
                    ? parsed.sectionReason
                    : 'recommendation',
                confidence: clampConfidence(parsed.confidence),
                fallback: false,
            };
        }
        catch (error) {
            this.logger.warn(`AI rerank skipped: ${error.message}`);
            return this.deterministic(dto);
        }
    }
    /** Deterministic fallback: input order preserved, no AI involved. */
    deterministic(dto) {
        return {
            rankedCandidateIds: (dto.candidates ?? []).map((c) => c.id),
            sectionReason: 'recommendation',
            fallback: true,
        };
    }
};
exports.AiRerankController = AiRerankController;
__decorate([
    (0, common_1.Post)('rerank'),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [ai_rerank_dto_1.AiRerankDto]),
    __metadata("design:returntype", Promise)
], AiRerankController.prototype, "rerank", null);
exports.AiRerankController = AiRerankController = AiRerankController_1 = __decorate([
    (0, common_1.Controller)('ai'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    __param(0, (0, common_1.Inject)(ai_provider_1.AI_PROVIDER)),
    __metadata("design:paramtypes", [Object])
], AiRerankController);
/** Best-effort JSON extraction from the model text (mirrors extractIds). */
function extractRerank(text) {
    const trimmed = (text ?? '').trim();
    const brace = trimmed.indexOf('{');
    const close = trimmed.indexOf('}');
    if (brace < 0 || close <= brace)
        return null;
    try {
        const parsed = JSON.parse(trimmed.slice(brace, close + 1));
        const ids = parsed?.rankedCandidateIds;
        if (!Array.isArray(ids))
            return null;
        return {
            rankedCandidateIds: ids.filter((x) => typeof x === 'string'),
            sectionReason: typeof parsed?.sectionReason === 'string' ? parsed.sectionReason : '',
            confidence: typeof parsed?.confidence === 'number' ? parsed.confidence : undefined,
        };
    }
    catch {
        return null;
    }
}
function clampConfidence(value) {
    if (value === undefined || !Number.isFinite(value))
        return undefined;
    return Math.min(1, Math.max(0, value));
}
function withTimeout(promise, ms) {
    return Promise.race([
        promise,
        new Promise((_, reject) => setTimeout(() => reject(new Error('rerank timeout')), ms)),
    ]);
}
//# sourceMappingURL=ai.rerank.controller.js.map