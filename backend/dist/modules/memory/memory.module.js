"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.MemoryModule = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const user_memory_entity_1 = require("../../database/entities/user_memory.entity");
const memory_service_1 = require("./memory.service");
const memory_controller_1 = require("./memory.controller");
const behavioral_memory_service_1 = require("./behavioral_memory.service");
const derived_preference_profile_service_1 = require("./derived_preference_profile.service");
const conversation_memory_service_1 = require("./conversation_memory.service");
const relevant_memory_selector_1 = require("./relevant_memory_selector");
const explicit_preference_signal_service_1 = require("./explicit_preference_signal.service");
/**
 * Memory Spine module (Phase 2A Foundation + 2B behavioural layer +
 * 2C-A explicit AI conversation layer).
 *
 * 2A exposes the JWT-scoped user-facing API. 2B adds the behavioural
 * extraction + derived-preference read model. 2C-A adds explicit
 * conversation-memory extraction (AI-assisted, strict 3-fact vocabulary)
 * and the RelevantMemorySelector read helper — conversation memories are
 * stored with type='conversation' + source='ai_conversation' so they stay
 * isolated from the 2B behavioural store. The AI-context wiring (selector
 * → /ai/query prompt) is deliberately NOT here; it lands in Phase 2C-B.
 *
 * PH-7 adds the ExplicitPreferenceSignalService: a SEPARATE, additive read
 * adapter that lets explicit conversation memories influence Home Ranking
 * without ever being folded into DerivedPreferenceProfile or converted to
 * behavioural rows.
 */
let MemoryModule = class MemoryModule {
};
exports.MemoryModule = MemoryModule;
exports.MemoryModule = MemoryModule = __decorate([
    (0, common_1.Module)({
        imports: [typeorm_1.TypeOrmModule.forFeature([user_memory_entity_1.UserMemory])],
        controllers: [memory_controller_1.MemoryController],
        providers: [
            memory_service_1.MemoryService,
            behavioral_memory_service_1.BehavioralMemoryService,
            derived_preference_profile_service_1.DerivedPreferenceProfileService,
            conversation_memory_service_1.ConversationMemoryService,
            relevant_memory_selector_1.RelevantMemorySelector,
            explicit_preference_signal_service_1.ExplicitPreferenceSignalService,
        ],
        exports: [
            memory_service_1.MemoryService,
            behavioral_memory_service_1.BehavioralMemoryService,
            derived_preference_profile_service_1.DerivedPreferenceProfileService,
            conversation_memory_service_1.ConversationMemoryService,
            relevant_memory_selector_1.RelevantMemorySelector,
            explicit_preference_signal_service_1.ExplicitPreferenceSignalService,
        ],
    })
], MemoryModule);
//# sourceMappingURL=memory.module.js.map