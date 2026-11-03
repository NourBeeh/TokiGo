import { Body, Controller, Post } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import {
  AiQueryDto,
  AiResponseDto,
  AiSuggestDto,
  AiSuggestResponseDto,
} from '../../common/dto/ai.dto';
import { AiService } from './ai.service';

@Controller('ai')
export class AiController {
  constructor(private readonly aiService: AiService) {}

  /** POST /ai/query → normalized, provider-agnostic AiResponseDto. */
  @Post('query')
  @Throttle({ default: { ttl: 60000, limit: 10 } })
  async query(@Body() dto: AiQueryDto): Promise<AiResponseDto> {
    return this.aiService.query(dto.prompt, dto.context);
  }

  /** POST /ai/suggest → fast typeahead prompts for the smart search sheet. */
  @Post('suggest')
  @Throttle({ default: { ttl: 60000, limit: 10 } })
  async suggest(@Body() dto: AiSuggestDto): Promise<AiSuggestResponseDto> {
    return { suggestions: await this.aiService.suggest(dto.query) };
  }
}