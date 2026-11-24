/**
 * Pure geographic helpers for Nearby Stays (R1/R2).
 *
 * No database, no clock and no provider calls live here: every function is
 * deterministic so the radius expansion, distance measurement and ranking can
 * be unit-tested without infrastructure.
 */

/** Mean Earth radius in kilometres (the value the Flutter app uses too). */
export const EARTH_RADIUS_KM = 6371;

/**
 * Configurable radius expansion stages, in kilometres.
 *
 * The product's ladder is the default. `NEARBY_RADIUS_STAGES` may override it
 * (comma-separated, ascending, each > 0 and <= 75) for a market that needs a
 * different shape; an invalid value falls back to the default rather than
 * silently disabling expansion or searching beyond the product limit.
 */
export const DEFAULT_RADIUS_STAGES_KM: readonly number[] = [5, 10, 20, 35, 50, 75];

/**
 * Hard product ceiling for Nearby Stays. No configured stage may exceed it,
 * and no hotel farther than the final stage is ever returned.
 */
export const MAX_NEARBY_RADIUS_KM = 75;

/** Kilometres per degree of latitude (a good equirectangular approximation). */
const KM_PER_DEGREE_LAT = 111.32;

export function isValidLatitude(value: unknown): value is number {
  return typeof value === 'number' && Number.isFinite(value) && value >= -90 && value <= 90;
}

export function isValidLongitude(value: unknown): value is number {
  return typeof value === 'number' && Number.isFinite(value) && value >= -180 && value <= 180;
}

export function isValidCoordinate(latitude: unknown, longitude: unknown): boolean {
  return isValidLatitude(latitude) && isValidLongitude(longitude);
}

/** Great-circle distance in kilometres. */
export function haversineKm(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number,
): number {
  const toRad = (deg: number): number => (deg * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) *
      Math.cos(toRad(lat2)) *
      Math.sin(dLng / 2) *
      Math.sin(dLng / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  const distance = EARTH_RADIUS_KM * c;
  return Number.isFinite(distance) ? distance : 0;
}

export interface GeoPoint {
  latitude: number;
  longitude: number;
}

export interface BoundingBox {
  minLat: number;
  maxLat: number;
  minLng: number;
  maxLng: number;
}

/**
 * Latitude/longitude bounding box around [center] for a radius search.
 *
 * The box is deliberately generous (it is only a prefilter): the exact
 * haversine test runs afterwards. Longitude degrees shrink toward the poles,
 * so the span uses `cos(latitude)` clamped away from zero; the clamp only
 * widens the box, never narrows it.
 */
export function boundingBox(center: GeoPoint, radiusKm: number): BoundingBox {
  const latSpan = radiusKm / KM_PER_DEGREE_LAT;
  const cosLat = Math.max(0.01, Math.abs(Math.cos((center.latitude * Math.PI) / 180)));
  const lngSpan = radiusKm / (KM_PER_DEGREE_LAT * cosLat);
  return {
    minLat: Math.max(-90, center.latitude - latSpan),
    maxLat: Math.min(90, center.latitude + latSpan),
    minLng: center.longitude - lngSpan,
    maxLng: center.longitude + lngSpan,
  };
}

/**
 * Radius stages actually used. Environment override is validated: ascending,
 * positive, finite, at most [MAX_NEARBY_RADIUS_KM], at most 12 stages. Invalid
 * input falls back to the default ladder — the product ceiling is never
 * exceeded.
 */
export function radiusStagesKm(): number[] {
  const raw = process.env.NEARBY_RADIUS_STAGES?.trim();
  if (!raw) return [...DEFAULT_RADIUS_STAGES_KM];
  const parts = raw
    .split(',')
    .map((part) => Number(part.trim()))
    .filter(
      (value) =>
        Number.isFinite(value) && value > 0 && value <= MAX_NEARBY_RADIUS_KM,
    );
  const rawCount = raw.split(',').filter((part) => part.trim()).length;
  if (parts.length !== rawCount || parts.length < 2 || parts.length > 12) {
    return [...DEFAULT_RADIUS_STAGES_KM];
  }
  const ascending = parts.every((value, index) => index === 0 || value > parts[index - 1]);
  if (!ascending) return [...DEFAULT_RADIUS_STAGES_KM];
  return parts;
}

/** Stable, bounded cache-key fragment for a center (≈11 m resolution). */
export function centerKey(latitude: number, longitude: number): string {
  return `${latitude.toFixed(4)},${longitude.toFixed(4)}`;
}

/** The first radius stage — the search always starts nearby. */
export function initialRadiusKm(): number {
  return radiusStagesKm()[0];
}

export interface NightWindow {
  /** `YYYY-MM-DD` check-in. */
  checkIn: string;
  /** `YYYY-MM-DD` check-out (the next calendar day). */
  checkOut: string;
}

/**
 * Exactly seven consecutive ONE-NIGHT windows starting at [fromDate].
 *
 * The provider quotes a rate for a window; a one-night window makes the
 * quoted amount a nightly rate, so no stay total is ever divided by a window
 * the traveller never chose. Dates are calendar dates in [timeZone] (default
 * UTC), computed with UTC arithmetic so a DST transition cannot skip or
 * duplicate a day.
 */
export function sevenOneNightWindows(fromDate: Date | string, timeZone = 'UTC'): NightWindow[] {
  const start =
    typeof fromDate === 'string' ? parseDateParts(fromDate) : zonedDateParts(fromDate, timeZone);
  const windows: NightWindow[] = [];
  for (let index = 0; index < 7; index += 1) {
    const checkIn = addDays(start, index);
    const checkOut = addDays(start, index + 1);
    windows.push({ checkIn: formatDateParts(checkIn), checkOut: formatDateParts(checkOut) });
  }
  return windows;
}

/** `YYYY-MM-DD` parts of [date] as a calendar date in [timeZone]. */
function zonedDateParts(date: Date, timeZone: string): DateParts {
  const formatter = new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  });
  const parts = formatter.formatToParts(date);
  const get = (type: string): string => parts.find((part) => part.type === type)?.value ?? '0';
  return {
    year: Number(get('year')),
    month: Number(get('month')),
    day: Number(get('day')),
  };
}

/** Parses a strict `YYYY-MM-DD` string into calendar parts, or null. */
function parseDateParts(value: string): DateParts {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value.trim());
  if (!match) {
    // Invalid input: the caller treats this as "today" by passing a Date, so
    // this branch is unreachable for validated input. Fall back to UTC now.
    return zonedDateParts(new Date(), 'UTC');
  }
  return { year: Number(match[1]), month: Number(match[2]), day: Number(match[3]) };
}

function addDays(parts: DateParts, days: number): DateParts {
  const shifted = new Date(Date.UTC(parts.year, parts.month - 1, parts.day + days));
  return {
    year: shifted.getUTCFullYear(),
    month: shifted.getUTCMonth() + 1,
    day: shifted.getUTCDate(),
  };
}

function formatDateParts(parts: DateParts): string {
  const month = String(parts.month).padStart(2, '0');
  const day = String(parts.day).padStart(2, '0');
  return `${parts.year}-${month}-${day}`;
}

interface DateParts {
  year: number;
  month: number;
  day: number;
}
