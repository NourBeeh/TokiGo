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
var ConversationMemoryService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.EXTRACTOR_SYSTEM_PROMPT = exports.ConversationMemoryService = void 0;
exports.parseExplicitFacts = parseExplicitFacts;
const common_1 = require("@nestjs/common");
const ai_provider_1 = require("../ai/ai.provider");
const memory_service_1 = require("./memory.service");
const conversation_facts_1 = require("./conversation_facts");
/**
 * Explicit AI Conversation Memory extraction (Phase 2C-A).
 *
 * One user message in an AI conversation → typed, whitelisted EXPLICIT facts,
 * upserted through the Phase 2A MemoryService with
 *   type   = 'conversation'
 *   source = 'ai_conversation'
 *
 * Design invariants (phase decision):
 * - EXPLICIT ONLY: the extractor prompt forbids inference; a fact is saved
 *   only when the user STATED it in this message. Behavioural guessing is
 *   the Phase 2B pipeline's job and never touches this store.
 * - NO raw transcripts: the persisted value is the small typed fact, never
 *   the message text or the AI's answer.
 * - ISOLATION (§ events pattern): extraction failure NEVER fails the AI
 *   response. The caller wraps this in try/catch; this service also logs
 *   and swallows its own AI-call failures so the caller's contract stays
 *   "throws nothing" in practice.
 * - LOG SAFETY: logs carry kinds and counts only — never fact values.
 *
 * Phase boundary: this phase does NOT send memories into the /ai/query
 * prompt; that wiring (RelevantMemorySelector → AI context) is the next
 * phase (2C-B). Here the selector is only exercised by unit tests.
 */
let ConversationMemoryService = ConversationMemoryService_1 = class ConversationMemoryService {
    memories;
    ai;
    logger = new common_1.Logger(ConversationMemoryService_1.name);
    constructor(memories, ai) {
        this.memories = memories;
        this.ai = ai;
    }
    /**
     * Extracts explicit facts from ONE user message and upserts them.
     * Returns the extracted-and-saved memories (possibly []). NEVER throws
     * to the caller on provider/parse/validation problems — invalid facts are
     * skipped and logged by kind, never by value.
     *
     * [ai] (tests / future callers) overrides the injected provider — used by
     * the Phase 2C-B specs to drive extraction deterministically.
     */
    async extractFromMessage(userId, message, ai) {
        const provider = ai ?? this.ai;
        const trimmed = (message ?? '').trim();
        if (!trimmed || !provider)
            return [];
        let facts;
        try {
            facts = await this.detectExplicitFacts(trimmed, provider);
        }
        catch (error) {
            this.logger.warn(`Explicit memory extraction skipped: ${error.message}`);
            return [];
        }
        const saved = [];
        for (const fact of facts) {
            try {
                saved.push(await this.saveFact(userId, fact));
            }
            catch (error) {
                this.logger.warn(`Explicit memory fact rejected (${fact.kind}): ${error.message}`);
            }
        }
        if (saved.length > 0) {
            this.logger.log(`explicit memory saved kinds=${saved.map((m) => m.key).length}`);
        }
        return saved;
    }
    /**
     * Saves ONE validated explicit fact via the Phase 2A upsert
     * (userId + type + key) — re-recording the same preference updates the
     * existing row instead of piling duplicates.
     */
    async saveFact(userId, fact) {
        const validation = (0, conversation_facts_1.validateConversationFact)(fact.kind, fact.value);
        if (!validation.valid) {
            throw new Error(validation.error);
        }
        const key = (0, conversation_facts_1.conversationFactKey)(fact.kind, fact.kind === 'preferred_destination'
            ? String(fact.value.destination ?? '')
            : fact.kind);
        return this.memories.upsert(userId, {
            type: 'conversation',
            key,
            // Phase 4B: the SANITIZED value is stored (a supported currency is
            // normalized, an unusable one is dropped) — never the raw model output.
            value: validation.value ?? fact.value,
            source: 'ai_conversation',
            confidence: 1, // The user said it themselves — no decay ladder applies.
        });
    }
    /**
     * Asks the provider to detect EXPLICIT statements only. The prompt is a
     * closed contract: only three fact kinds, only what the user literally
     * stated in THIS message, JSON only. The contract rides the provider's
     * system prompt (Phase 2C-B signature) so the user message itself stays
     * a clean, isolated input.
     */
    async detectExplicitFacts(message, provider) {
        const prompt = `User message: ${message}`;
        const response = await provider.generate(prompt, exports.EXTRACTOR_SYSTEM_PROMPT);
        return parseExplicitFacts(response.text ?? '');
    }
};
exports.ConversationMemoryService = ConversationMemoryService;
exports.ConversationMemoryService = ConversationMemoryService = ConversationMemoryService_1 = __decorate([
    (0, common_1.Injectable)(),
    __param(1, (0, common_1.Optional)()),
    __param(1, (0, common_1.Inject)(ai_provider_1.AI_PROVIDER)),
    __metadata("design:paramtypes", [memory_service_1.MemoryService, Object])
], ConversationMemoryService);
/** Closed extractor contract (system-prompt tier, Phase 2C-B). */
exports.EXTRACTOR_SYSTEM_PROMPT = [
    'You extract EXPLICIT travel preferences that the user states about THEMSELVES.',
    'Rules:',
    '- Save ONLY what the user explicitly says in this message (first person).',
    '- NEVER infer, guess, or derive from behaviour, context, or the assistant.',
    '- If the message contains no explicit self-stated preference, return an empty list.',
    '- For a budget, record the currency ONLY when the user states it (e.g. "up to 300 USD"). NEVER convert, guess or assume a currency.',
    '- Allowed fact kinds and value shapes:',
    `  preferred_destination: { "destination": string (max ${conversation_facts_1.CONVERSATION_FACT_LIMITS.destinationMax} chars) }`,
    '  preferred_budget: { "min"?: number, "max"?: number, "currency"?: string (ISO 4217 code, ONLY when the user states it) }',
    `  preferred_travel_style: { "styles": string[] (max ${conversation_facts_1.CONVERSATION_FACT_LIMITS.stylesMaxItems} items) }`,
    '- NO other kinds. NO other fields.',
    'Return ONLY a JSON object, no prose:',
    '{"facts": [{"kind": "preferred_destination | preferred_budget | preferred_travel_style", "value": { ... }}]}',
    'Example of no preference: {"facts": []}',
].join('\n');
/**
 * Parses the extractor's JSON answer against the strict vocabulary.
 * Malformed output, unknown kinds, or non-object values yield [] — never a
 * throw (the caller treats extraction as best-effort).
 */
function parseExplicitFacts(text) {
    const trimmed = (text ?? '').trim();
    if (!trimmed)
        return [];
    const brace = trimmed.indexOf('{');
    const close = trimmed.lastIndexOf('}');
    if (brace < 0 || close <= brace)
        return [];
    let parsed;
    try {
        parsed = JSON.parse(trimmed.slice(brace, close + 1));
    }
    catch {
        return [];
    }
    const record = parsed;
    if (!record || typeof record !== 'object' || !Array.isArray(record.facts)) {
        return [];
    }
    const out = [];
    for (const raw of record.facts) {
        const entry = raw;
        if (!entry || typeof entry !== 'object')
            continue;
        const kind = entry.kind;
        const value = entry.value;
        if (typeof kind !== 'string' ||
            !conversation_facts_1.CONVERSATION_FACT_KINDS.includes(kind)) {
            continue;
        }
        if (!value || typeof value !== 'object' || Array.isArray(value)) {
            continue;
        }
        out.push({ kind: kind, value: value });
    }
    return out;
}
//# sourceMappingURL=conversation_memory.service.js.map