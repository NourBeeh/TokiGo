import {
  IsArray,
  IsBoolean,
  IsDateString,
  IsIn,
  IsInt,
  IsObject,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  MinLength,
  Validate,
  ValidationArguments,
  ValidatorConstraint,
  ValidatorConstraintInterface,
} from 'class-validator';
import { TRAVEL_MOODS } from '../travel_mood';

function hasValidDestinationMoods(value: unknown, required: boolean): boolean {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    return false;
  }
  const content = value as Record<string, unknown>;
  if (content.metadata === undefined) return !required;
  if (
    content.metadata === null ||
    typeof content.metadata !== 'object' ||
    Array.isArray(content.metadata)
  ) {
    return false;
  }
  const moods = (content.metadata as Record<string, unknown>).moods;
  if (moods === undefined) return !required;
  return (
    Array.isArray(moods) &&
    moods.length > 0 &&
    moods.length <= TRAVEL_MOODS.length &&
    new Set(moods).size === moods.length &&
    moods.every(
      (mood) =>
        typeof mood === 'string' &&
        (TRAVEL_MOODS as readonly string[]).includes(mood),
    )
  );
}

@ValidatorConstraint({ name: 'createDestinationMoods', async: false })
class CreateDestinationMoodsConstraint implements ValidatorConstraintInterface {
  validate(value: unknown, args: ValidationArguments): boolean {
    const cardType = (args.object as { cardType?: unknown }).cardType;
    return hasValidDestinationMoods(value, cardType === 'destination');
  }

  defaultMessage(): string {
    return `Destination moods must be a non-empty unique array of: ${TRAVEL_MOODS.join(', ')}.`;
  }
}

@ValidatorConstraint({ name: 'validDestinationMoods', async: false })
class ValidDestinationMoodsConstraint implements ValidatorConstraintInterface {
  validate(value: unknown): boolean {
    return hasValidDestinationMoods(value, false);
  }

  defaultMessage(): string {
    return `Moods must be a non-empty unique array of: ${TRAVEL_MOODS.join(', ')}.`;
  }
}

/** Section layouts exactly as the Flutter Home repository parses them. */
export const SECTION_LAYOUTS = [
  'horizontal',
  'horizontalpeek',
  'grid',
  'vertical',
] as const;

/** Card types exactly as HomeCardType on the Flutter side. */
export const CARD_TYPES = [
  'flight',
  'hotel',
  'car',
  'package',
  'destination',
  'deal',
] as const;

/** Content lifecycle: drafts stay invisible to the public home feed. */
export const CONTENT_STATUSES = ['draft', 'published'] as const;

export class CreateSectionDto {
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  title!: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  subtitle?: string;

  @IsIn(SECTION_LAYOUTS as unknown as string[])
  layout!: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  order?: number;

  @IsOptional()
  @IsBoolean()
  isVisible?: boolean;

  @IsOptional()
  @IsIn(CONTENT_STATUSES as unknown as string[])
  status?: string;

  /** Publication time: the public feed hides the section until then. */
  @IsOptional()
  @IsDateString()
  publishAt?: string;

  @IsOptional()
  @IsDateString()
  expiresAt?: string;
}

export class UpdateSectionDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  title?: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  subtitle?: string;

  @IsOptional()
  @IsIn(SECTION_LAYOUTS as unknown as string[])
  layout?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  order?: number;

  @IsOptional()
  @IsBoolean()
  isVisible?: boolean;

  @IsOptional()
  @IsIn(CONTENT_STATUSES as unknown as string[])
  status?: string;

  @IsOptional()
  @IsDateString()
  publishAt?: string;

  @IsOptional()
  @IsDateString()
  expiresAt?: string;
}

export class CreateCardDto {
  @IsString()
  @MinLength(1)
  sectionId!: string;

  @IsIn(CARD_TYPES as unknown as string[])
  cardType!: string;

  /** Presentation payload: title/price/rating/... (flattened by HomeService). */
  @IsObject()
  @Validate(CreateDestinationMoodsConstraint)
  content!: Record<string, any>;

  @IsOptional()
  @IsInt()
  @Min(0)
  order?: number;

  @IsOptional()
  @IsBoolean()
  isVisible?: boolean;

  @IsOptional()
  @IsIn(CONTENT_STATUSES as unknown as string[])
  status?: string;

  @IsOptional()
  @IsDateString()
  publishAt?: string;

  @IsOptional()
  @IsDateString()
  expiresAt?: string;
}

export class UpdateCardDto {
  @IsOptional()
  @IsIn(CARD_TYPES as unknown as string[])
  cardType?: string;

  /** Partial patch: provided keys are merged into the persisted content. */
  @IsOptional()
  @IsObject()
  @Validate(ValidDestinationMoodsConstraint)
  content?: Record<string, any>;

  @IsOptional()
  @IsInt()
  @Min(0)
  order?: number;

  @IsOptional()
  @IsBoolean()
  isVisible?: boolean;

  @IsOptional()
  @IsIn(CONTENT_STATUSES as unknown as string[])
  status?: string;

  @IsOptional()
  @IsDateString()
  publishAt?: string;

  @IsOptional()
  @IsDateString()
  expiresAt?: string;
}

export class ReorderDto {
  /** Entity ids in their new display order. */
  @IsArray()
  @IsString({ each: true })
  ids!: string[];
}

export class UpdateProviderStatusDto {
  @IsBoolean()
  isActive!: boolean;
}

export class UpdateProviderPriorityDto {
  @IsInt()
  @Min(0)
  priority!: number;
}

export class UpdateProviderConfigDto {
  @IsObject()
  config!: Record<string, any>;
}
