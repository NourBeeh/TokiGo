"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.AiConversationModule = void 0;
const common_1 = require("@nestjs/common");
const ai_module_1 = require("./ai.module");
const ai_conversation_controller_1 = require("./ai.conversation.controller");
const memory_module_1 = require("../memory/memory.module");
const profile_module_1 = require("../profile/profile.module");
const auth_module_1 = require("../auth/auth.module");
/**
 * Authenticated AI conversation surface (Phase 2C-B).
 *
 * Hosts POST /ai/chat — the JWT-only endpoint that layers the caller's
 * relevant explicit conversation memories onto the AI system prompt and
 * extracts new explicit facts after the response.
 *
 * Kept SEPARATE from AiModule so the base AI module stays database-free
 * (the HTTP integration specs boot AiModule with ConfigModule alone) and
 * so the guest-compatible /ai/query path is untouched.
 */
let AiConversationModule = class AiConversationModule {
};
exports.AiConversationModule = AiConversationModule;
exports.AiConversationModule = AiConversationModule = __decorate([
    (0, common_1.Module)({
        imports: [ai_module_1.AiModule, memory_module_1.MemoryModule, profile_module_1.ProfileModule, auth_module_1.AuthModule],
        controllers: [ai_conversation_controller_1.AiConversationController],
    })
], AiConversationModule);
//# sourceMappingURL=ai.conversation.module.js.map