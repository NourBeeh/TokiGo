"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.CONFIDENCE_MAX = exports.REPEAT_BOOST = exports.SIGNAL_BASE_CONFIDENCE = exports.BEHAVIORAL_FACT_KINDS = void 0;
exports.behavioralFactKey = behavioralFactKey;
exports.behavioralKindFromKey = behavioralKindFromKey;
exports.validateBehavioralFact = validateBehavioralFact;
exports.effectiveConfidence = effectiveConfidence;
exports.nextConfidence = nextConfidence;
const memory_dto_1 = require("../../common/dto/memory.dto");
exports.BEHAVIORAL_FACT_KINDS = [
    'preferred_destination',
    'preferred_budget',
    'recent_viewed_hotel',
    'favorite_hotel',
    'planned_destination',
];
/** Deterministic base confidence per signal kind (§8 ladder). */
exports.SIGNAL_BASE_CONFIDENCE = {
    search: 0.3,
    view: 0.35,
    favorite: 0.6,
    trip_planned: 0.75,
    booking: 0.9,
};
/** Confidence boost on a repeated observation of the SAME fact. */
exports.REPEAT_BOOST = 0.1;
/** Confidence hard ceiling — inflation beyond 1.0 is impossible. */
exports.CONFIDENCE_MAX = 1;
const SHAPES = {
    preferred_destination: {
        kind: 'preferred_destination',
        fields: { destination: 'string' },
        maxLength: { destination: 80 },
        suffixed: true,
    },
    preferred_budget: {
        kind: 'preferred_budget',
        fields: { min: 'number', max: 'number' },
        maxLength: {},
        suffixed: false,
    },
    recent_viewed_hotel: {
        kind: 'recent_viewed_hotel',
        fields: { hotelId: 'string', title: 'string' },
        maxLength: { hotelId: 120, title: 120 },
        suffixed: true,
    },
    favorite_hotel: {
        kind: 'favorite_hotel',
        fields: { hotelId: 'string', title: 'string' },
        maxLength: { hotelId: 120, title: 120 },
        suffixed: true,
    },
    planned_destination: {
        kind: 'planned_destination',
        fields: { destination: 'string' },
        maxLength: { destination: 80 },
        suffixed: true,
    },
};
/** Builds the memory key for [kind] + [subject] (subject slugified). */
function behavioralFactKey(kind, subject) {
    const shape = SHAPES[kind];
    const slug = subject
        .toLowerCase()
        .trim()
        .replace(/[^a-z0-9\u0600-\u06FF]+/g, '-')
        .replace(/^-+|-+$/g, '');
    return shape.suffixed ? `${kind}:${slug}` : kind;
}
/** Extracts the base kind from a stored key (`null` when unknown). */
function behavioralKindFromKey(key) {
    const base = key.split(':')[0];
    return exports.BEHAVIORAL_FACT_KINDS.includes(base)
        ? base
        : null;
}
/**
 * Validates a candidate fact value against its kind's exact shape:
 * - every field must be one of the declared fields,
 * - types must match, string lengths must hold,
 * - the sensitive scanner (Phase 2A) must pass.
 */
function validateBehavioralFact(kind, value) {
    const shape = SHAPES[kind];
    if (!shape) {
        return { valid: false, error: `Unknown behavioral fact kind: ${kind}` };
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
        if (expected === 'number' && typeof raw !== 'number') {
            return { valid: false, error: `Field "${field}" must be a number.` };
        }
        if (expected === 'string') {
            const max = shape.maxLength[field] ?? 80;
            if (raw.length > max) {
                return {
                    valid: false,
                    error: `Field "${field}" exceeds ${max} characters.`,
                };
            }
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
/**
 * Time decay for behavioral confidence (§11) — PURE and deterministic:
 *
 *   effectiveConfidence = storedConfidence × exp(-ageDays / 30)
 *
 * Computed ONLY at read/derivation time; the stored confidence is never
 * rewritten and no cron/job exists. A 30-day half-life keeps recent signals
 * strong while stale ones fade — reproducible for identical inputs.
 */
function effectiveConfidence(storedConfidence, updatedAt, now = new Date()) {
    const ageMs = now.getTime() - new Date(updatedAt).getTime();
    const ageDays = Math.max(0, ageMs / 86_400_000);
    return Math.max(0, Math.min(exports.CONFIDENCE_MAX, storedConfidence * Math.exp(-ageDays / 30)));
}
/**
 * Deterministic repeat-confidence step (§9): a repeated observation of the
 * SAME fact pushes the stored confidence up by [REPEAT_BOOST] but never
 * above the harder of (existing, signal base) + boost, and never above 1.0.
 * Monotonic and reproducible: same event sequence → same result.
 */
function nextConfidence(existingConfidence, baseConfidence) {
    const existing = existingConfidence ?? 0;
    // Ladder semantics (§8/§9), monotonic and bounded at 1.0:
    // - first observation  → the signal's base confidence;
    // - stronger new signal → climbs to at least its own base
    //   (search 0.3 → favorite 0.6 → booking 0.9);
    // - same-strength repeat → +0.1 boost;
    // - strictly weaker new observation → the recorded value is untouched
    //   (a fresh search after a booking never inflates the booking signal).
    let next = existing;
    if (existing === 0 || baseConfidence > existing) {
        next = baseConfidence;
    }
    else if (baseConfidence >= existing) {
        next = existing + exports.REPEAT_BOOST;
    }
    return round6(Math.min(exports.CONFIDENCE_MAX, next));
}
function round6(value) {
    return Math.round(value * 1e6) / 1e6;
}
//# sourceMappingURL=behavioral_facts.js.map