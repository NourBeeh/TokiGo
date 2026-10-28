import { Inject, Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AI_PROVIDER, AiProvider } from '../ai/ai.provider';
import { NuiteeService } from '../nuitee/nuitee.service';
import { ProfileService } from '../profile/profile.service';
import { CacheService } from '../cache/cache.service';

/** Popular cities per country for candidate scans. */
const COUNTRY_CITIES: Record<string, string[]> = {
  EG: ['Cairo', 'Hurghada', 'Sharm El Sheikh', 'Luxor'],
  AE: ['Dubai', 'Abu Dhabi'],
  SA: ['Riyadh', 'Jeddah'],
  TR: ['Istanbul', 'Antalya'],
  QA: ['Doha'],
  KW: ['Kuwait City'],
  JO: ['Amman'],
  GB: ['London'],
  FR: ['Paris', 'Nice'],
  IT: ['Rome', 'Milan'],
  ES: ['Madrid', 'Barcelona'],
  DE: ['Berlin', 'Munich'],
  GR: ['Athens'],
  US: ['New York', 'Miami'],
  TH: ['Bangkok'],
  SG: ['Singapore'],
  MY: ['Kuala Lumpur'],
  JP: ['Tokyo'],
};

const DEFAULT_GUESTS = 2;

/**
 * Guest / unknown-market default. Every provider call must carry the city's
 * ISO-2 country (Nuitee answers with an empty list without it), so a guest
 * with no known country falls back to the launch market instead of scanning
 * the whole world on every Home open.
 */
const DEFAULT_COUNTRY = 'EG';

/** Home rail cache: short TTL; the Home opens constantly. */
const RECOMMENDED_TTL_SECONDS = 5 * 60;

/** Cards per response (the DTO enforces the same upper bound). */
const HOTEL_LIMIT_MAX = 12;

/** A compact hotel candidate shaped for scoring + AI ranking. */
export interface HotelCandidate {
  id: string;
  title: string;
  city: string;
  price?: number;
  currency?: string;
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
  ) {
    this.aiRerankEnabled = isEnabled(config.get<string>('RECOMMEND_AI_RERANK'));
  }

  async recommend(params: {
    userId?: string;
    countryCode?: string;
    countryConfidence?: string;
    limit?: number;
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

    // The stay window is part of the cache identity: prices are presentation
    // snapshots tied to those dates, never durable booking truth.
    const checkIn = daysFromNow(3);
    const checkOut = daysFromNow(5);
    const cacheKey =
      `home:recommended:${country}:${limit}:` +
      `${isoDay(checkIn)}:${isoDay(checkOut)}`;

    const cached = await this.cache.get<RecommendedHotelsResult>(cacheKey);
    if (cached) return cached;

    const candidates = await this.candidatesFor(country, checkIn, checkOut);
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

    const result: RecommendedHotelsResult = {
      source: 'provider',
      countryCode: country,
      confidence,
      hotels: hotels.slice(0, limit),
    };

    // Cache only a non-empty provider snapshot; an empty answer may recover.
    if (result.hotels.length > 0) {
      await this.cache.set(cacheKey, result, RECOMMENDED_TTL_SECONDS);
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

  /** Scans popular cities in the country via Nuitee real search. */
  private async candidatesFor(
    country: string,
    checkIn: Date,
    checkOut: Date,
  ): Promise<HotelCandidate[]> {
    const cities = COUNTRY_CITIES[country] ?? [];
    if (cities.length === 0) return [];

    const results = await Promise.allSettled(
      cities.map((city) =>
        this.nuitee.searchHotels({
          city,
          country,
          checkIn,
          checkOut,
          guests: DEFAULT_GUESTS,
          rooms: 1,
        }),
      ),
    );

    const out = new Map<string, HotelCandidate>();
    for (const r of results) {
      if (r.status === 'rejected') {
        // Never swallow a dead provider: an empty rail must be explainable.
        this.logger.warn(
          `Nuitee search rejected for ${country}: ${
            (r.reason as Error)?.message ?? String(r.reason)
          }`,
        );
        continue;
      }
      const value = r.value;
      if (value && value.success === false) {
        this.logger.warn(
          `Nuitee returned no rates for ${country}: ${value.error ?? 'unknown'}`,
        );
        continue;
      }
      const data = value?.data;
      if (!Array.isArray(data)) continue;
      for (const offer of data) {
        if (!offer?.id) continue;
        // Deduplicate by hotelId to avoid showing same hotel multiple times
        const hotelId = offer.metadata?.providerHotelId ?? offer.id;
        if (out.has(hotelId)) continue;
        out.set(hotelId, {
          id: hotelId,
          title: offer.title ?? 'Hotel',
          city: offer.city ?? '',
          price: typeof offer.price === 'number' ? offer.price : undefined,
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
 * A stay date `days` ahead. The provider adapter formats dates in UTC
 * (`toISOString().split('T')[0]`), so zeroing the clock to local midnight
 * would shift the check-in by a day in UTC+ timezones — keep the wall clock.
 */
function daysFromNow(days: number): Date {
  return new Date(Date.now() + days * 86_400_000);
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
