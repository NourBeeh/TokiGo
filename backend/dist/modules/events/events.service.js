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
var EventsService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.EventsService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const user_event_entity_1 = require("../../database/entities/user_event.entity");
const profile_service_1 = require("../profile/profile.service");
const behavioral_memory_service_1 = require("../memory/behavioral_memory.service");
let EventsService = EventsService_1 = class EventsService {
    events;
    profiles;
    behavioralMemory;
    logger = new common_1.Logger(EventsService_1.name);
    constructor(events, profiles, behavioralMemory) {
        this.events = events;
        this.profiles = profiles;
        this.behavioralMemory = behavioralMemory;
    }
    /** Records a behavioural signal and folds it into the user profile. */
    async track(sig) {
        await this.events.save(this.events.create({
            userId: sig.userId,
            deviceId: sig.userId ? undefined : sig.deviceId,
            type: sig.type,
            payload: sig.payload ?? {},
        }));
        if (!sig.userId)
            return; // Guests: no server memory (Phase 1C decision).
        // Fold signals into the derived profile — never let aggregation failure
        // fail the event itself.
        try {
            await this.applyToProfile(sig);
        }
        catch (error) {
            this.logger.warn(`Profile aggregation skipped (${sig.type}): ${error.message}`);
        }
        // Phase 2B — derive typed behavioral memories from the same event.
        // Isolated by design: memory failure NEVER breaks the event flow (§19).
        const memory = this.behavioralMemory;
        if (memory) {
            try {
                await memory.extractFromEvent(sig.userId, sig.type, sig.payload ?? {});
            }
            catch (error) {
                this.logger.warn(`Behavioral memory extraction skipped (${sig.type}): ${error.message}`);
            }
        }
    }
    async recent(userId, limit = 50) {
        return this.events.find({
            where: { userId },
            order: { createdAt: 'DESC' },
            take: Math.min(Math.max(limit, 1), 200),
        });
    }
    async recentByDevice(deviceId, limit = 50) {
        return this.events.find({
            where: { deviceId },
            order: { createdAt: 'DESC' },
            take: Math.min(Math.max(limit, 1), 200),
        });
    }
    /** Derives profile signals from one event. Throws nothing by design. */
    async applyToProfile(sig) {
        const userId = sig.userId;
        const payload = sig.payload ?? {};
        switch (sig.type) {
            case 'hotel_search': {
                const searches = await this.profiles.getOrCreate(userId);
                const top = searches.derived?.topDestinations ?? [];
                const dest = payload.destination;
                if (dest && typeof dest === 'string') {
                    const next = top.filter((d) => d !== dest);
                    next.unshift(dest);
                    const budget = candidateBudget(searches.derived, payload);
                    await this.profiles.updateDerived(userId, {
                        topDestinations: next.slice(0, 6),
                        lastDestination: dest,
                        budget,
                    });
                }
                break;
            }
            case 'hotel_view': {
                await this.profiles.updateDerived(userId, {
                    lastViewedHotel: payload.hotelId ?? payload.title,
                    viewedAt: new Date().toISOString(),
                });
                break;
            }
            case 'hotel_favorite': {
                if (payload.hotelId) {
                    const profile = await this.profiles.getOrCreate(userId);
                    const favs = profile.derived?.favoriteHotels ?? [];
                    if (!favs.includes(payload.hotelId)) {
                        await this.profiles.updateDerived(userId, {
                            favoriteHotels: [...favs, payload.hotelId].slice(-20),
                        });
                    }
                }
                break;
            }
            case 'booking_confirmed':
            case 'trip_planned': {
                const dest = payload.destination;
                if (dest) {
                    await this.profiles.updateDerived(userId, {
                        upcomingDestination: dest,
                        plannedAt: new Date().toISOString(),
                    });
                }
                break;
            }
        }
    }
};
exports.EventsService = EventsService;
exports.EventsService = EventsService = EventsService_1 = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(user_event_entity_1.UserEvent)),
    __param(2, (0, common_1.Optional)()),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        profile_service_1.ProfileService,
        behavioral_memory_service_1.BehavioralMemoryService])
], EventsService);
function candidateBudget(derived, payload) {
    const current = derived?.budget ?? {};
    const min = typeof payload.minPrice === 'number' ? payload.minPrice : current.min;
    const max = typeof payload.maxPrice === 'number' ? payload.maxPrice : current.max;
    return { min, max };
}
//# sourceMappingURL=events.service.js.map