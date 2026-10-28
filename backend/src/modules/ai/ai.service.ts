import {
  Inject,
  Injectable,
  Logger,
} from '@nestjs/common';
import { DuffelService } from '../duffel/duffel.service';

import { AiResponseDto, AiContextDto } from '../../common/dto/ai.dto';
import {
  AI_PROVIDER,
  AiProvider,
  categoryOf,
  upstreamStatusOf,
} from './ai.provider';

interface AiAttemptRecord {
  provider: string;
  outcome: 'success' | 'failure';
  latencyMs: number;
  category?: string;
  upstreamStatus?: number;
}

export function formatAiAttempt(record: AiAttemptRecord): string {
  const parts = [
    `provider=${record.provider}`,
    `outcome=${record.outcome}`,
    `latencyMs=${record.latencyMs}`,
  ];
  if (record.category !== undefined) {
    parts.push(`category=${record.category}`);
  }
  if (record.upstreamStatus !== undefined) {
    parts.push(`upstreamStatus=${record.upstreamStatus}`);
  }
  return `ai.query ${parts.join(' ')}`;
}

@Injectable()
export class AiService {
  private readonly logger = new Logger(AiService.name);

  /** Bilingual display templates for /ai/suggest typeahead. */
  private static readonly SUGGEST_CATALOGUE: readonly string[] = [
    'Flights from Cairo to Dubai',
    'Flights from Riyadh to Cairo',
    'Cheap flights to Istanbul',
    'Flights to Sharm El Sheikh',
    'Hotels in Dubai for 2 nights',
    'Hotels in Cairo city centre',
    'Hotels in Sharm El Sheikh with a pool',
    'Car rental in Riyadh for 3 days',
    'Car rental in Cairo airport',
    'Weekend trip ideas under $300',
    'Family destinations in Egypt',
    'Beach escapes in Egypt',
    'طيران من القاهرة إلى دبي',
    'طيران من الرياض إلى القاهرة',
    'أرخص رحلات إلى إستنبول',
    'رحلات إلى شرم الشيخ',
    'فنادق في دبي لليلتين',
    'فنادق في وسط القاهرة',
    'فنادق في شرم الشيخ بمسبح',
    'تأجير عربية في الرياض لمدة ٣ أيام',
    'تأجير عربية من مطار القاهرة',
    'أفكار ويك إند بميزانية تحت ٣٠٠ دولار',
    'وجهات عائلية في مصر',
    'رحلات شاطئية في مصر',
  ];

  /** Shown when the typed query matches nothing in the catalogue. */
  private static readonly DEFAULT_SUGGESTIONS: readonly string[] = [
    'Flights from Cairo to Dubai',
    'Hotels in Dubai for 2 nights',
    'طيران من القاهرة إلى دبي',
    'أرخص رحلات إلى إستنبول',
    'Weekend trip ideas under $300',
    'فنادق في شرم الشيخ بمسبح',
  ];

  constructor(
    @Inject(AI_PROVIDER) private readonly provider: AiProvider,
    private readonly duffelService: DuffelService,
  ) {}

  private extractTravelSearchData(prompt: string): { isTravelSearch: boolean; searchData?: any } {
    const travelKeywords = ['طيران', 'رحلة', 'سفر', 'حجز', 'أريد طيران', 'عايز طيران', 'ابغى سفر', 'حجز تذكرة'];
    const isTravelSearch = travelKeywords.some(keyword => prompt.includes(keyword));
    
    if (!isTravelSearch) return { isTravelSearch: false };

    const citiesPattern = /من\s*([\u0600-\u06FF\w]+)\s*إلى\s*([\u0600-\u06FF\w]+)/;
    const datePattern = /في\s*(\d{4}-\d{2}-\d{2})|يوم\s*(\d{1,2})\s*(\w+)/;
    
    const citiesMatch = prompt.match(citiesPattern);
    const dateMatch = prompt.match(datePattern);

    const defaultDate = new Date();
    defaultDate.setDate(defaultDate.getDate() + 7);

    const searchData = {
      origin: citiesMatch?.[1] || '',
      destination: citiesMatch?.[2] || '',
      departureDate: dateMatch?.[1] || defaultDate.toISOString().split('T')[0],
      passengers: 1,
    };

    return { isTravelSearch: true, searchData };
  }

  async query(
    prompt: string,
    context?: AiContextDto | null,
    memoryContext?: string | null,
  ): Promise<AiResponseDto> {    const startedAt = Date.now();
    let fullPrompt = prompt;
    const requestedMaxOutputTokens = context?.metadata?.maxOutputTokens;
    const maxOutputTokens =
      typeof requestedMaxOutputTokens === 'number' &&
      Number.isInteger(requestedMaxOutputTokens) &&
      requestedMaxOutputTokens >= 64 &&
      requestedMaxOutputTokens <= 2048
        ? requestedMaxOutputTokens
        : undefined;
    if (context) {
      const contextParts: string[] = [];
      const metadata = context.metadata ?? {};
      const mood = metadata.travelMood;
      if (
        typeof mood === 'string' &&
        ['shopping', 'beach', 'snow', 'nature', 'city'].includes(mood)
      ) {
        contextParts.push(`Travel mood: ${mood}`);
      }
      const countryCode = metadata.countryCode;
      if (
        typeof countryCode === 'string' &&
        /^[A-Za-z]{2}$/.test(countryCode)
      ) {
        contextParts.push(`Traveller country: ${countryCode.toUpperCase()}`);
      }
      const explicitPreferences = metadata.explicitPreferences;
      if (typeof explicitPreferences === 'object' && explicitPreferences !== null) {
        const preferences = explicitPreferences as Record<string, unknown>;
        const destination = preferences.preferred_destination;
        if (typeof destination === 'string' && destination.trim()) {
          contextParts.push(
            `Explicit preferred destination: ${destination.trim().replace(/[\r\n\t]/g, ' ').slice(0, 80)}`,
          );
        }
        const preferredBudget = preferences.preferred_budget;
        if (typeof preferredBudget === 'object' && preferredBudget !== null) {
          const range = preferredBudget as Record<string, unknown>;
          const min = typeof range.min === 'number' ? range.min : null;
          const max = typeof range.max === 'number' ? range.max : null;
          if (min !== null || max !== null) {
            // Phase 4B: the currency is only stated when the user stated it.
            const currency =
              typeof range.currency === 'string' ? range.currency.trim() : '';
            const suffix = currency ? ` ${currency}` : '';
            contextParts.push(
              `Explicit preferred budget: ${min ?? 'unspecified'} to ${max ?? 'unspecified'}${suffix}`,
            );
          }
        }
        const styles = preferences.preferred_travel_style;
        if (Array.isArray(styles)) {
          const safeStyles = styles
            .filter((style): style is string => typeof style === 'string')
            .map((style) => style.trim().replace(/[\r\n\t]/g, ' ').slice(0, 60))
            .filter(Boolean)
            .slice(0, 60);
          if (safeStyles.length > 0) {
            contextParts.push(`Explicit preferred travel styles: ${safeStyles.join(', ')}`);
          }
        }
      }
      const likedStayTitles = metadata.likedStayTitles;
      if (Array.isArray(likedStayTitles)) {
        const safeLikedTitles = likedStayTitles
          .filter((title): title is string => typeof title === 'string')
          .map((title) => title.trim().replace(/[\r\n\t]/g, ' ').slice(0, 120))
          .filter(Boolean)
          .slice(0, 5);
        if (safeLikedTitles.length > 0) {
          contextParts.push(
            `Traveller-liked stay names (style signals only): ${safeLikedTitles.join(', ')}`,
          );
        }
      }
      const budget = metadata.budget;
      if (
        typeof budget === 'object' &&
        budget !== null &&
        (typeof budget.min === 'number' || typeof budget.max === 'number')
      ) {
        const min = typeof budget.min === 'number' ? budget.min : 0;
        const max = typeof budget.max === 'number' ? budget.max : 'unspecified';
        contextParts.push(`Travel budget range: ${min} to ${max}`);
      }
      if (context.travelDates) {
        contextParts.push(`Travel dates: ${JSON.stringify(context.travelDates)}`);
      }
      if (contextParts.length > 0) {
        fullPrompt = [
          `Use this traveller context when relevant: ${contextParts.join('; ')}.`,
          'Do not infer an exact departure city or airport from country alone; ask if needed.',
          prompt,
        ].join('\n');
      }
    }

    const { isTravelSearch, searchData } = this.extractTravelSearchData(prompt);
    if (isTravelSearch && searchData && searchData.origin && searchData.destination) {
      try {
        const flights = await this.duffelService.searchFlightsLegacy(
          searchData.origin,
          searchData.destination,
          searchData.departureDate,
          searchData.passengers,
        );

        const flightItems = (flights.offers || []).map((offer: any) => ({
          id: offer.id,
          type: 'flight',
          title: offer.title || `${searchData.origin} → ${searchData.destination}`,
          subtitle: offer.subtitle || offer.airline || 'رحلة جوية',
          price: typeof offer.price === 'number' ? offer.price : parseFloat(offer.price || '0'),
          currency: offer.currency || 'USD',
          airline: offer.airline,
          flightNumber: offer.flightNumber,
          data: {
            origin: offer.origin,
            destination: offer.destination,
            departureTime: offer.departureTime,
            arrivalTime: offer.arrivalTime,
          },
        }));

        if (flightItems.length > 0) {
          this.record({
            provider: 'duffel-flight',
            outcome: 'success',
            latencyMs: Date.now() - startedAt,
          });

          return {
            text: `تم العثور على ${flightItems.length} رحلة طيران متاحة من ${searchData.origin} إلى ${searchData.destination}:`,
            sections: [{
              id: 'flight-results',
              title: 'رحلات الطيران المتاحة',
              layout: 'vertical',
              items: flightItems,
            }],
            metadata: { searchData, flightCount: flightItems.length },
          };
        }
      } catch (searchError) {
        this.logger.warn(`Live flight search bypassed: ${(searchError as Error).message}`);
      }
    }

    try {
      // Phase 2C-B: the conversation-memory context (when present) rides the
      // provider system prompt — it is NEVER concatenated into the user
      // prompt, so the Duffel keyword shortcut and the flight-path prompt
      // stay byte-identical when no memory is relevant.
      const response = await this.provider.generate(
        fullPrompt,
        memoryContext ?? undefined,
        maxOutputTokens,
      );
      this.record({
        provider: this.provider.providerId,
        outcome: 'success',
        latencyMs: Date.now() - startedAt,
      });
      return response;
    } catch (error) {
      this.record({
        provider: this.provider.providerId,
        outcome: 'failure',
        latencyMs: Date.now() - startedAt,
        category: categoryOf(error),
        upstreamStatus: upstreamStatusOf(error),
      });
      throw error;
    }
  }

  /**
   * POST /ai/suggest — fast typeahead suggestions for the smart search
   * sheet. Deliberately NOT an LLM call: typeahead must return in tens of
   * milliseconds and stay free. Template matching over a small bilingual
   * travel catalogue — no ML, no vector search (per architecture rules).
   */
  async suggest(query: string): Promise<string[]> {
    const q = query.trim().toLowerCase();
    if (q.length < 2) {
      return AiService.DEFAULT_SUGGESTIONS.slice(0, 6);
    }

    const catalogue = AiService.SUGGEST_CATALOGUE;
    const scored: { text: string; score: number }[] = [];

    for (const entry of catalogue) {
      const haystack = entry.toLowerCase();
      let score = 0;

      // Containment on either side (partial prefix or substring) beats
      // nothing; language-agnostic for the mixed AR/EN catalogue.
      const direct = haystack.indexOf(q);
      if (direct >= 0) {
        score = 100 - Math.min(direct, 50);
      } else {
        // Token-overlap fallback for word-order differences.
        const tokens = q.split(/\s+/).filter((t) => t.length > 1);
        const matched = tokens.filter((t) => haystack.includes(t)).length;
        if (tokens.length > 0 && matched > 0) {
          score = Math.round((matched / tokens.length) * 60);
        }
      }

      if (score > 0) {
        scored.push({ text: entry, score });
      }
    }

    scored.sort((a, b) => b.score - a.score);
    const results = scored.slice(0, 6).map((s) => s.text);
    return results.length > 0 ? results : AiService.DEFAULT_SUGGESTIONS.slice(0, 6);
  }

  private record(record: AiAttemptRecord): void {
    const line = formatAiAttempt(record);
    if (record.outcome === 'success') {
      this.logger.log(line);
    } else {
      this.logger.warn(line);
    }
  }
}
