"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.AiModule = void 0;
const common_1 = require("@nestjs/common");
const config_1 = require("@nestjs/config");
const ai_provider_1 = require("./ai.provider");
const ai_controller_1 = require("./ai.controller");
const ai_rerank_controller_1 = require("./ai.rerank.controller");
const ai_service_1 = require("./ai.service");
const openai_ai_provider_1 = require("./openai.ai.provider");
const duffel_module_1 = require("../duffel/duffel.module");
/**
 * AI module.
 *
 * Uses the real OpenAI-compatible provider (OpenRouter) configured through
 * environment variables (AI_API_KEY / AI_BASE_URL / AI_MODEL).
 *
 * IMPORTANT (test-pinned contract): this module deliberately imports NO
 * database module — the HTTP integration specs boot it with ConfigModule
 * alone. The Phase 2C-B /ai/chat conversation controller therefore lives in
 * AiConversationModule (see ai.conversation.module.ts), NOT here.
 */
let AiModule = class AiModule {
};
exports.AiModule = AiModule;
exports.AiModule = AiModule = __decorate([
    (0, common_1.Module)({
        imports: [duffel_module_1.DuffelModule],
        controllers: [ai_controller_1.AiController, ai_rerank_controller_1.AiRerankController],
        providers: [
            ai_service_1.AiService,
            {
                provide: ai_provider_1.AI_PROVIDER,
                inject: [config_1.ConfigService],
                useFactory: (config) => {
                    return new openai_ai_provider_1.OpenAiAiProvider(config);
                },
            },
        ],
        exports: [ai_provider_1.AI_PROVIDER, ai_service_1.AiService],
    })
], AiModule);
//# sourceMappingURL=ai.module.js.map