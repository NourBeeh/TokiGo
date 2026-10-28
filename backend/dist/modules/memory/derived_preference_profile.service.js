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
var DerivedPreferenceProfileService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.DerivedPreferenceProfileService = void 0;
const common_1 = require("@nestjs/common");
const memory_service_1 = require("./memory.service");
const behavioral_facts_1 = require("./behavioral_facts");
/**
 * Derived Preference Profile (Phase 2B) — a COMPUTED read model, never
 * persisted as its own memory: building it twice from the same inputs yields
 * the same output, and the underlying behavioral memories stay the single
 * source of truth.
 *
 * Aggregation sources (one bounded memory query + the existing profile):
 * - behavioral memories (type='behavior'; expired rows already hidden by
 *   the Phase 2A default listing),
 * - the R-4 profile (explicit preferences outrank everything; derived
 *   topDestinations/budget are the legacy fallbacks).
 *
 * Conflict ladder (§14 — deterministic, never random):
 *   explicit profile preference
 *   > confirmed booking behaviour
 *   > favourite
 *   > trip planned
 *   > repeated recent behaviour
 *   > single view / single search
 *   > geo/discovery
 *
 * Only fields derivable from today's payloads exist here. preferredCountries,
 * preferredHotelStars, and travelPatterns are deliberately ABSENT — the
 * events carry no country/stars/pattern data (§13: unreliable → excluded).
 */
let DerivedPreferenceProfileService = DerivedPreferenceProfileService_1 = class DerivedPreferenceProfileService {
    memories;
    logger = new common_1.Logger(DerivedPreferenceProfileService_1.name);
    constructor(memories) {
        this.memories = memories;
    }
    async buildForUser(userId, profile) {
        // ONE bounded query: the user's behavioral memories, expired hidden.
        const rows = await this.memories.listForUser(userId, {
            type: 'behavior',
            source: 'behavior_event',
        });
        const destinations = new Map();
        const favoriteHotels = [];
        const recentDestinations = [];
        let budget;
        const seenRecent = new Set();
        for (const row of rows) {
            const kind = (0, behavioral_facts_1.behavioralKindFromKey)(row.key);
            const value = (row.value ?? {});
            const eff = (0, behavioral_facts_1.effectiveConfidence)(row.confidence ?? 0, row.updatedAt);
            switch (kind) {
                case 'preferred_destination': {
                    const name = String(value.destination ?? '');
                    if (!name)
                        break;
                    const entry = destinations.get(name);
                    // The stored confidence already encodes the ladder (booking rows
                    // carry a higher base than view/search rows); take the strongest
                    // observation per destination and apply read-time decay.
                    const confidence = Math.max(entry?.confidence ?? 0, eff);
                    destinations.set(name, {
                        name,
                        confidence,
                        source: entry?.source ?? 'behavior_event',
                    });
                    break;
                }
                case 'planned_destination': {
                    const name = String(value.destination ?? '');
                    if (!name)
                        break;
                    const entry = destinations.get(name);
                    const confidence = Math.max(entry?.confidence ?? 0, eff);
                    destinations.set(name, {
                        name,
                        confidence,
                        source: 'trip_planned',
                    });
                    break;
                }
                case 'favorite_hotel': {
                    const hotelId = String(value.hotelId ?? '');
                    const title = value.title ? String(value.title) : undefined;
                    if (hotelId || title) {
                        favoriteHotels.push({ hotelId: hotelId || title, title });
                    }
                    break;
                }
                case 'preferred_budget': {
                    budget = {
                        ...(value.min !== undefined ? { min: Number(value.min) } : {}),
                        ...(value.max !== undefined ? { max: Number(value.max) } : {}),
                    };
                    break;
                }
                default:
                    break; // recent_viewed_hotel: not a preference — only a recall aid.
            }
            // recentDestinations: any destination-bearing fact, most recent first
            // (rows arrive updatedAt DESC from the Phase 2A listing contract).
            const recentName = String(value.destination ?? (kind === 'planned_destination' ? '' : ''));
            if (recentName && !seenRecent.has(recentName)) {
                seenRecent.add(recentName);
                recentDestinations.push(recentName);
            }
        }
        // R-4 legacy derived signals fold in BELOW memory-based signals (the
        // memory spine records why/when; the profile fold is the coarse legacy).
        const legacyTop = (profile.derived?.topDestinations ?? []);
        for (const name of legacyTop) {
            if (!destinations.has(name)) {
                destinations.set(name, {
                    name,
                    confidence: 0.25, // Legacy fold: single-search-strength floor.
                    source: 'profile_derived',
                });
            }
        }
        // Explicit profile destinations (if the user set any) outrank all
        // behavioural signals — the §14 ladder apex, and events NEVER create
        // explicit preferences (§14 note).
        const explicitDests = (profile.preferences?.preferredDestinations ??
            []);
        for (const name of explicitDests) {
            destinations.set(name, {
                name,
                confidence: 1,
                source: 'user_explicit',
            });
        }
        const topDestinations = [...destinations.values()]
            .sort((a, b) => {
            if (Math.abs(b.confidence - a.confidence) > 1e-9) {
                return b.confidence - a.confidence;
            }
            return a.name.localeCompare(b.name); // Deterministic tiebreak.
        })
            .slice(0, 6);
        // Budget ladder: explicit preferences > behavioral memory > legacy fold.
        const explicitMin = asNumber(profile.preferences?.budgetMin);
        const explicitMax = asNumber(profile.preferences?.budgetMax);
        const legacyBudget = (profile.derived?.budget ?? {});
        const budgetRange = {
            min: explicitMin ?? budget?.min ?? asNumber(legacyBudget.min),
            max: explicitMax ?? budget?.max ?? asNumber(legacyBudget.max),
        };
        const hasBudget = budgetRange.min !== undefined || budgetRange.max !== undefined;
        return {
            topDestinations,
            budgetRange: hasBudget ? budgetRange : undefined,
            favoriteHotels: favoriteHotels.slice(0, 20),
            recentDestinations: recentDestinations.slice(0, 5),
        };
    }
    /** Safe wrapper: derivation failure degrades to an empty profile, never
     * breaks the caller (profile endpoint / future context builder). */
    async buildForUserSafe(userId, profile) {
        try {
            return await this.buildForUser(userId, profile);
        }
        catch (error) {
            this.logger.warn(`Derived preference profile failed: ${error.message}`);
            return {
                topDestinations: [],
                favoriteHotels: [],
                recentDestinations: [],
            };
        }
    }
};
exports.DerivedPreferenceProfileService = DerivedPreferenceProfileService;
exports.DerivedPreferenceProfileService = DerivedPreferenceProfileService = DerivedPreferenceProfileService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [memory_service_1.MemoryService])
], DerivedPreferenceProfileService);
function asNumber(raw) {
    return typeof raw === 'number' && Number.isFinite(raw) ? raw : undefined;
}
//# sourceMappingURL=derived_preference_profile.service.js.map