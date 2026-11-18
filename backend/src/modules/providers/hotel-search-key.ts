import { createHash } from 'crypto';

/**
 * Live hotel-search cache identity (high-load refactor, Phase 1).
 *
 * The key MUST contain every parameter that can change the provider result or
 * the displayed price: check-in/out, room count, adults, children's ages,
 * display currency, market, country, guest nationality and the filters that
 * shape the offer list. Normalisation happens here so two spellings of the
 * same search (`rooms: null` vs `rooms: 1`, `Cairo` vs `  cAIro `, date-time
 * vs date-only) share one entry.
 *
 * Key layout: `hotels:{city}:{checkin_date}:{sha256}` — the mandated base key
 * followed by a digest of the remaining normalised parameters. The digest
 * keeps Redis key length bounded no matter how many filters are sent.
 */

/** Spec-mandated live-search TTL: presentation acceleration only. */
export const HOTEL_SEARCH_CACHE_TTL_SECONDS = 45;

/** How long a fetcher may hold the distributed lock before it expires. */
export const HOTEL_SEARCH_LOCK_TTL_MS = 20_000;

/** How long a lock loser waits for the winner's cache entry before falling back. */
export const HOTEL_SEARCH_WAIT_MS = 1_500;

export interface HotelSearchKeyParams {
  city?: string;
  checkIn?: string | Date;
  checkOut?: string | Date;
  guests?: number | null;
  rooms?: number | null;
  occupancies?: Array<{ adults: number; children?: number[] }> | null;
  currency?: string | null;
  market?: string | null;
  country?: string | null;
  /** Guest residency/nationality required by the provider (default EG). */
  nationality?: string | null;
  language?: string | null;
  minRating?: number | null;
  maxPrice?: number | null;
  minPrice?: number | null;
  amenities?: string[] | null;
}

/** Default guest nationality used by the Nuitee rates request today. */
export const DEFAULT_GUEST_NATIONALITY = 'EG';
/** Launch market used when the caller did not select one. */
export const DEFAULT_KEY_MARKET = 'EG';

function isoDay(value: string | Date | undefined | null): string {
  if (value === undefined || value === null) return '';
  if (value instanceof Date) return value.toISOString().slice(0, 10);
  const trimmed = String(value).trim();
  const match = /^(\d{4}-\d{2}-\d{2})([T ].*)?$/.exec(trimmed);
  return match ? match[1] : trimmed;
}

function normalizeCity(city: unknown): string {
  return String(city ?? '')
    .trim()
    .replace(/\s+/g, ' ')
    .toLowerCase();
}

/**
 * Redis-safe slug for the human-readable prefix. Latin and Arabic letters,
 * digits, underscore and dash survive; everything else becomes `-`.
 */
function slug(value: string): string {
  const slugified = value
    .replace(/[^\p{L}\p{N}_-]+/gu, '-')
    .replace(/-{2,}/g, '-')
    .replace(/^-+|-+$/g, '');
  return slugified || 'unknown';
}

/**
 * Canonical, comparable parameter set for a hotel search.
 * Returns a plain object with stable key insertion order.
 */
export function normalizeHotelSearchForCacheKey(
  params: HotelSearchKeyParams,
  marketOverride?: string,
  currencyOverride?: string,
): Record<string, unknown> {
  const p = params ?? ({} as HotelSearchKeyParams);

  const occupancies = Array.isArray(p.occupancies)
    ? p.occupancies.filter(
        (o) => o && typeof o.adults === 'number' && o.adults > 0,
      )
    : [];

  let rooms: number;
  let adults: number;
  let childrenAges: number[];
  if (occupancies.length > 0) {
    rooms = occupancies.length;
    adults = occupancies.reduce((sum, o) => sum + (o.adults ?? 0), 0);
    childrenAges = occupancies
      .flatMap((o) => (Array.isArray(o.children) ? o.children : []))
      .filter((age) => typeof age === 'number' && Number.isFinite(age))
      .sort((a, b) => a - b);
  } else {
    rooms = Math.max(1, Math.floor(Number(p.rooms ?? 1)) || 1);
    adults = Math.max(1, Math.floor(Number(p.guests ?? 2)) || 2);
    childrenAges = [];
  }

  const currency = String(currencyOverride ?? p.currency ?? '')
    .trim()
    .toUpperCase();
  const market = String(marketOverride ?? p.market ?? DEFAULT_KEY_MARKET)
    .trim()
    .toUpperCase();
  const country = String(p.country ?? '').trim().toUpperCase();
  const nationality = String(p.nationality ?? DEFAULT_GUEST_NATIONALITY)
    .trim()
    .toUpperCase();
  const language = p.language === 'ar' ? 'ar' : p.language === 'en' ? 'en' : '';

  const out: Record<string, unknown> = {
    city: normalizeCity(p.city),
    checkin: isoDay(p.checkIn),
    checkout: isoDay(p.checkOut),
    rooms,
    adults,
    children: childrenAges,
    currency,
    market,
    country,
    nationality,
    language,
  };

  // Result-shaping filters. Omitted/null and explicit "no filter" are equal.
  const minRating = finiteOrNull(p.minRating);
  const maxPrice = finiteOrNull(p.maxPrice);
  const minPrice = finiteOrNull(p.minPrice);
  if (minRating !== null) out.minRating = minRating;
  if (maxPrice !== null) out.maxPrice = maxPrice;
  if (minPrice !== null) out.minPrice = minPrice;

  if (Array.isArray(p.amenities) && p.amenities.length > 0) {
    out.amenities = p.amenities
      .map((a) => String(a).trim().toLowerCase())
      .filter(Boolean)
      .sort();
  }

  return out;
}

function finiteOrNull(value: unknown): number | null {
  const n = Number(value);
  return Number.isFinite(n) && n >= 0 ? n : null;
}

/**
 * Final cache key: `hotels:{city}:{checkin_date}:{sha256}`.
 */
export function hotelSearchCacheKey(
  params: HotelSearchKeyParams,
  marketOverride?: string,
  currencyOverride?: string,
): string {
  const canonical = normalizeHotelSearchForCacheKey(
    params,
    marketOverride,
    currencyOverride,
  );
  const digest = createHash('sha256')
    .update(JSON.stringify(canonical))
    .digest('hex');
  return `hotels:${slug(normalizeCity(canonical.city))}:${canonical.checkin}:${digest}`;
}
