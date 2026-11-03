import { Inject, Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AI_PROVIDER, AiProvider } from '../ai/ai.provider';
import { NuiteeService } from '../nuitee/nuitee.service';
import { ProfileService } from '../profile/profile.service';
import { CacheService } from '../cache/cache.service';
import { ProviderResult } from '../../common/providers/provider.result';
import { COUNTRY_CITIES } from '../../common/market/popular-cities';
import {
  PricingService,
  PriceQuote,
} from '../../common/market/pricing.service';

const DEFAULT_GUESTS = 2;

/**
 * How many provider searches may be in flight at once.
 *
 * A market with several cities × the month's scanned nights is a burst of
 * requests, and Nuitee answers a burst with HTTP 429 and an empty rail.
 */
function providerConcurrency(): number {
  const configured = Number(process.env.RECOMMEND_CONCURRENCY);
  return Number.isFinite(configured) && configured > 0
    ? Math.min(Math.floor(configured), 8)
    : 4;
}

/**
 * How many of the month's nights are searched.
 *
 * Every scanned night is one search per city, so this is provider budget as
 * much as coverage: the cheapest night is usually within a few percent of the
 * month's floor, and a 31-night scan per city would cost 31× the budget for
 * the privilege of seeing the same number.
 */
function scanNightCount(): number {
  const configured = Number(process.env.RECOMMEND_SCAN_NIGHTS);
  if (Number.isFinite(configured) && configured > 0) {
    return Math.min(Math.floor(configured), 31);
  }
  return 6;
}

/**
 * Guest / unknown-market default. Every provider call must carry the city's
 * ISO-2 country (Nuitee answers with an empty list without it), so a guest
 * with no known country falls back to the launch market instead of scanning
 * the whole world on every Home open.
 */
const DEFAULT_COUNTRY = 'EG';

/** Home rail cache: short TTL; the Home opens constantly. */
function recommendedTtlSeconds(): number {
  const configured = Number(process.env.RECOMMENDED_CACHE_TTL_SECONDS);
  return Number.isFinite(configured) && configured > 0 ? configured : 5 * 60;
}

/** Cards per response (the DTO enforces the same upper bound). */
const HOTEL_LIMIT_MAX = 12;

/** A compact hotel candidate shaped for scoring + AI ranking. */
export interface HotelCandidate {
  id: string;
  title: string;
  city: string;
  price?: number;
  /**
   * The price of ONE night — the cheapest night the current month still offers
   * for this hotel.
   *
   * [price] is that same night's total: the rate is quoted for a SINGLE-night
   * window (see [scannedNights]), so the two numbers agree and the card can
   * label the amount "/ night" without dividing a stay total by a window the
   * traveller never chose (user report, 2026-10-30).
   */
  pricePerNight?: number;
  currency?: string;
  /**
   * Backend-quoted customer display price (market/currency converted). The
   * card shows this in the traveller's currency; the provider amount stays in
   * [price]/[currency] so revalidation compares like with like.
   */
  customerPrice?: PriceQuote;
  rating?: number;
  reviewCount?: number;
  imageUrl?: string;
  subtitle?: string;
  description?: string;
  /**
   * The stay window the price belongs to, plus where the room is.
   *
   * A recommendation is a REAL rate for a real window: a card that opens the
   * details page without these would have to invent dates (or send the
   * traveller back to a search). Both are facts the provider already returned,
   * so they travel with the card.
   */
  country?: string;
  checkIn?: string;
  checkOut?: string;
  roomType?: string;
  amenities?: string[];
  /**
   * Provider provenance. The tap-through revalidates an offer before booking,
   * so the rate/offer ids must survive the ranking step untouched.
   */
  metadata?: {
    providerId?: string;
    providerName?: string;
    providerRateId?: string;
    providerOfferId?: string;
    providerHotelId?: string;
    refundable?: boolean;
    stars?: number;
    boardName?: string;
    /** The single night's rate, for every per-night label on screen. */
    pricePerNight?: number;
    /** Provider-verbatim position, for "open in maps" + distance to centre. */
    latitude?: number;
    longitude?: number;
    address?: string;
    distanceToCenter?: number;
    hotelNameEn?: string;
    hotelNameAr?: string;
  };
}

export interface RecommendedHotelsResult {
  source: 'provider' | 'fallback';
  countryCode?: string;
  confidence?: string;
  hotels: HotelCandidate[];
  reasoning?: string;
}

/**
 * Recommendation engine (R-4) — THE ONLY source is the current provider
 * (Nuitee). Scores deterministically (popularity×quality) then, when the
 * live AI is configured, ranks the SAME candidates to personalise — the AI
 * never generates or invents hotels. Nuitee down → empty fallback (Flutter
 * keeps seed content); AI down → deterministic order.
 */
@Injectable()
export class RecommendedHotelService {
  private readonly logger = new Logger(RecommendedHotelService.name);

  /**
   * AI re-ranking is OFF unless `RECOMMEND_AI_RERANK` explicitly enables it.
   * The Home opens on every cold start: deterministic scoring is enough, and
   * an AI call there would re-add the cost/latency Phase 5 removed.
   */
  private readonly aiRerankEnabled: boolean;

  constructor(
    private readonly nuitee: NuiteeService,
    private readonly profiles: ProfileService,
    @Inject(AI_PROVIDER) private readonly ai: AiProvider | null,
    private readonly config: ConfigService,
    private readonly cache: CacheService,
    private readonly pricing: PricingService,
  ) {
    this.aiRerankEnabled = isEnabled(config.get<string>('RECOMMEND_AI_RERANK'));
  }

  async recommend(params: {
    userId?: string;
    countryCode?: string;
    countryConfidence?: string;
    limit?: number;
    language?: 'en' | 'ar';
    currency?: string;
  }): Promise<RecommendedHotelsResult> {
    const limit = Math.min(Math.max(params.limit ?? 6, 1), HOTEL_LIMIT_MAX);

    // ONE profile read for country + preferences (this used to read it three
    // times per request).
    const profile = params.userId ? await this.profileFor(params.userId) : null;
    const explicit = normalizeCountry(params.countryCode);
    const fromProfile = normalizeCountry(profile?.countryCode);
    const country = this.resolveCountry(explicit ?? fromProfile);
    const confidence =
      params.countryConfidence ??
      (explicit ? 'explicit' : fromProfile ? 'profile' : 'default');

    // The card prices ONE NIGHT, and that number must be the LOWEST night the
    // current month still sells (user report, 2026-10-30): a stay total divided
    // by a window the traveller never chose said nothing about what a night
    // here costs. The scanned nights belong to the cache identity — prices are
    // presentation snapshots tied to those dates, never durable booking truth.
    const nights = scannedNights();
    const language = params.language === 'ar' ? 'ar' : 'en';
    // The DISPLAY market is the caller's own country (not the served-search
    // market, which falls back to EG for unsupported countries). Unknown
    // countries + the traveller's chosen currency are resolved in marketFor.
    const displayCountry = explicit ?? fromProfile;
    const currencyKey = String(params.currency ?? '')
      .trim()
      .toUpperCase();
    const cacheKey =
      `home:recommended:${language}:${country}:${limit}:` +
      (currencyKey ? `${currencyKey}:` : '') +
      nights.map((night) => isoDay(night.checkIn)).join(',');

    const cached = await this.cache.get<RecommendedHotelsResult>(cacheKey);
    if (cached) return cached;

    const candidates = await this.candidatesFor(country, nights, language);
    if (candidates.length === 0) {
      // Provider down, no inventory, or an unserved market: honest empty.
      return { source: 'fallback', countryCode: country, confidence, hotels: [] };
    }

    const prefs = profile?.preferences;
    const scored = this.score(candidates, prefs);
    let hotels = scored.map((s) => s.hotel);

    const aiRank = await this.rankWithAi(hotels, profile, prefs, limit);
    if (aiRank) {
      const ordered = aiRank
        .map((id) => hotels.find((h) => h.id === id))
        .filter((h): h is HotelCandidate => Boolean(h));
      if (ordered.length > 0) {
        hotels = ordered;
      }
    }

    // Attach the customer display price (converted to the market/currency) to
    // each card the traveller will actually see. Provider price/currency stay
    // untouched inside the candidate.
    const selected = hotels.slice(0, limit);
    const pricedHotels = await Promise.all(
      selected.map((hotel) => this.withCustomerPrice(hotel, displayCountry, params.currency)),
    );

    const result: RecommendedHotelsResult = {
      source: 'provider',
      countryCode: country,
      confidence,
      hotels: pricedHotels,
    };

    // Cache only a non-empty provider snapshot; an empty answer may recover.
    if (result.hotels.length > 0) {
      await this.cache.set(cacheKey, result, recommendedTtlSeconds());
    }
    return result;
  }

  /** Profile read that never fails the recommendation (missing profile = guest). */
  private async profileFor(userId: string): Promise<any> {
    return this.profiles.getView(userId).catch(() => null);
  }

  /** Markets we can actually serve; anything else falls back to the default. */
  private resolveCountry(country?: string): string {
    return country && COUNTRY_CITIES[country] ? country : DEFAULT_COUNTRY;
  }

  /**
   * Attaches the backend-quoted customer display price to a candidate. Display
   * only: a pricing failure returns the card unpriced rather than dropping it.
   */
  private async withCustomerPrice(
    hotel: HotelCandidate,
    market?: string,
    currency?: string,
  ): Promise<HotelCandidate> {
    if (typeof hotel.price !== 'number' || !hotel.currency) return hotel;
    try {
      const customerPrice = await this.pricing.quote(
        hotel.price,
        hotel.currency,
        { market, currency },
      );
      return { ...hotel, customerPrice };
    } catch {
      return hotel;
    }
  }

  /**
   * Scans popular cities in the country via Nuitee real search — one search per
   * (city, scanned night) — and keeps each hotel's CHEAPEST night.
   *
   * The searches run through a small concurrency gate: a market's cities × the
   * month's nights is a burst, and a provider that answers a burst with HTTP
   * 429 returns an empty rail to the traveller.
   */
  private async candidatesFor(
    country: string,
    nights: StayNight[],
    language: 'en' | 'ar',
  ): Promise<HotelCandidate[]> {
    const cities = COUNTRY_CITIES[country] ?? [];
    if (cities.length === 0) return [];

    const jobs: Array<{ city: string; night: StayNight }> = [];
    for (const city of cities) {
      for (const night of nights) jobs.push({ city, night });
    }

    const results = await mapLimit(
      jobs,
      providerConcurrency(),
      async (job): Promise<{ job: typeof job; value?: ProviderResult<any[]>; error?: unknown }> => {
        try {
          const value = await this.nuitee.searchHotels({
            city: job.city,
            country,
            checkIn: job.night.checkIn,
            checkOut: job.night.checkOut,
            guests: DEFAULT_GUESTS,
            rooms: 1,
            language,
          });
          return { job, value };
        } catch (error) {
          return { job, error };
        }
      },
    );

    const out = new Map<string, HotelCandidate>();
    for (const r of results) {
      if (r.error !== undefined) {
        // Never swallow a dead provider: an empty rail must be explainable.
        this.logger.warn(
          `Nuitee search rejected for ${r.job.city} on ${isoDay(
            r.job.night.checkIn,
          )}: ${(r.error as Error)?.message ?? String(r.error)}`,
        );
        continue;
      }
      const value = r.value;
      if (value && value.success === false) {
        this.logger.warn(
          `Nuitee returned no rates for ${r.job.city} on ${isoDay(
            r.job.night.checkIn,
          )}: ${value.error ?? 'unknown'}`,
        );
        continue;
      }
      const data = value?.data;
      if (!Array.isArray(data)) continue;
      for (const offer of data) {
        if (!offer?.id) continue;
        // Deduplicate by hotelId across cities AND nights; the cheapest night
        // wins, because that is the number the card states.
        const hotelId = offer.metadata?.providerHotelId ?? offer.id;
        const price =
          typeof offer.price === 'number' ? offer.price : undefined;
        const existing = out.get(hotelId);
        const cheaper =
          price !== undefined &&
          (existing?.price === undefined || price < existing.price);
        if (existing && !cheaper) continue;
        out.set(hotelId, {
          id: hotelId,
          title: offer.title ?? 'Hotel',
          city: offer.city ?? '',
          price,
          // The window is ONE night, so this is the same number as `price` —
          // stated explicitly so no surface has to divide a total to get it.
          pricePerNight: price,
          currency: offer.currency,
          rating: typeof offer.rating === 'number' ? offer.rating : undefined,
          reviewCount:
            typeof offer.reviewCount === 'number' ? offer.reviewCount : undefined,
          imageUrl: offer.imageUrl,
          subtitle: offer.subtitle,
          description: offer.description,
          // The offer's own stay facts — no client-side guessing.
          country: offer.country,
          checkIn: offer.checkIn,
          checkOut: offer.checkOut,
          roomType: offer.roomType,
          amenities: Array.isArray(offer.amenities)
            ? offer.amenities.slice(0, 6).map((a: unknown) => String(a))
            : [],
          // Provenance survives scoring + AI ordering: the card tap needs the
          // rate/offer ids to revalidate the price before booking.
          metadata: {
            providerId: offer.providerId,
            providerName: offer.providerName,
            providerRateId: offer.metadata?.providerRateId,
            providerOfferId: offer.metadata?.providerOfferId,
            providerHotelId: offer.metadata?.providerHotelId ?? hotelId,
            refundable: offer.metadata?.refundable,
            // The hotel's own class and board — the details page shows them
            // (the class line and the board row) and must not have to guess.
            stars: offer.metadata?.stars,
            boardName: offer.metadata?.boardName,
            // The nightly rate, spelled out for the card's price label and for
            // the details page's per-night line.
            pricePerNight: price,
            // Position travels with the card so it can open maps and state a
            // real distance to the centre (undefined stays undefined).
            latitude: offer.metadata?.latitude,
            longitude: offer.metadata?.longitude,
            address: offer.metadata?.address,
            distanceToCenter: offer.metadata?.distanceToCenter,
            hotelNameEn: offer.metadata?.hotelNameEn,
            hotelNameAr: offer.metadata?.hotelNameAr,
          },
        });
      }
    }
    return [...out.values()];
  }

  /** Deterministic score: quality × popularity, aligned to user prefs. */
  private score(
    candidates: HotelCandidate[],
    prefs?: Record<string, any>,
  ): Array<{ hotel: HotelCandidate; score: number }> {
    const budgetMax = asNumber(prefs?.budgetMax);
    const preferredStars = asNumber(prefs?.preferredStars);
    const amenities = Array.isArray(prefs?.amenities)
      ? (prefs.amenities as string[])
      : [];

    return candidates
      .map((hotel) => {
        let score = 0;
        const rating = hotel.rating ?? 0;
        const reviews = hotel.reviewCount ?? 0;
        // Quality × popularity (log-scaling reviews so a 1000-review hotel
        // doesn't dwarf every curated pick).
        score += rating * (1 + Math.log10(reviews + 1));

        if (budgetMax !== undefined && hotel.price !== undefined) {
          if (hotel.price <= budgetMax) score += 2;
          else if (hotel.price <= budgetMax * 1.2) score -= 0.5;
          else score -= 2;
        }
        if (preferredStars !== undefined) {
          const stars = Math.round(rating);
          score += -Math.abs(stars - preferredStars) * 0.5;
        }
        if (amenities.length > 0) {
          score += amenities.length * 0.2;
        }
        return { hotel, score };
      })
      .sort((a, b) => b.score - a.score);
  }

  /** Asks the live AI to re-order the SAME hotels by relevance to the profile. */
  private async rankWithAi(
    hotels: HotelCandidate[],
    profile: any,
    prefs: Record<string, any> | undefined,
    limit: number,
  ): Promise<string[] | null> {
    // Hard gate: no AI provider, or the feature is off (the Home default).
    if (!this.ai || !this.aiRerankEnabled) return null;

    const compact = hotels.slice(0, 30).map((h) => ({
      id: h.id,
      title: h.title,
      city: h.city,
      price: h.price ?? null,
      rating: h.rating ?? null,
      reviews: h.reviewCount ?? 0,
    }));
    const prompt = [
      'You are the TokiGo hotel-recommendation ranker.',
      'Given the user profile and a list of REAL hotels, return ONLY a JSON object:',
      '{"ordered": ["<id1>", "<id2>", ...], "reason": "<short reason>"}',
      'Order by personal relevance to the user. NEVER invent hotels or ids.',
      'User preferences: ' + JSON.stringify(prefs ?? {}),
      'User derived profile: ' + JSON.stringify(profile?.derived ?? {}),
      'Candidate hotels: ' + JSON.stringify(compact),
      `Return max ${limit} ids.`,
    ].join('\n');

    try {
      const response = await this.ai.generate(prompt);
      const raw = response.text ?? '';
      const parsed = extractIds(raw);
      if (!parsed || parsed.length === 0) {
        const ids = idsFromSections(response.sections);
        return ids.length > 0 ? ids : null;
      }
      return parsed;
    } catch (error) {
      this.logger.warn(`AI ranking skipped: ${(error as Error).message}`);
      return null;
    }
  }
}

function asNumber(value: unknown): number | undefined {
  return typeof value === 'number' && Number.isFinite(value) ? value : undefined;
}

/** Feature flag parser: absent/empty → false (opt-in only). */
function isEnabled(value?: string | null): boolean {
  if (!value) return false;
  return ['1', 'true', 'yes', 'on'].includes(value.trim().toLowerCase());
}

/** ISO-2 normaliser: anything that is not two letters is treated as unknown. */
function normalizeCountry(value?: string | null): string | undefined {
  const code = value?.trim().toUpperCase();
  return code && /^[A-Z]{2}$/.test(code) ? code : undefined;
}

/**
 * A one-night stay window. Every window this service prices is exactly one
 * night long, so the provider's quoted total IS the nightly rate.
 */
interface StayNight {
  checkIn: Date;
  checkOut: Date;
}

/** The nights of [year]/[month] a card may price, starting at [fromDay]. */
function nightsOfMonth(year: number, month: number, fromDay: number): StayNight[] {
  // Day 0 of the NEXT month is the last day of this one (Date.UTC normalises).
  const lastDay = new Date(Date.UTC(year, month + 1, 0)).getUTCDate();
  const nights: StayNight[] = [];
  for (let day = fromDay; day <= lastDay; day++) nights.push(nightAt(year, month, day));
  return nights;
}

/** One night's window; UTC because the provider adapter formats dates in UTC. */
function nightAt(year: number, month: number, day: number): StayNight {
  return {
    checkIn: new Date(Date.UTC(year, month, day)),
    // `day + 1` rolls into the next month on the month's last day.
    checkOut: new Date(Date.UTC(year, month, day + 1)),
  };
}

/**
 * The nights the recommended rail may price: every remaining night of the
 * CURRENT calendar month, thinned to [scanNightCount] of them.
 *
 * A one-night window means the card's amount is a nightly rate the provider
 * actually quoted for ONE night — not a stay total divided by a window the
 * traveller never chose. When the month has no night left (its last day), the
 * scan starts on the next month's first nights instead of leaving the rail
 * without a price at all.
 */
function scannedNights(now: Date = new Date()): StayNight[] {
  const year = now.getUTCFullYear();
  const month = now.getUTCMonth();
  const remaining = nightsOfMonth(year, month, now.getUTCDate());
  const nights =
    remaining.length > 0
      ? remaining
      : nightsOfMonth(
          month === 11 ? year + 1 : year,
          (month + 1) % 12,
          1,
        );
  return thinNights(nights, scanNightCount());
}

/**
 * Evenly spread a month's nights down to [count] of them. Even spacing samples
 * the whole month (a weekday/weekend rhythm shows up as a real difference)
 * instead of pricing the first `count` nights, which are often the priciest.
 */
function thinNights(nights: StayNight[], count: number): StayNight[] {
  if (nights.length <= count) return nights;
  const step = nights.length / count;
  const out: StayNight[] = [];
  for (let i = 0; i < count; i++) out.push(nights[Math.floor(i * step)]);
  return out;
}

/**
 * Bounded parallelism — at most [limit] workers in flight.
 *
 * Results keep their input order, so logs and scores stay deterministic no
 * matter how the network interleaves.
 */
async function mapLimit<T, R>(
  items: T[],
  limit: number,
  worker: (item: T) => Promise<R>,
): Promise<R[]> {
  const results: R[] = new Array(items.length);
  let next = 0;
  const runners = Array.from(
    { length: Math.max(1, Math.min(limit, items.length)) },
    async () => {
      while (next < items.length) {
        const index = next++;
        results[index] = await worker(items[index]);
      }
    },
  );
  await Promise.all(runners);
  return results;
}

/** YYYY-MM-DD (UTC) — the provider window in a cache-key-safe form. */
function isoDay(date: Date): string {
  return date.toISOString().slice(0, 10);
}

/** Extracts the "ordered" JSON array from the AI text response, best-effort. */
function extractIds(text: string): string[] | null {
  const trimmed = text.trim();
  const walk = (s: string): string[] | null => {
    const brace = s.indexOf('{');
    const close = s.indexOf('}');
    if (brace < 0 || close <= brace) return null;
    const obj = s.slice(brace, close + 1);
    try {
      const parsed = JSON.parse(obj);
      const arr = parsed?.ordered;
      if (Array.isArray(arr)) {
        return arr.filter((x: unknown): x is string => typeof x === 'string');
      }
      return null;
    } catch {
      return walk(s.slice(close + 1));
    }
  };
  return walk(trimmed);
}

function idsFromSections(sections?: any[]): string[] {
  if (!Array.isArray(sections)) return [];
  const out: string[] = [];
  for (const section of sections) {
    for (const item of section?.items ?? []) {
      if (typeof item?.id === 'string') out.push(item.id);
    }
  }
  return out;
}
