import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { HotelProvider } from '../../common/providers/hotel.provider';
import { ProviderResult } from '../../common/providers/provider.result';

/**
 * Nuitee Connect hotel provider (spec point 25).
 *
 * Implements the shared HotelProvider contract so it can be registered,
 * routed and replaced without touching domain or Flutter code.
 *
 * Workflow mapping (Nuitee Connect REST v3):
 *   searchHotels  -> POST /v3.0/hotels/rates   (rates search)
 *   prebookHotel  -> POST /v3.0/rates/prebook
 *   bookHotel     -> POST /v3.0/rates/book    (ACC_CREDIT_CARD sandbox)
 *   hotelContent  -> GET  /v3.0/data/hotels    (metadata list)
 *
 * Sandbox and production share ONE base URL (api.liteapi.travel) — the
 * environment is determined by the API key itself (sand_*** = sandbox) and
 * the response carries a top-level `sandbox` boolean.
 *
 * The API key is resolved from NUITEE_API_KEY in the environment only —
 * never shipped to Flutter (spec non-negotiable).
 */

export interface NuiteeSearchParams {
  city: string;
  checkIn: Date;
  checkOut: Date;
  guests?: number;
  rooms?: number;
  country?: string;
}

export interface NuiteePrebookResult {
  success: boolean;
  providerId: string;
  prebookId?: string;
  transactionId?: string;
  priceChanged?: boolean;
  oldPrice?: number;
  newPrice?: number;
  currency?: string;
  expiresAt?: string;
  error?: string;
}

/** City -> countryCode mapping for the rates request (ISO-2). */
const CITY_COUNTRIES: Record<string, string> = {
  cairo: 'EG', 'القاهرة': 'EG', 'القاهره': 'EG', alexandria: 'EG',
  'الاسكندرية': 'EG', 'الإسكندرية': 'EG', hurghada: 'EG', 'الغردقة': 'EG',
  'sharm el sheikh': 'EG', 'شرم الشيخ': 'EG', luxor: 'EG', 'الأقصر': 'EG',
  aswan: 'EG', 'أسوان': 'EG',
  dubai: 'AE', 'دبي': 'AE', 'abu dhabi': 'AE', 'أبوظبي': 'AE',
  riyadh: 'SA', 'الرياض': 'SA', jeddah: 'SA', 'جدة': 'SA', 'جده': 'SA',
  mecca: 'SA', 'مكة': 'SA', medina: 'SA', 'المدينة': 'SA',
  doha: 'QA', 'الدوحة': 'QA', kuwait: 'KW', 'الكويت': 'KW',
  amman: 'JO', 'عمّان': 'JO', 'عمان الأردن': 'JO',
  istanbul: 'TR', 'اسطنبول': 'TR', 'إسطنبول': 'TR',
  london: 'GB', 'لندن': 'GB', paris: 'FR', 'باريس': 'FR',
  rome: 'IT', 'روما': 'IT', milan: 'IT', 'ميلان': 'IT', 'ميلانو': 'IT',
  madrid: 'ES', 'مدريد': 'ES', barcelona: 'ES', 'برشلونة': 'ES',
  berlin: 'DE', 'برلين': 'DE', munich: 'DE', 'ميونخ': 'DE',
  vienna: 'AT', 'فيينا': 'AT', athens: 'GR', 'أثينا': 'GR', 'اثينا': 'GR',
  'new york': 'US', 'نيويورك': 'US', toronto: 'CA', 'تورونتو': 'CA',
  bangkok: 'TH', 'بانكوك': 'TH', singapore: 'SG', 'سنغافورة': 'SG',
  'kuala lumpur': 'MY', 'كوالالمبور': 'MY', tokyo: 'JP', 'طوكيو': 'JP',
};

const NUITEE_BASE_URL = 'https://api.liteapi.travel/v3.0';


@Injectable()
export class NuiteeService implements HotelProvider {
  providerId = 'nuitee';
  providerName = 'Nuitee Connect';

  private readonly logger = new Logger(NuiteeService.name);
  private readonly apiKey?: string;

  constructor(private configService: ConfigService) {
    this.apiKey = this.configService.get<string>('NUITEE_API_KEY');
    if (!this.apiKey) {
      this.logger.warn('NUITEE_API_KEY is not defined — Nuitee hotel provider is disabled');
    } else {
      const mode = this.apiKey.startsWith('sand_') ? 'sandbox' : 'live';
      this.logger.log(`Nuitee hotel provider enabled (${mode} key detected)`);
    }
  }

  private headers(): Record<string, string> {
    return {
      'Content-Type': 'application/json',
      'X-API-Key': this.apiKey!,
    };
  }

  private async nuiteeFetch(path: string, init: RequestInit): Promise<any> {
    const response = await fetch(`${NUITEE_BASE_URL}${path}`, {
      ...init,
      signal: AbortSignal.timeout(15_000),
    });
    const text = await response.text();
    let body: any;
    try {
      body = JSON.parse(text);
    } catch {
      throw new Error(`Nuitee returned non-JSON (${response.status}): ${text.slice(0, 120)}`);
    }
    if (!response.ok) {
      const detail = body?.error?.message ?? body?.message ?? JSON.stringify(body).slice(0, 160);
      throw new Error(`Nuitee ${path} failed (${response.status}): ${String(detail)}`);
    }
    return body;
  }

  /**
   * Rates search mapped into the shared hotel offer shape.
   * One offer per (hotel, roomType, cheapest rate) so every bookable
   * rate surfaces with its live provider price.
   */
  async searchHotels(params: NuiteeSearchParams): Promise<ProviderResult<any[]>> {
    if (!this.apiKey) {
      return this.disabledResult();
    }

    const checkInStr = this.dateStr(params.checkIn);
    const checkOutStr = this.dateStr(params.checkOut);
    const guests = params.guests ?? 2;
    const rooms = params.rooms ?? 1;

    try {
      const body = {
        cityName: params.city,
        countryCode: params.country ?? this.countryFor(params.city) ?? 'EG',
        checkin: checkInStr,
        checkout: checkOutStr,
        currency: 'USD',
        guestNationality: 'EG',
        occupancies: [{ rooms, adults: guests }],
        // Keep responses lean: top rate per room type, capped hotel set.
        maxRatesPerHotel: 2,
        limit: 40,
        includeHotelData: true,
      };
      const response = await this.nuiteeFetch('/hotels/rates', {
        method: 'POST',
        headers: this.headers(),
        body: JSON.stringify(body),
      });

      const hotelMeta = this.hotelMetaIndex(response);
      const rateEntries = this.extractRateResults(response);

      // BUGFIX (user report 2026-09-08): the adapter emitted one offer PER
      // ROOM TYPE, so the same hotel surfaced 2–3 times at different
      // prices (Standard/Deluxe/Suite) on the Home rail and search. The
      // original comment said "cheapest rate per hotel" but the code never
      // deduplicated. Fix: keep exactly ONE offer per hotel — the cheapest
      // available room. The room-level detail stays reachable through the
      // provider (rateId of the cheapest room is preserved for prebook).
      const cheapestPerHotel = new Map<string, { entry: any; price: number }>();
      for (const entry of rateEntries) {
        const key = String(
          entry?.hotelId ?? entry?.rate?.rateId ?? entry?.offerId ?? '',
        );
        const price = this.firstAmount(entry?.rate?.retailRate?.total) ?? Infinity;
        const existing = cheapestPerHotel.get(key);
        if (!existing || price < existing.price) {
          cheapestPerHotel.set(key, { entry, price });
        }
      }

      const mapped = [...cheapestPerHotel.values()]
        .map(({ entry }) =>
          this.mapRateToOffer(entry, hotelMeta, params, checkInStr, checkOutStr),
        )
        .filter((o: any) => o !== null)
        // Cheapest-first order; capped hotel set keeps responses lean.
        .sort((a: any, b: any) => a.price - b.price)
        .slice(0, 40);

      return {
        success: true,
        providerId: this.providerId,
        providerName: this.providerName,
        data: mapped,
        timestamp: new Date(),
        metadata: {
          engine: 'hotels/rates',
          source: 'nuitee',
          sandbox: response?.sandbox ?? false,
        },
      };
    } catch (error) {
      return {
        ...this.disabledResult(),
        error: `Failed Nuitee rates search: ${(error as Error).message}`,
      };
    }
  }

  /**
   * Prebook — revalidates price/availability and freezes the quote
   * (spec points 8, 27). Preserves prebookId/transactionId because
   * Nuitee docs state they are NOT recoverable after the response is lost.
   */
  async prebookHotel(input: {
    rateId: string;
    guests?: number;
    rooms?: number;
  }): Promise<NuiteePrebookResult> {
    if (!this.apiKey) {
      return { success: false, providerId: this.providerId, error: 'NUITEE_API_KEY missing' };
    }
    try {
      const body = {
        offerId: input.rateId,
        rooms: input.rooms ?? 1,
        adults: input.guests ?? 2,
        usePaymentSdk: false,
      };
      const response = await this.nuiteeFetch('/rates/prebook', {
        method: 'POST',
        headers: this.headers(),
        body: JSON.stringify(body),
      });
      const data = response?.data ?? response;
      return {
        success: true,
        providerId: this.providerId,
        prebookId: data?.prebookId,
        transactionId: data?.transactionId,
        priceChanged: Boolean(data?.priceChanged),
        newPrice:
          this.numberOrUndefined(data?.net) ??
          this.firstAmount(data?.retailRate?.total),
        currency: data?.currency ?? data?.retailRate?.total?.[0]?.currency,
        expiresAt: data?.expiresAt ?? data?.holdExpiresAt,
      };
    } catch (error) {
      return {
        success: false,
        providerId: this.providerId,
        error: `Nuitee prebook failed: ${(error as Error).message}`,
      };
    }
  }

  /**
   * Book with the ACC_CREDIT_CARD strategy — TokiGo is merchant of
   * record for the customer payment; sandbox keys charge the attached
   * hidden test account card (spec point 27 / O.3).
   */
  async bookHotel(input: {
    prebookId: string;
    transactionId: string;
    holderName: string;
    holderEmail?: string;
    guestNames: string[];
  }): Promise<ProviderResult<any>> {
    if (!this.apiKey) {
      return {
        ...this.disabledResult(),
        error: 'NUITEE_API_KEY missing',
      };
    }
    try {
      const first = input.holderName.trim().split(' ')[0];
      const last = input.holderName.trim().split(' ').slice(1).join(' ') || '-';
      const body = {
        prebookId: input.prebookId,
        transactionId: input.transactionId,
        payment: { method: 'ACC_CREDIT_CARD' },
        holder: { firstName: first, lastName: last, email: input.holderEmail ?? 'guest@tokigo.app' },
        guests: input.guestNames.map((name, i) => ({
          name: {
            firstName: name.split(' ')[0],
            lastName: name.split(' ').slice(1).join(' ') || '-',
          },
          adult: i === 0,
        })),
      };
      const response = await this.nuiteeFetch('/rates/book', {
        method: 'POST',
        headers: this.headers(),
        body: JSON.stringify(body),
      });
      const data = response?.data ?? response;
      return {
        success: true,
        providerId: this.providerId,
        providerName: this.providerName,
        data: {
          bookingId: data?.bookingId ?? data?.id,
          reference: data?.hotelConfirmationNumber ?? data?.confirmationCode,
          status: data?.status ?? 'CONFIRMED',
          total:
            this.firstAmount(data?.total) ??
            this.numberOrUndefined(data?.net),
          currency: data?.currency ?? data?.total?.[0]?.currency,
        },
        timestamp: new Date(),
      };
    } catch (error) {
      return {
        success: false,
        providerId: this.providerId,
        providerName: this.providerName,
        error: `Nuitee book failed: ${(error as Error).message}`,
        timestamp: new Date(),
      };
    }
  }

  /** Hotel metadata list (names/photos/facilities) for detail pages. */
  async hotelContent(city: string, country?: string): Promise<ProviderResult<any>> {
    if (!this.apiKey) {
      return { ...this.disabledResult(), error: 'NUITEE_API_KEY missing' };
    }
    try {
      const query = new URLSearchParams({ cityName: city });
      if (country ?? this.countryFor(city)) {
        query.set('countryCode', country ?? this.countryFor(city)!);
      }
      const response = await this.nuiteeFetch(`/data/hotels?${query.toString()}`, {
        method: 'GET',
        headers: this.headers(),
      });
      const hotels = response?.data ?? response?.hotels ?? [];
      return {
        success: true,
        providerId: this.providerId,
        providerName: this.providerName,
        data: hotels.slice(0, 50),
        timestamp: new Date(),
      };
    } catch (error) {
      return {
        success: false,
        providerId: this.providerId,
        providerName: this.providerName,
        error: `Nuitee content failed: ${(error as Error).message}`,
        timestamp: new Date(),
      };
    }
  }

  // ------------------------------------------------------------------
  // Mapping helpers
  // ------------------------------------------------------------------

  /** Flat list of {hotelId, offerId, roomType, rate} entries from the live shape. */
  extractRateResults(response: any): any[] {
    // Live shape wraps the array in `data`; fixtures keep the raw array.
    const data = Array.isArray(response?.data)
      ? response.data
      : response?.data?.data;
    if (!Array.isArray(data)) return [];
    const entries: any[] = [];
    for (const hotel of data) {
      for (const room of hotel?.roomTypes ?? []) {
        const rates = room?.rates ?? [];
        // Cheapest rate per room type keeps the offer list scannable.
        const cheapest = rates.reduce(
          (min: any, r: any) =>
            (this.firstAmount(r?.retailRate?.total) ?? Infinity) <
            (this.firstAmount(min?.retailRate?.total) ?? Infinity)
              ? r
              : min,
          rates[0],
        );
        if (cheapest?.rateId) {
          entries.push({
            hotelId: hotel?.hotelId,
            offerId: room?.offerId,
            // Live shape: room display name lives on the rate itself.
            roomType:
              room?.roomTypeName ??
              room?.roomType?.name ??
              cheapest?.name ??
              cheapest?.boardName,
            rate: cheapest,
          });
        }
      }
    }
    return entries;
  }

  private hotelMetaIndex(response: any): Map<string, any> {
    // Live shape nests hotels under data.hotels; fixtures keep response.hotels.
    const hotels = response?.hotels ?? response?.data?.hotels ?? [];
    const index = new Map<string, any>();
    for (const h of hotels) {
      index.set(String(h?.id ?? h?.hotelId), h);
    }
    return index;
  }

  /** Maps one {hotelId, roomType, rate} entry to the shared offer shape. */
  mapRateToOffer(
    entry: any,
    hotelMeta: Map<string, any>,
    params: NuiteeSearchParams,
    checkInStr: string,
    checkOutStr: string,
  ) {
    const rate = entry?.rate;
    const rateId = rate?.rateId;
    if (!rateId) return null;

    // Live metadata shape (snake_case): main_photo / city_name / review_count.
    const meta = hotelMeta.get(String(entry?.hotelId)) ?? {};
    const total = this.firstAmount(rate?.retailRate?.total);
    const currency = rate?.retailRate?.total?.[0]?.currency ?? 'USD';
    const refundable = rate?.cancellationPolicies?.refundableTag === 'RFN';
    const rating = typeof meta?.rating === 'number' ? meta.rating : undefined;
    // Nuitee rates hotels on a 10 scale — halve for the 5-star display scale.
    const displayRating = rating !== undefined ? Math.min(5, rating / 2) : undefined;
    const roomName =
      entry?.roomType ?? rate?.name ?? rate?.boardName ?? 'Standard Room';

    // 3D — provider-verbatim detail fields (never invented):
    // taxesAndFees: the first total entry Nuitee quotes (amount/currency/included).
    const taxes = rate?.retailRate?.taxesAndFees?.[0];
    const taxesAndFees =
      typeof taxes?.amount === 'number'
        ? {
            amount: taxes.amount,
            currency: taxes.currency ?? currency,
            included: taxes.included === true,
            description: taxes.description,
          }
        : undefined;
    // Cancellation: the LAST policy window (closest to check-in) verbatim.
    const policyInfos = rate?.cancellationPolicies?.cancelPolicyInfos ?? [];
    const lastPolicy = policyInfos.length
      ? policyInfos[policyInfos.length - 1]
      : undefined;
    const cancellationPolicy = lastPolicy
      ? {
          refundableUntil: lastPolicy.cancelTime,
          feeAmount:
            typeof lastPolicy.amount === 'number' ? lastPolicy.amount : undefined,
          feeCurrency: lastPolicy.currency,
          timezone: lastPolicy.timezone,
        }
      : undefined;

    return {
      id: rateId,
      type: 'hotel',
      providerId: this.providerId,
      providerName: this.providerName,
      title: meta?.name ?? `Hotel ${entry?.hotelId}`,
      subtitle: [
        meta?.city_name ?? meta?.address?.cityName ?? params.city,
        displayRating !== undefined ? `${displayRating.toFixed(1)}★` : null,
        meta?.stars ? `${meta.stars}★ hotel` : null,
        refundable ? 'Free cancellation' : null,
      ]
        .filter(Boolean)
        .join(' · '),
      description: meta?.description ?? '',
      imageUrl: meta?.main_photo ?? meta?.images?.[0]?.url ?? meta?.thumbnail,
      price: total ?? 0,
      currency,
      rating: displayRating,
      reviewCount: meta?.review_count ?? meta?.reviewCount,
      city: meta?.city_name ?? meta?.address?.cityName ?? params.city,
      country: meta?.country_code ?? meta?.address?.countryName,
      checkIn: checkInStr,
      checkOut: checkOutStr,
      roomType: roomName,
      amenities: (meta?.facilities ?? meta?.amenities ?? []).slice(0, 6),
      // Provider provenance (spec point 7): raw ids survive as metadata.
      metadata: {
        providerRateId: rateId,
        providerOfferId: entry?.offerId,
        providerHotelId: entry?.hotelId,
        retrievedAt: new Date().toISOString(),
        expiresAt: new Date(Date.now() + 30 * 60 * 1000).toISOString(),
        refundable,
        paymentType: 'ACC_CREDIT_CARD',
        boardType: rate?.boardType,
        // 3D — verbatim detail fields for the details page.
        stars:
          typeof meta?.stars === 'number' ? meta.stars : undefined,
        boardName: rate?.boardName,
        taxesAndFees,
        cancellationPolicy,
      },
    };
  }

  private firstAmount(total: any): number | undefined {
    const amount = total?.[0]?.amount;
    return typeof amount === 'number' ? amount : undefined;
  }

  private numberOrUndefined(value: any): number | undefined {
    return typeof value === 'number' ? value : undefined;
  }

  private countryFor(city: string): string | undefined {
    return CITY_COUNTRIES[(city || '').trim().toLowerCase()];
  }

  private disabledResult(): ProviderResult<any[]> {
    return {
      success: false,
      providerId: this.providerId,
      providerName: this.providerName,
      data: [],
      error: 'NUITEE_API_KEY missing',
      timestamp: new Date(),
    };
  }

  private dateStr(value: Date | string): string {
    return value instanceof Date ? value.toISOString().split('T')[0] : String(value).split('T')[0];
  }
}
