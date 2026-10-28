import { Module } from '@nestjs/common';

import { AiModule } from './ai.module';
import { AiConversationController } from './ai.conversation.controller';
import { MemoryModule } from '../memory/memory.module';
import { ProfileModule } from '../profile/profile.module';
import { AuthModule } from '../auth/auth.module';

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
@Module({
  imports: [AiModule, MemoryModule, ProfileModule, AuthModule],
  controllers: [AiConversationController],
})
export class AiConversationModule {}
