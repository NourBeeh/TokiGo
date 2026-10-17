import { Inject, Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AI_PROVIDER, AiProvider } from '../ai/ai.provider';
import { NuiteeService } from '../nuitee/nuitee.service';
import { ProfileService } from '../profile/profile.service';

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

  constructor(
    private readonly nuitee: NuiteeService,
    private readonly profiles: ProfileService,
    @Inject(AI_PROVIDER) private readonly ai: AiProvider | null,
    private readonly config: ConfigService,
  ) {}

  async recommend(params: {
    userId?: string;
    countryCode?: string;
    countryConfidence?: string;
    limit?: number;
  }): Promise<RecommendedHotelsResult> {
    const limit = Math.min(Math.max(params.limit ?? 6, 1), 12);
    const country =
      params.countryCode ??
      (params.userId
        ? (await this.profiles.getView(params.userId).catch(() => null))?.countryCode
        : undefined);
    const confidence = params.countryConfidence;

    const candidates = country
      ? await this.candidatesFor(country)
      : await this.globalCandidates();
    if (candidates.length === 0) {
      return { source: 'fallback', countryCode: country, confidence, hotels: [] };
    }

    const prefs = params.userId
      ? (await this.profiles.getView(params.userId).catch(() => null))?.preferences
      : undefined;

    const scored = this.score(candidates, prefs);
    let hotels = scored.map((s) => s.hotel);

    const profile = params.userId
      ? await this.profiles.getView(params.userId).catch(() => null)
      : null;
    const aiRank = await this.rankWithAi(hotels, profile, prefs, limit);
    if (aiRank) {
      const ordered = aiRank
        .map((id) => hotels.find((h) => h.id === id))
        .filter((h): h is HotelCandidate => Boolean(h));
      if (ordered.length > 0) {
        hotels = ordered;
      }
    }

    return {
      source: 'provider',
      countryCode: country,
      confidence,
      hotels: hotels.slice(0, limit),
    };
  }

/** Scans popular cities in the country via Nuitee real search. */
  private async candidatesFor(country: string): Promise<HotelCandidate[]> {
    const cities = COUNTRY_CITIES[country] ?? [];
    if (cities.length === 0) return [];
    const checkIn = new Date(Date.now() + 3 * 86_400_000);
    const checkOut = new Date(Date.now() + 5 * 86_400_000);

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
      if (r.status !== 'fulfilled') continue;
      const data = r.value?.data;
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
        });
      }
    }
    return [...out.values()];
  }

  /** No country known: scan a broad default set so the section still has real hotels. */
  private async globalCandidates(): Promise<HotelCandidate[]> {
    const countries = ['EG', 'AE', 'SA', 'TR', 'FR'];
    const batches = await Promise.allSettled(
      countries.map((c) => this.candidatesFor(c)),
    );
    const out = new Map<string, HotelCandidate>();
    for (const b of batches) {
      if (b.status !== 'fulfilled') continue;
      for (const h of b.value) out.set(h.id, h);
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
    if (!this.ai) return null;

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
