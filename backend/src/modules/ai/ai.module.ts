import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

import { AI_PROVIDER, AiProvider } from './ai.provider';
import { AiController } from './ai.controller';
import { AiRerankController } from './ai.rerank.controller';
import { AiService } from './ai.service';
import { OpenAiAiProvider } from './openai.ai.provider';
import { DuffelService } from '../duffel/duffel.service';
import { DuffelModule } from '../duffel/duffel.module';

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
@Module({
  imports: [DuffelModule],
  controllers: [AiController, AiRerankController],
  providers: [
    AiService,
    {
      provide: AI_PROVIDER,
      inject: [ConfigService],
      useFactory: (config: ConfigService) => {
        return new OpenAiAiProvider(config);
      },
    },
  ],
  exports: [AI_PROVIDER, AiService],
})
export class AiModule {}
