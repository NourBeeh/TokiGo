"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.CONVERSATION_FACT_LIMITS = exports.CONVERSATION_FACT_KINDS = void 0;
exports.conversationFactKey = conversationFactKey;
exports.validateConversationFact = validateConversationFact;
exports.conversationKindFromKey = conversationKindFromKey;
const memory_dto_1 = require("../../common/dto/memory.dto");
const budget_currency_1 = require("./budget_currency");
exports.CONVERSATION_FACT_KINDS = [
    'preferred_destination',
    'preferred_budget',
    'preferred_travel_style',
];
/** Field limits from the Phase 2C vocabulary decision. */
exports.CONVERSATION_FACT_LIMITS = {
    /** preferred_destination.destination max chars. */
    destinationMax: 80,
    /** preferred_travel_style.styles array item cap. */
    stylesMaxItems: 60,
    /** Single style string max chars (sanity bound per item). */
    styleMaxChars: 60,
    /** preferred_budget.currency max chars (ISO 4217). */
    budgetCurrencyMax: 3,
};
const SHAPES = {
    preferred_destination: {
        kind: 'preferred_destination',
        fields: { destination: 'string' },
        suffixed: true,
    },
    preferred_budget: {
        kind: 'preferred_budget',
        // Phase 4B: the currency is OPTIONAL and part of the vocabulary — a
        // budget may be stated without one ("up to 300"), and the app never
        // converts prices silently, so a currency-less budget filters nothing.
        fields: { min: 'number', max: 'number', currency: 'string' },
        suffixed: false,
    },
    preferred_travel_style: {
        kind: 'preferred_travel_style',
        fields: { styles: 'string[]' },
        suffixed: false,
    },
};
/** Builds the memory key for [kind] + [subject] (subject slugified). */
function conversationFactKey(kind, subject) {
    const shape = SHAPES[kind];
    const slug = subject
        .toLowerCase()
        .trim()
        .replace(/[^a-z0-9\u0600-\u06FF]+/g, '-')
        .replace(/^-+|-+$/g, '');
    return shape.suffixed ? `${kind}:${slug}` : kind;
}
/**
 * Validates a candidate explicit fact against its kind's exact shape:
 * - every field must be one of the declared fields (no extras),
 * - types must match, limits must hold (destination ≤ 80 chars, styles ≤ 60 items),
 * - at least one declared field must be present,
 * - the Phase 2A sensitive scanner must pass.
 *
 * Pure and total: NEVER throws — invalid facts come back as {valid: false}.
 */
function validateConversationFact(kind, value) {
    const shape = SHAPES[kind];
    if (!shape) {
        return { valid: false, error: `Unknown conversation fact kind: ${kind}` };
    }
    if (!value || typeof value !== 'object' || Array.isArray(value)) {
        return { valid: false, error: 'Fact value must be an object.' };
    }
    if ((0, memory_dto_1.containsSensitiveData)(value)) {
        return { valid: false, error: 'Fact value contains sensitive keys.' };
    }
    for (const [field, raw] of Object.entries(value)) {
        const expected = shape.fields[field];
        if (!expected) {
            return { valid: false, error: `Unexpected field "${field}" for ${kind}.` };
        }
        if (expected === 'string' && typeof raw !== 'string') {
            return { valid: false, error: `Field "${field}" must be a string.` };
        }
        if (expected === 'number' && !isFiniteNumber(raw)) {
            return { valid: false, error: `Field "${field}" must be a number.` };
        }
        if (expected === 'string[]') {
            if (!Array.isArray(raw) ||
                raw.some((entry) => typeof entry !== 'string' || entry.length === 0)) {
                return { valid: false, error: `Field "${field}" must be a string array.` };
            }
        }
    }
    // Kind-specific limits.
    if (kind === 'preferred_destination') {
        const destination = value.destination;
        if (destination !== undefined && destination.length > exports.CONVERSATION_FACT_LIMITS.destinationMax) {
            return {
                valid: false,
                error: `Field "destination" exceeds ${exports.CONVERSATION_FACT_LIMITS.destinationMax} characters.`,
            };
        }
        if (destination !== undefined && destination.trim().length === 0) {
            return { valid: false, error: 'Field "destination" must not be empty.' };
        }
        // Phase 2D: free-text values must be SINGLE-LINE — CR/LF and other
        // control characters let a stored value forge new prompt lines when the
        // fact is later rendered into the AI context block.
        if (destination !== undefined && /[\u0000-\u001f\u007f]/.test(destination)) {
            return {
                valid: false,
                error: 'Field "destination" must not contain control characters.',
            };
        }
    }
    if (kind === 'preferred_budget') {
        // Phase 4B: a currency is OPTIONAL. A supported ISO 4217 code is stored
        // uppercase; an unusable one is DROPPED (the bounds survive) — the app
        // never converts a price, so a currency it does not know must simply not
        // be applied. A wrong TYPE is still a malformed fact.
        const rawCurrency = value.currency;
        if (rawCurrency !== undefined) {
            const currency = (0, budget_currency_1.normalizeBudgetCurrency)(rawCurrency);
            if (currency) {
                value = { ...value, currency };
            }
            else {
                const { currency: _dropped, ...rest } = value;
                value = rest;
            }
        }
    }
    if (kind === 'preferred_travel_style') {
        const styles = value.styles;
        if (styles !== undefined && styles.length > exports.CONVERSATION_FACT_LIMITS.stylesMaxItems) {
            return {
                valid: false,
                error: `Field "styles" exceeds ${exports.CONVERSATION_FACT_LIMITS.stylesMaxItems} items.`,
            };
        }
        if (styles !== undefined && styles.length === 0) {
            return { valid: false, error: 'Field "styles" must not be empty.' };
        }
        if (styles !== undefined &&
            styles.some((s) => s.length > exports.CONVERSATION_FACT_LIMITS.styleMaxChars)) {
            return {
                valid: false,
                error: `A style exceeds ${exports.CONVERSATION_FACT_LIMITS.styleMaxChars} characters.`,
            };
        }
        // Phase 2D: same single-line rule per style item (line-forgery guard).
        if (styles !== undefined && styles.some((s) => /[\u0000-\u001f\u007f]/.test(s))) {
            return {
                valid: false,
                error: 'A style must not contain control characters.',
            };
        }
    }
    // At least one declared field must be present.
    const hasAny = Object.keys(shape.fields).some((f) => f in value);
    if (!hasAny) {
        return {
            valid: false,
            error: `Fact ${kind} requires at least one of: ${Object.keys(shape.fields).join(', ')}.`,
        };
    }
    return { valid: true, value };
}
function isFiniteNumber(raw) {
    return typeof raw === 'number' && Number.isFinite(raw);
}
/**
 * Extracts the base kind from a stored memory key (`null` when unknown).
 * Mirrors behavioralKindFromKey.
 */
function conversationKindFromKey(key) {
    const base = key.split(':')[0];
    return exports.CONVERSATION_FACT_KINDS.includes(base)
        ? base
        : null;
}
//# sourceMappingURL=conversation_facts.js.map