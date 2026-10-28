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
var RelevantMemorySelector_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.RelevantMemorySelector = void 0;
exports.relevanceScore = relevanceScore;
exports.tokenize = tokenize;
const common_1 = require("@nestjs/common");
const memory_service_1 = require("./memory.service");
const conversation_facts_1 = require("./conversation_facts");
/**
 * Relevant Memory Selector (Phase 2C-A).
 *
 * Server-side read helper for the FUTURE AI-context integration (Phase 2C-B):
 * given the user's next message, return a SMALL, relevant subset of their
 * explicit conversation memories — never a full dump.
 *
 * Phase boundary: this selector is pure read logic over the memory spine.
 * It does NOT touch DerivedPreferenceProfile, Home Ranking, or any AI
 * prompt yet. Nothing in Phase 2C-A sends memories to OpenRouter.
 *
 * Safety contract:
 * - Reads ONLY type='conversation' + source='ai_conversation' rows —
 *   behavioral memories (Phase 2B) are invisible here by construction.
 * - Ownership: every query goes through MemoryService.listForUser(userId)
 *   so rows from other users can never appear.
 * - Expiration: expired rows are hidden (Phase 2A listing default).
 * - Deterministic relevance (no ML/embeddings): keyword overlap between
 *   the message tokens and the fact's own text, then recency as the
 *   tiebreaker (the listing is already updatedAt DESC).
 * - Bounded output: capped at `maxMemories` (default 5).
 */
let RelevantMemorySelector = class RelevantMemorySelector {
    static { RelevantMemorySelector_1 = this; }
    memories;
    logger = new common_1.Logger(RelevantMemorySelector_1.name);
    /** Hard output cap — the caller gets a small subset, not a dump. */
    static DEFAULT_MAX_MEMORIES = 5;
    constructor(memories) {
        this.memories = memories;
    }
    /**
     * Returns the explicit conversation memories relevant to [message], capped
     * and ordered by relevance (keyword overlap) then recency. Degrades to []
     * on any failure — a selector problem must never break an AI query.
     */
    async selectRelevant(userId, message, maxMemories = RelevantMemorySelector_1.DEFAULT_MAX_MEMORIES) {
        try {
            const rows = await this.memories.listForUser(userId, {
                type: 'conversation',
                source: 'ai_conversation',
            });
            const cap = Math.max(1, Math.min(maxMemories, 20));
            if (rows.length === 0)
                return [];
            const tokens = tokenize(message);
            if (tokens.size === 0) {
                // Degenerate input (no usable tokens) → nothing can be relevant.
                return [];
            }
            const scored = rows
                .map((row) => ({ row, score: relevanceScore(row, tokens) }))
                .filter((entry) => entry.score > 0)
                .sort((a, b) => b.score !== a.score
                ? b.score - a.score
                : // rows arrive updatedAt DESC — stable, deterministic tiebreak.
                    0);
            // STRICT relevance (Phase 2C-B): an irrelevant memory never travels to
            // the AI. No "recent fallback" — absence of a match is the correct
            // answer, not a reason to dump the newest rows.
            return scored.slice(0, cap).map((entry) => entry.row);
        }
        catch (error) {
            this.logger.warn(`Relevant memory selection skipped: ${error.message}`);
            return [];
        }
    }
};
exports.RelevantMemorySelector = RelevantMemorySelector;
exports.RelevantMemorySelector = RelevantMemorySelector = RelevantMemorySelector_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [memory_service_1.MemoryService])
], RelevantMemorySelector);
/**
 * Deterministic keyword overlap between the message and a memory's own
 * fields (destination text, budget numbers, style words). Pure — no model,
 * no embeddings. A fact scores >0 only when at least one of its own tokens
 * appears in the message.
 */
function relevanceScore(row, tokens) {
    const value = (row.value ?? {});
    let score = 0;
    const kind = (0, conversation_facts_1.conversationKindFromKey)(row.key);
    const destination = typeof value.destination === 'string' ? value.destination : '';
    if (destination) {
        for (const token of tokenize(destination)) {
            if (tokens.has(token))
                score += 2;
        }
    }
    const styles = Array.isArray(value.styles) ? value.styles : [];
    for (const style of styles) {
        if (typeof style === 'string') {
            for (const token of tokenize(style)) {
                if (tokens.has(token))
                    score += 1;
            }
        }
    }
    // Budget relevance: a budget fact is relevant when the message mentions
    // price/budget vocabulary; the numbers themselves are never stringified.
    if (kind === 'preferred_budget') {
        const messageText = [...tokens].join(' ');
        if (/(budget|price|cheap|expensive|cost|ميزانية|سعر|تكلفة)/i.test(messageText)) {
            score += 1;
        }
    }
    return score;
}
/** Lowercases, strips punctuation, and keeps Arabic + Latin word tokens. */
function tokenize(text) {
    const raw = (text ?? '').toLowerCase();
    const tokens = new Set();
    for (const match of raw.matchAll(/[a-z0-9\u0600-\u06FF]+/g)) {
        const token = match[0];
        // Skip bare numbers and single letters — noise for keyword matching.
        if (token.length > 1 || /[\u0600-\u06FF]/.test(token)) {
            tokens.add(token);
        }
    }
    return tokens;
}
//# sourceMappingURL=relevant_memory_selector.js.map