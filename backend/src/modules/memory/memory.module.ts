import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { UserMemory } from '../../database/entities/user_memory.entity';
import { MemoryService } from './memory.service';
import { MemoryController } from './memory.controller';
import { BehavioralMemoryService } from './behavioral_memory.service';
import { DerivedPreferenceProfileService } from './derived_preference_profile.service';
import { ConversationMemoryService } from './conversation_memory.service';
import { RelevantMemorySelector } from './relevant_memory_selector';
import { ExplicitPreferenceSignalService } from './explicit_preference_signal.service';

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
@Module({
  imports: [TypeOrmModule.forFeature([UserMemory])],
  controllers: [MemoryController],
  providers: [
    MemoryService,
    BehavioralMemoryService,
    DerivedPreferenceProfileService,
    ConversationMemoryService,
    RelevantMemorySelector,
    ExplicitPreferenceSignalService,
  ],
  exports: [
    MemoryService,
    BehavioralMemoryService,
    DerivedPreferenceProfileService,
    ConversationMemoryService,
    RelevantMemorySelector,
    ExplicitPreferenceSignalService,
  ],
})
export class MemoryModule {}
