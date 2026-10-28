import { IsNotEmpty, IsString, MaxLength, IsOptional, IsObject, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';

/** Geolocation coordinates for context-aware AI queries */
export class GeolocationDto {
  @IsOptional()
  lat?: number;
  
  @IsOptional()
  lng?: number;
}

/** Travel date range for context-aware AI queries */
export class TravelDatesDto {
  @IsOptional()
  from?: string; // ISO 8601 date string
  
  @IsOptional()
  to?: string; // ISO 8601 date string
}

/** Full context object for AI queries, matching Flutter's AiQueryContext */
export class AiContextDto {
  @IsString()
  route!: string;
  
  @IsOptional()
  @IsString()
  screenTitle?: string;
  
  @IsOptional()
  selectedOfferIds?: string[];
  
  @IsOptional()
  @ValidateNested()
  @Type(() => GeolocationDto)
  geolocation?: GeolocationDto;
  
  @IsOptional()
  @ValidateNested()
  @Type(() => TravelDatesDto)
  travelDates?: TravelDatesDto;
  
  @IsOptional()
  metadata?: Record<string, any>;
}

/** POST /ai/query request body. White-listed by the global ValidationPipe. */
export class AiQueryDto {
  @IsString()
  @IsNotEmpty({ message: 'prompt must not be empty' })
  @MaxLength(4000, { message: 'prompt must be at most 4000 characters' })
  prompt!: string;

  @IsOptional()
  @ValidateNested()
  @Type(() => AiContextDto)
  context?: AiContextDto;
}

/**
 * POST /ai/suggest request body — live typeahead for the smart search sheet.
 * `query` is deliberately short: this is a partial prompt, not a full one.
 */
export class AiSuggestDto {
  @IsString()
  @IsNotEmpty({ message: 'query must not be empty' })
  @MaxLength(120, { message: 'query must be at most 120 characters' })
  query!: string;
}

/** POST /ai/suggest response — short, display-ready prompt suggestions. */
export interface AiSuggestResponseDto {
  suggestions: string[];
}

/**
 * POST /ai/chat request body (Phase 2C-B). Same prompt contract as
 * AiQueryDto; the endpoint itself is JWT-only and enriches the call with
 * the caller's relevant explicit conversation memories server-side.
 */
export class AiChatDto {
  @IsString()
  @IsNotEmpty({ message: 'prompt must not be empty' })
  @MaxLength(4000, { message: 'prompt must be at most 4000 characters' })
  prompt!: string;

  @IsOptional()
  @ValidateNested()
  @Type(() => AiContextDto)
  context?: AiContextDto;
}

/**
 * Normalized, provider-agnostic AI response contract.
 *
 * Field names mirror the Flutter AiResponse contract exactly so the mobile
 * side can parse this payload with `AiResponse.fromMap()` regardless of which
 * upstream AI provider (Grok/Gemini/DeepSeek/...) produced it.
 */
export interface AiResponseDto {
  /** Natural-language content preceding/around the sections. */
  text?: string;
  /** Ordered semantic blocks; each becomes a section on the AI surface. */
  sections: AiSectionDto[];
  /** Response-level metadata. MUST NOT identify the underlying provider. */
  metadata?: Record<string, any>;
}

export interface AiSectionDto {
  id?: string;
  title: string;
  subtitle?: string;
  /** vertical | horizontal | horizontalPeek | grid */
  layout: 'vertical' | 'horizontal' | 'horizontalPeek' | 'grid';
  items: AiItemDto[];
  /** Explicit ordering hint among sibling sections. */
  order?: number;
  metadata?: Record<string, any>;
}

export interface AiItemDto {
  id: string;
  /** hotel | flight | car | package | destination | deal | experience | story */
  type: string;
  title: string;
  subtitle?: string;
  description?: string;
  imageUrl?: string;
  price?: number;
  currency?: string;
  rating?: number;
  reviewCount?: number;
  badge?: string;
  highlights?: string[];
  tags?: string[];
  actionLabel?: string;
  rawPrice?: number;
  order?: number;
  /** Type-specific card extras (e.g. flight `route`). */
  data?: Record<string, any>;
  /** Future action envelope (book / view / call...). */
  actions?: AiActionDto[];
  metadata?: Record<string, any>;
}

export interface AiActionDto {
  type: string;
  label?: string;
  payload?: Record<string, any>;
}