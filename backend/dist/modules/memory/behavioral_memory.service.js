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
var BehavioralMemoryService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.BehavioralMemoryService = void 0;
const common_1 = require("@nestjs/common");
const behavioral_facts_1 = require("./behavioral_facts");
const memory_service_1 = require("./memory.service");
/**
 * Behavioral Memory extraction (Phase 2B).
 *
 * Turns ONE incoming behavioural event into typed, whitelisted memory facts
 * and upserts them through the Phase 2A MemoryService — never a new row per
 * event, never raw payloads, never AI-computed confidence.
 *
 * Failure contract (§19): extraction problems are logged and swallowed by
 * the CALLER (EventsService). An event succeeding must never depend on
 * memory derivation succeeding.
 */
let BehavioralMemoryService = BehavioralMemoryService_1 = class BehavioralMemoryService {
    memories;
    logger = new common_1.Logger(BehavioralMemoryService_1.name);
    constructor(memories) {
        this.memories = memories;
    }
    /**
     * Extracts the typed facts for one event. Returns [] when the payload
     * cannot support any fact (absence is NOT a negative signal — §10).
     * THROWS on invalid facts so the caller's catch can isolate the failure.
     */
    async extractFromEvent(userId, type, payload) {
        switch (type) {
            case 'hotel_search':
                return this._fromHotelSearch(userId, payload);
            case 'hotel_view':
                return this._fromHotelView(userId, payload);
            case 'hotel_favorite':
                return this._fromHotelFavorite(userId, payload);
            case 'trip_planned':
                return this._fromTripPlanned(userId, payload);
            case 'booking_confirmed':
                return this._fromBookingConfirmed(userId, payload);
            default:
                return [];
        }
    }
    async _fromHotelSearch(userId, payload) {
        // Validate EVERYTHING first — extraction is atomic: either all the
        // event's facts are recorded or none are (a bad price never leaves a
        // half-written destination fact behind).
        const destination = asString(payload?.destination);
        const min = payload?.minPrice !== undefined || payload?.maxPrice !== undefined
            ? asPrice(payload?.minPrice)
            : undefined;
        const max = payload?.maxPrice !== undefined || payload?.minPrice !== undefined
            ? asPrice(payload?.maxPrice)
            : undefined;
        const out = [];
        if (destination) {
            out.push(await this._upsertFact(userId, 'preferred_destination', destination, {
                destination,
            }));
        }
        if (payload?.minPrice !== undefined || payload?.maxPrice !== undefined) {
            out.push(await this._upsertBudget(userId, { min, max }));
        }
        return out;
    }
    async _fromHotelView(userId, payload) {
        const hotelId = asString(payload?.hotelId);
        const title = asString(payload?.title);
        if (!hotelId && !title)
            return [];
        const subject = hotelId || title;
        return [
            await this._upsertFact(userId, 'recent_viewed_hotel', subject, { ...(hotelId ? { hotelId } : {}), ...(title ? { title } : {}) }, 0.35),
        ];
    }
    async _fromHotelFavorite(userId, payload) {
        const hotelId = asString(payload?.hotelId);
        const title = asString(payload?.title);
        if (!hotelId && !title)
            return [];
        const subject = hotelId || title;
        return [
            await this._upsertFact(userId, 'favorite_hotel', subject, { ...(hotelId ? { hotelId } : {}), ...(title ? { title } : {}) }, 0.6),
        ];
    }
    async _fromTripPlanned(userId, payload) {
        const destination = asString(payload?.destination);
        if (!destination)
            return [];
        return [
            await this._upsertFact(userId, 'planned_destination', destination, {
                destination,
            }),
        ];
    }
    async _fromBookingConfirmed(userId, payload) {
        // The STRONGEST behavioural signal (§7): a confirmed booking reinforces
        // the destination preference at booking-level confidence. Only
        // payload-present data is used — no checkout fields that do not exist
        // in the event.
        const destination = asString(payload?.destination);
        if (!destination)
            return [];
        return [
            await this._upsertFact(userId, 'preferred_destination', destination, { destination }, 0.9),
        ];
    }
    /** Budget facts merge with the existing memory (new price wins per side). */
    async _upsertBudget(userId, patch) {
        const key = (0, behavioral_facts_1.behavioralFactKey)('preferred_budget', 'main');
        const existing = await this.memories.findBehavioral(userId, key);
        const current = (existing?.value ?? {});
        const merged = {
            ...(current.min !== undefined ? { min: current.min } : {}),
            ...(current.max !== undefined ? { max: current.max } : {}),
            ...(patch.min !== undefined ? { min: patch.min } : {}),
            ...(patch.max !== undefined ? { max: patch.max } : {}),
        };
        const validation = (0, behavioral_facts_1.validateBehavioralFact)('preferred_budget', merged);
        if (!validation.valid) {
            throw new Error(validation.error);
        }
        const confidence = (0, behavioral_facts_1.nextConfidence)(existing?.confidence, 0.5);
        return this.memories.upsert(userId, {
            type: 'behavior',
            key,
            value: merged,
            source: 'behavior_event',
            confidence,
        });
    }
    async _upsertFact(userId, kind, subject, value, baseConfidence) {
        const validation = (0, behavioral_facts_1.validateBehavioralFact)(kind, value);
        if (!validation.valid) {
            throw new Error(validation.error);
        }
        const key = (0, behavioral_facts_1.behavioralFactKey)(kind, subject);
        const existing = await this.memories.findBehavioral(userId, key);
        const confidence = (0, behavioral_facts_1.nextConfidence)(existing?.confidence, baseConfidence ?? defaultBase(kind));
        return this.memories.upsert(userId, {
            type: 'behavior',
            key,
            value,
            source: 'behavior_event',
            confidence,
        });
    }
};
exports.BehavioralMemoryService = BehavioralMemoryService;
exports.BehavioralMemoryService = BehavioralMemoryService = BehavioralMemoryService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [memory_service_1.MemoryService])
], BehavioralMemoryService);
/** Default base confidence when a fact kind has no per-event override. */
function defaultBase(kind) {
    switch (kind) {
        case 'preferred_destination':
            return 0.3; // search-level default
        case 'recent_viewed_hotel':
            return 0.35;
        case 'favorite_hotel':
            return 0.6;
        case 'planned_destination':
            return 0.75;
        case 'preferred_budget':
            return 0.5;
    }
}
function asString(raw) {
    if (typeof raw !== 'string')
        return undefined;
    const trimmed = raw.trim();
    return trimmed.length > 0 && trimmed.length <= 120 ? trimmed : undefined;
}
/** Present-but-wrongly-typed price fields are a hard error (never silent). */
function asPrice(raw) {
    if (raw === undefined || raw === null)
        return undefined;
    if (typeof raw !== 'number' || !Number.isFinite(raw)) {
        throw new Error('Price fields must be numbers.');
    }
    return raw;
}
//# sourceMappingURL=behavioral_memory.service.js.map