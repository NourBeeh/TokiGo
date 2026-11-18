import { IsInt, IsOptional, Max, Min } from 'class-validator';
import { Type } from 'class-transformer';

/** Default page size for every paginated list endpoint. */
export const DEFAULT_PAGE_LIMIT = 20;

/** Hard ceiling; overridable per endpoint via env when truly needed. */
export const MAX_PAGE_LIMIT = 100;

/**
 * Offset pagination contract shared by list endpoints.
 *
 * Cursor pagination remains available where a repository needs it (large,
 * frequently changing sets); this DTO keeps response metadata consistent for
 * the current bounded lists.
 */
export class PaginationDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(MAX_PAGE_LIMIT)
  limit?: number = DEFAULT_PAGE_LIMIT;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  offset?: number = 0;
}

/** Clamp an arbitrary limit to [1, max] without trusting the caller. */
export function clampLimit(raw: unknown, max: number = MAX_PAGE_LIMIT): number {
  const n = Math.floor(Number(raw));
  if (!Number.isFinite(n) || n <= 0) return DEFAULT_PAGE_LIMIT;
  return Math.min(n, max);
}

export function clampOffset(raw: unknown): number {
  const n = Math.floor(Number(raw));
  if (!Number.isFinite(n) || n < 0) return 0;
  return n;
}

export interface PageMeta {
  total: number;
  limit: number;
  offset: number;
  hasMore: boolean;
}

export function pageMeta(total: number, limit: number, offset: number): PageMeta {
  return { total, limit, offset, hasMore: offset + limit < total };
}
