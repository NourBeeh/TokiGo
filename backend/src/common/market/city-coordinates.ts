/**
 * Canonical city catalog for TokiGo.
 *
 * ONE source of truth for:
 *  - the customer-facing City Selection picker (served by `GET /geo/cities`);
 *  - city → country → ISO-4217 currency resolution;
 *  - the search centre for a manually selected city;
 *  - the nearest supported city to a GPS fix.
 *
 * These are CITY reference points, never hotel coordinates. A hotel's own
 * position always comes from the provider metadata, and a hotel is never
 * placed at a city centre. Coordinates are approximate public city centres
 * (Wikipedia/geonames-style), not surveyed points.
 *
 * Adding a city here automatically makes it selectable, priced in its
 * country's currency and searchable by Nearby Stays.
 */

import { haversineKm } from '../../modules/nearby/geo';
import { currencyForCountry } from './currency-by-country';

/** Bump when the catalog shape or its contents change. */
export const CITY_CATALOG_VERSION = 1;

export interface CityRecord {
  /** Stable canonical id (`cairo`, `new-york`). Never a display name. */
  id: string;
  /** Canonical English display name. */
  name: string;
  /** ISO-3166-1 alpha-2. */
  countryCode: string;
  /** ISO-4217 derived from the country — never guessed from the name. */
  currency: string;
  latitude: number;
  longitude: number;
  /** Extra lookup keys (Arabic names, common variants, airport-city names). */
  aliases: string[];
}

/** Backwards-compatible coordinate shape used by the Nearby pipeline. */
export interface CityCoordinate {
  latitude: number;
  longitude: number;
  /** ISO-3166-1 alpha-2 country of the city. */
  countryCode: string;
}

interface CitySeed {
  id: string;
  name: string;
  countryCode: string;
  latitude: number;
  longitude: number;
  aliases?: string[];
}

const CITY_SEEDS: readonly CitySeed[] = [
  // Egypt
  { id: 'cairo', name: 'Cairo', countryCode: 'EG', latitude: 30.0444, longitude: 31.2357, aliases: ['القاهرة', 'قاهرة', 'caire'] },
  { id: 'new-cairo', name: 'New Cairo', countryCode: 'EG', latitude: 30.0322, longitude: 31.4769, aliases: ['new cairo', 'القاهرة الجديدة'] },
  { id: 'hurghada', name: 'Hurghada', countryCode: 'EG', latitude: 27.2579, longitude: 33.8116, aliases: ['الغردقة', 'غردقة'] },
  { id: 'sharm-el-sheikh', name: 'Sharm El Sheikh', countryCode: 'EG', latitude: 27.9158, longitude: 34.33, aliases: ['sharm el-sheikh', 'sharm', 'شرم الشيخ', 'شرم'] },
  { id: 'luxor', name: 'Luxor', countryCode: 'EG', latitude: 25.6872, longitude: 32.6396, aliases: ['الأقصر', 'اقصر'] },
  { id: 'aswan', name: 'Aswan', countryCode: 'EG', latitude: 24.0889, longitude: 32.8998, aliases: ['أسوان', 'اسوان'] },
  { id: 'alexandria', name: 'Alexandria', countryCode: 'EG', latitude: 31.2001, longitude: 29.9187, aliases: ['الإسكندرية', 'اسكندرية'] },
  { id: 'marsa-alam', name: 'Marsa Alam', countryCode: 'EG', latitude: 25.0675, longitude: 34.879, aliases: ['مرسى علم'] },
  { id: 'marsa-matruh', name: 'Marsa Matruh', countryCode: 'EG', latitude: 31.3543, longitude: 27.2373, aliases: ['مرسى مطروح'] },

  // Gulf
  { id: 'dubai', name: 'Dubai', countryCode: 'AE', latitude: 25.2048, longitude: 55.2708, aliases: ['دبي'] },
  { id: 'abu-dhabi', name: 'Abu Dhabi', countryCode: 'AE', latitude: 24.4539, longitude: 54.3773, aliases: ['أبوظبي', 'ابو ظبي'] },
  { id: 'riyadh', name: 'Riyadh', countryCode: 'SA', latitude: 24.7136, longitude: 46.6753, aliases: ['الرياض'] },
  { id: 'jeddah', name: 'Jeddah', countryCode: 'SA', latitude: 21.4858, longitude: 39.1925, aliases: ['جدة', 'جده'] },
  { id: 'doha', name: 'Doha', countryCode: 'QA', latitude: 25.2854, longitude: 51.531, aliases: ['الدوحة'] },
  { id: 'kuwait-city', name: 'Kuwait City', countryCode: 'KW', latitude: 29.3759, longitude: 47.9774, aliases: ['kuwait', 'مدينة الكويت'] },
  { id: 'amman', name: 'Amman', countryCode: 'JO', latitude: 31.9539, longitude: 35.9106, aliases: ['عمّان', 'عمان'] },

  // Europe
  { id: 'london', name: 'London', countryCode: 'GB', latitude: 51.5072, longitude: -0.1276, aliases: ['لندن'] },
  { id: 'paris', name: 'Paris', countryCode: 'FR', latitude: 48.8566, longitude: 2.3522, aliases: ['باريس'] },
  { id: 'nice', name: 'Nice', countryCode: 'FR', latitude: 43.7102, longitude: 7.262, aliases: ['نيس'] },
  { id: 'rome', name: 'Rome', countryCode: 'IT', latitude: 41.9028, longitude: 12.4964, aliases: ['roma', 'روما'] },
  { id: 'milan', name: 'Milan', countryCode: 'IT', latitude: 45.4642, longitude: 9.19, aliases: ['milano', 'ميلانو'] },
  { id: 'madrid', name: 'Madrid', countryCode: 'ES', latitude: 40.4168, longitude: -3.7038, aliases: ['مدريد'] },
  { id: 'barcelona', name: 'Barcelona', countryCode: 'ES', latitude: 41.3874, longitude: 2.1686, aliases: ['برشلونة'] },
  { id: 'berlin', name: 'Berlin', countryCode: 'DE', latitude: 52.52, longitude: 13.405, aliases: ['برلين'] },
  { id: 'munich', name: 'Munich', countryCode: 'DE', latitude: 48.1351, longitude: 11.582, aliases: ['münchen', 'munchen', 'ميونخ'] },
  { id: 'athens', name: 'Athens', countryCode: 'GR', latitude: 37.9838, longitude: 23.7275, aliases: ['أثينا', 'اثينا'] },
  { id: 'istanbul', name: 'Istanbul', countryCode: 'TR', latitude: 41.0082, longitude: 28.9784, aliases: ['إسطنبول', 'اسطنبول'] },
  { id: 'antalya', name: 'Antalya', countryCode: 'TR', latitude: 36.8969, longitude: 30.7133, aliases: ['أنطاليا', 'انطاليا'] },

  // Asia / America
  { id: 'bangkok', name: 'Bangkok', countryCode: 'TH', latitude: 13.7563, longitude: 100.5018, aliases: ['بانكوك'] },
  { id: 'singapore', name: 'Singapore', countryCode: 'SG', latitude: 1.3521, longitude: 103.8198, aliases: ['سنغافورة'] },
  { id: 'kuala-lumpur', name: 'Kuala Lumpur', countryCode: 'MY', latitude: 3.139, longitude: 101.6869, aliases: ['kl', 'كوالالمبور'] },
  { id: 'tokyo', name: 'Tokyo', countryCode: 'JP', latitude: 35.6762, longitude: 139.6503, aliases: ['طوكيو'] },
  { id: 'new-york', name: 'New York', countryCode: 'US', latitude: 40.7128, longitude: -74.006, aliases: ['nyc', 'new york city', 'نيويورك'] },
  { id: 'miami', name: 'Miami', countryCode: 'US', latitude: 25.7617, longitude: -80.1918, aliases: ['ميامي'] },
];

function buildCatalog(): CityRecord[] {
  return CITY_SEEDS.map((seed) => {
    const currency = currencyForCountry(seed.countryCode);
    if (!currency) {
      throw new Error(
        `City catalog: no ISO-4217 currency for ${seed.countryCode} (${seed.name})`,
      );
    }
    return {
      id: seed.id,
      name: seed.name,
      countryCode: seed.countryCode,
      currency,
      latitude: seed.latitude,
      longitude: seed.longitude,
      aliases: seed.aliases ?? [],
    };
  });
}

/** Every selectable city, in stable catalog order. */
export const CITY_CATALOG: readonly CityRecord[] = buildCatalog();

const BY_ID = new Map<string, CityRecord>(CITY_CATALOG.map((city) => [city.id, city]));

function normalizeCityName(value: unknown): string {
  return String(value ?? '')
    .trim()
    .toLowerCase()
    .replace(/[’']/g, '')
    .replace(/\s+/g, ' ');
}

const BY_KEY = new Map<string, CityRecord>();
for (const city of CITY_CATALOG) {
  BY_KEY.set(normalizeCityName(city.id), city);
  BY_KEY.set(normalizeCityName(city.name), city);
  for (const alias of city.aliases) {
    BY_KEY.set(normalizeCityName(alias), city);
  }
}

/** Looks up a canonical city by its stable id. */
export function cityById(id: unknown): CityRecord | null {
  const key = normalizeCityName(id);
  if (!key) return null;
  return BY_ID.get(key) ?? null;
}

/**
 * Matches a name/alias to a catalog city. When [countryCode] is supplied the
 * match is constrained to that country, so "Alexandria" cannot resolve to the
 * wrong country by accident.
 */
export function matchCity(
  name: unknown,
  countryCode?: string | null,
): CityRecord | null {
  const key = normalizeCityName(name);
  if (!key) return null;
  const country = countryCode?.trim().toUpperCase();
  const direct = BY_KEY.get(key);
  if (direct && (!country || direct.countryCode === country)) return direct;
  if (!country) return null;
  // Fall back to a catalog scan so a country-constrained alias still matches
  // even if a duplicate name exists in another country.
  for (const city of CITY_CATALOG) {
    if (city.countryCode !== country) continue;
    if (normalizeCityName(city.name) === key) return city;
    if (city.aliases.some((alias) => normalizeCityName(alias) === key)) {
      return city;
    }
  }
  return null;
}

/** The default currency for a city id/name, or null when unknown. */
export function currencyForCity(value: unknown): string | null {
  return matchCity(value)?.currency ?? cityById(value)?.currency ?? null;
}

/**
 * Looks up a user-selected city. Returns null for an unknown city.
 * Kept for the existing Nearby call sites; new code should use [matchCity].
 */
export function cityCoordinate(value: unknown): CityCoordinate | null {
  const city = matchCity(value) ?? cityById(value);
  if (!city) return null;
  return {
    latitude: city.latitude,
    longitude: city.longitude,
    countryCode: city.countryCode,
  };
}

/**
 * Nearest supported city to a GPS/IP fix, within [maxRadiusKm].
 * Returns null when no supported city is close enough — the caller then
 * reports an honest empty result rather than searching a distant city.
 */
export function nearestCity(
  latitude: number,
  longitude: number,
  maxRadiusKm: number,
): { name: string; countryCode: string; distanceKm: number } | null {
  const best = nearestCityWithin(latitude, longitude, maxRadiusKm);
  if (!best) return null;
  return {
    name: best.city.name,
    countryCode: best.city.countryCode,
    distanceKm: best.distanceKm,
  };
}

/** Nearest catalog city (full record) within [maxRadiusKm], or null. */
export function nearestCityWithin(
  latitude: number,
  longitude: number,
  maxRadiusKm: number,
): { city: CityRecord; distanceKm: number } | null {
  if (
    !Number.isFinite(latitude) ||
    !Number.isFinite(longitude) ||
    latitude < -90 ||
    latitude > 90 ||
    longitude < -180 ||
    longitude > 180 ||
    !(maxRadiusKm > 0)
  ) {
    return null;
  }
  let best: { city: CityRecord; distanceKm: number } | null = null;
  for (const city of CITY_CATALOG) {
    const distanceKm = haversineKm(latitude, longitude, city.latitude, city.longitude);
    if (distanceKm > maxRadiusKm) continue;
    if (!best || distanceKm < best.distanceKm) {
      best = { city, distanceKm };
    }
  }
  return best;
}

/** Wire shape returned by `GET /geo/cities`. */
export function cityCatalogWire(): Array<{
  id: string;
  name: string;
  countryCode: string;
  currency: string;
  latitude: number;
  longitude: number;
  /**
   * Local/spoken names the picker may be searched by (`لندن` → London).
   * Display always uses [name]; aliases are search aids only.
   */
  aliases: string[];
}> {
  return CITY_CATALOG.map((city) => ({
    id: city.id,
    name: city.name,
    countryCode: city.countryCode,
    currency: city.currency,
    latitude: city.latitude,
    longitude: city.longitude,
    aliases: city.aliases,
  }));
}
