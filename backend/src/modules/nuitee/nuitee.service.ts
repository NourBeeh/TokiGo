import { Injectable, Logger, Optional } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { CacheService } from '../cache/cache.service';
import { HotelProvider } from '../../common/providers/hotel.provider';
import { ProviderResult } from '../../common/providers/provider.result';
import {
  termsFromChangedFlags,
  termsVersionOf,
} from '../../common/pricing/offer-terms';
import { NuiteeClient } from './nuitee.client';
import { countryFor } from './nuitee.cities';
import {
  dateStr,
  extractRateResults,
  hotelMetaIndex,
  mapHotelOffers,
  numberOrUndefined,
} from './nuitee.mapper';
import {
  NuiteeBookingGuest,
  NuiteeBookingHolder,
  NuiteeHotelOffer,
  NuiteePrebookResult,
  NuiteeSearchParams,
} from './nuitee.types';
import { DEFAULT_MARKET } from '../../common/market/market-context';

export type {
  NuiteeHotelOffer,
  NuiteePrebookResult,
  NuiteeSearchParams,
} from './nuitee.types';

/**
 * Nuitee Connect hotel provider (spec point 25).
 *
 * Orchestration only: it decides WHICH call to make and what an honest answer
 * looks like. Transport lives in `nuitee.client.ts`, payload mapping in
 * `nuitee.mapper.ts`, the city→country table in `nuitee.cities.ts`.
 *
 * Implements the shared HotelProvider contract so it can be registered,
 * routed and replaced without touching domain or Flutter code.
 *
 * Workflow mapping (Nuitee Connect REST v3):
 *   searchHotels  -> POST /v3.0/hotels/rates   (rates search)
 *   prebookHotel  -> POST /v3.0/rates/prebook
 *   bookHotel     -> POST /v3.0/rates/book    (ACC_CREDIT_CARD sandbox)
 *   hotelContent  -> GET  /v3.0/data/hotels    (metadata list)
 */
@Injectable()
export class NuiteeService implements HotelProvider {
  providerId = 'nuitee';
  providerName = 'Nuitee Connect';

  private readonly logger = new Logger(NuiteeService.name);
  private readonly client: NuiteeClient;
  private readonly contentCache?: CacheService;
  /** Settlement currency requested from Nuitee. Never the display currency. */
  private readonly settlementCurrency: string;

  constructor(
    configService: ConfigService,
    @Optional() contentCache?: CacheService,
  ) {
    this.client = new NuiteeClient(configService);
    this.contentCache = contentCache;
    const configured = configService.get<string>('NUITEE_CURRENCY');
    this.settlementCurrency =
      typeof configured === 'string' && /^[A-Za-z]{3}$/.test(configured.trim())
        ? configured.trim().toUpperCase()
        : 'USD';
  }

  /**
   * Rates search mapped into the shared hotel offer shape.
   *
   * One row per hotel: the cheapest live offer is the row's identity, and ALL
   * valid room-type offers ride along in `offers` for the details selector.
   * The hotel exists only because Nuitee returned at least one priced offer.
   *
   * Pagination is sequential and bounded. A full page means "there may be
   * more", so the next `offset` is fetched; a short page completes the set. A
   * failed page or the page cap leaves `complete: false` — the caller must
   * never present that as the whole market, and SearchService must not cache
   * it.
   */
  async searchHotels(params: NuiteeSearchParams): Promise<ProviderResult<any[]>> {
    if (!this.client.enabled) {
      return this.disabledResult();
    }

    const checkInStr = dateStr(params.checkIn);
    const checkOutStr = dateStr(params.checkOut);
    const occupancy = resolveOccupancies(params);
    if (!occupancy.ok) {
      return {
        ...this.disabledResult(),
        error: occupancy.error,
      };
    }

    const pageSize = this.boundedEnv('NUITEE_RATES_PAGE_SIZE', 50, 1, 5000);
    const maxPages = this.boundedEnv('NUITEE_RATES_MAX_PAGES', 4, 1, 50);
    const nationality = (
      params.nationality ??
      params.market ??
      DEFAULT_MARKET.marketCountry
    )
      .trim()
      .toUpperCase();
    const country = (
      params.country ??
      countryFor(params.city) ??
      DEFAULT_MARKET.marketCountry
    )
      .trim()
      .toUpperCase();

    const bodyBase = {
      cityName: params.city,
      countryCode: country,
      checkin: checkInStr,
      checkout: checkOutStr,
      currency: this.settlementCurrency,
      guestNationality: nationality,
      occupancies: occupancy.value,
      includeHotelData: true,
    };

    const entries: ReturnType<typeof extractRateResults> = [];
    const hotelMeta = new Map<string, any>();
    const failedOffsets: number[] = [];
    let pagesFetched = 0;
    let offset = 0;
    let complete = false;
    let sandbox = false;

    while (pagesFetched < maxPages) {
      let response: any;
      try {
        response = await this.client.request('/hotels/rates', {
          method: 'POST',
          body: { ...bodyBase, limit: pageSize, offset },
        });
      } catch (error) {
        // Keep the real offers from earlier pages; mark the set incomplete.
        failedOffsets.push(offset);
        this.logger.warn(
          `Rates page offset=${offset} failed: ${(error as Error).message}`,
        );
        break;
      }

      pagesFetched += 1;
      sandbox = sandbox || response?.sandbox === true;
      for (const [hotelId, meta] of hotelMetaIndex(response)) {
        hotelMeta.set(hotelId, meta);
      }
      entries.push(...extractRateResults(response));

      const hotelsOnPage = Array.isArray(response?.data)
        ? response.data.length
        : 0;
      if (hotelsOnPage < pageSize) {
        complete = true;
        break;
      }
      offset += pageSize;
    }

    // The cap was reached with a full page still on the table: more inventory
    // exists but was deliberately not fetched. Never call that complete.
    const capReached = !complete && failedOffsets.length === 0;

    if (params.language === 'ar') {
      const hotelIds = [...hotelMeta.keys()];
      const arabicMeta = await this.localizedHotelMetadata(hotelIds, 'ar');
      for (const [hotelId, localized] of arabicMeta) {
        const current = hotelMeta.get(hotelId) ?? {};
        hotelMeta.set(hotelId, {
          ...current,
          ...localized,
          nameEn: current.name,
          nameAr: localized.name,
          name: localized.name,
        });
      }
    }

    const mapped = mapHotelOffers(
      entries,
      hotelMeta,
      params,
      checkInStr,
      checkOutStr,
      this,
    ).sort((a, b) => a.price - b.price || a.id.localeCompare(b.id));

    if (mapped.length === 0 && failedOffsets.length > 0) {
      return {
        ...this.disabledResult(),
        error: `Failed Nuitee rates search (page offset ${failedOffsets[0]})`,
      };
    }

    return {
      success: true,
      providerId: this.providerId,
      providerName: this.providerName,
      data: mapped,
      timestamp: new Date(),
      metadata: {
        engine: 'hotels/rates',
        source: 'nuitee',
        sandbox,
        complete,
        capReached,
        pagesFetched,
        failedOffsets,
        hotelsFetched: new Set(
          entries.map((entry) => String(entry.hotelId ?? '')),
        ).size,
        requestedCurrency: this.settlementCurrency,
        guestNationality: nationality,
        occupancies: occupancy.value,
      },
    };
  }

  /**
   * PROMOTIONAL minimum-rate discovery (Nearby Stays, R3).
   *
   * `POST /hotels/min-rates` answers with the cheapest rate for each hotel in
   * a list over ONE date window. The Home price is a one-night discovery
   * figure, so the caller invokes this once per one-night window and keeps the
   * minimum itself — never a multi-night total divided by a window.
   *
   * This is NOT the booking path: no rate/offer id is returned to the caller
   * and the amount is never replayed as a payable offer. Live booking keeps
   * using `searchHotels` → `prebookHotel`.
   */
  async minRates(input: {
    hotelIds: string[];
    checkIn: string;
    checkOut: string;
    currency: string;
    guestNationality: string;
    occupancies: Array<{ adults: number; children?: number[] }>;
    timeout?: number;
  }): Promise<ProviderResult<Array<{ hotelId: string; price: number }>>> {
    if (!this.client.enabled) {
      return { ...this.disabledResult(), error: 'NUITEE_API_KEY missing' };
    }
    try {
      const response = await this.client.request('/hotels/min-rates', {
        method: 'POST',
        body: {
          hotelIds: input.hotelIds,
          occupancies: input.occupancies,
          checkin: input.checkIn,
          checkout: input.checkOut,
          currency: input.currency,
          guestNationality: input.guestNationality,
          timeout: input.timeout ?? 10,
        },
      });
      const data = Array.isArray(response?.data) ? response.data : [];
      const prices = data
        .map((entry: any) => ({
          hotelId: String(entry?.hotelId ?? ''),
          price: typeof entry?.price === 'number' ? entry.price : Number.NaN,
        }))
        .filter(
          (entry: { hotelId: string; price: number }) =>
            entry.hotelId.length > 0 && Number.isFinite(entry.price) && entry.price > 0,
        );
      return {
        success: true,
        providerId: this.providerId,
        providerName: this.providerName,
        data: prices,
        timestamp: new Date(),
        metadata: { engine: 'hotels/min-rates', source: 'nuitee' },
      };
    } catch (error) {
      const message = (error as Error).message;
      this.logger.warn(`Minimum-rate search failed: ${message}`);
      return {
        ...this.disabledResult(),
        error: `Failed Nuitee minimum-rate search: ${message}`,
      };
    }
  }

  /**
   * Prebook — revalidates price/availability and freezes the quote
   * (spec points 8, 27).
   *
   * Contract (LiteAPI `POST /rates/prebook`): the request is exactly
   * `{ offerId, usePaymentSdk }`. `offerId` is the room type's offer id from
   * the rates search — NOT a rate id. With `usePaymentSdk: false` (the
   * merchant-of-record flow) the response has no `transactionId`; it must
   * never be required to book.
   */
  async prebookHotel(input: {
    offerId: string;
  }): Promise<NuiteePrebookResult> {
    if (!this.client.enabled) {
      return {
        success: false,
        providerId: this.providerId,
        error: 'NUITEE_API_KEY missing',
      };
    }
    const offerId = input.offerId?.trim();
    if (!offerId) {
      return {
        success: false,
        providerId: this.providerId,
        error: 'Nuitee prebook requires an offerId',
      };
    }
    try {
      const response = await this.client.request('/rates/prebook', {
        method: 'POST',
        body: {
          offerId,
          usePaymentSdk: false,
        },
      });
      const data = response?.data ?? response;
      const prebookId =
        typeof data?.prebookId === 'string' ? data.prebookId : undefined;
      const price = numberOrUndefined(data?.price);
      const currency =
        typeof data?.currency === 'string' ? data.currency : undefined;
      // A prebook without an id, a final price or a currency cannot be booked
      // or compared to the search quote. Reporting success would invent both.
      if (!prebookId || price === undefined || !currency) {
        return {
          success: false,
          providerId: this.providerId,
          error: 'Nuitee prebook returned no bookable quote',
        };
      }
      const difference = numberOrUndefined(data?.priceDifferencePercent);
      // Nuitee reports condition changes as booleans relative to the search
      // quote. Only true flags are facts; a missing flag is not a value and
      // never becomes a fabricated "unchanged" condition.
      const terms = termsFromChangedFlags({
        cancellationChanged: data?.cancellationChanged,
        boardChanged: data?.boardChanged,
      });
      return {
        success: true,
        providerId: this.providerId,
        prebookId,
        transactionId:
          typeof data?.transactionId === 'string'
            ? data.transactionId
            : undefined,
        hotelId: typeof data?.hotelId === 'string' ? data.hotelId : undefined,
        checkin: typeof data?.checkin === 'string' ? data.checkin : undefined,
        checkout:
          typeof data?.checkout === 'string' ? data.checkout : undefined,
        roomCount: Array.isArray(data?.roomTypes)
          ? data.roomTypes.length
          : undefined,
        priceDifferencePercent: difference,
        priceChanged:
          data?.priceChanged === true || (difference ?? 0) > 0,
        cancellationChanged: data?.cancellationChanged === true,
        boardChanged: data?.boardChanged === true,
        newPrice: price,
        currency,
        terms,
        termsVersion: termsVersionOf(terms),
        ...(Object.keys(terms).length > 0
          ? { changedTerms: Object.keys(terms) }
          : {}),
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
   * Book with the ACC_CREDIT_CARD strategy — TokiGo is merchant of record for
   * the customer payment; sandbox keys charge the attached hidden test account
   * card (spec point 27 / O.3).
   *
   * Contract (LiteAPI `POST /rates/book`): `prebookId`, `holder`
   * (firstName/lastName/email/phone), one `guests[]` entry per room
   * (`occupancyNumber` + names/email) and `payment.method`. ACC_CREDIT_CARD
   * does not take a `transactionId`.
   */
  async bookHotel(input: {
    prebookId: string;
    holder: NuiteeBookingHolder;
    guests: NuiteeBookingGuest[];
    /** Nuitee's documented idempotency key; duplicate submissions return 4005. */
    clientReference?: string;
    /** Up to five `^[A-Z0-9_-]+$` labels persisted with the booking. */
    customTags?: Record<string, string>;
  }): Promise<ProviderResult<any>> {
    if (!this.client.enabled) {
      return {
        ...this.disabledResult(),
        error: 'NUITEE_API_KEY missing',
      };
    }

    const holder = normalizeHolder(input.holder);
    if (!holder) {
      return {
        ...this.disabledResult(),
        error:
          'Nuitee booking requires the holder first/last name, email and phone',
      };
    }
    const guests = (input.guests ?? [])
      .map((guest) => normalizeGuest(guest))
      .filter((guest): guest is NuiteeBookingGuest => guest !== null);
    if (guests.length === 0) {
      return {
        ...this.disabledResult(),
        error: 'Nuitee booking requires at least one room guest',
      };
    }

    try {
      const response = await this.client.request('/rates/book', {
        method: 'POST',
        body: {
          prebookId: input.prebookId,
          ...(input.clientReference
            ? { clientReference: input.clientReference }
            : {}),
          ...(input.customTags && Object.keys(input.customTags).length > 0
            ? { customTags: input.customTags }
            : {}),
          holder,
          guests,
          payment: { method: 'ACC_CREDIT_CARD' },
        },
      });
      const data = response?.data ?? response;
      const bookingId =
        typeof data?.bookingId === 'string' ? data.bookingId : undefined;
      const confirmation =
        typeof data?.hotelConfirmationCode === 'string'
          ? data.hotelConfirmationCode
          : undefined;
      return {
        success: true,
        providerId: this.providerId,
        providerName: this.providerName,
        data: {
          bookingId,
          // The hotel confirmation code is not issued at booking time; an
          // absent code stays absent (the provider booking id is the honest
          // fallback reference, never an invented code).
          reference: confirmation ?? bookingId ?? '',
          hotelConfirmationCode: confirmation,
          supplierBookingId:
            typeof data?.supplierBookingId === 'string'
              ? data.supplierBookingId
              : undefined,
          status:
            typeof data?.status === 'string' ? data.status : undefined,
          total: numberOrUndefined(data?.price),
          currency:
            typeof data?.currency === 'string' ? data.currency : undefined,
          checkin: typeof data?.checkin === 'string' ? data.checkin : undefined,
          checkout:
            typeof data?.checkout === 'string' ? data.checkout : undefined,
          raw: data,
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

  /**
   * Hotel metadata list (names/photos/facilities) for detail pages.
   *
   * `/data/hotels` is paginated with `offset`/`limit` (provider default 200,
   * maximum 5000). A single 50-row slice used to make a city look "synced"
   * while most of its inventory was never fetched, so this walks every page
   * up to a bounded per-city cap, retries transient failures, and reports
   * whether the result is complete.
   */
  async hotelContent(
    city: string,
    country?: string,
    language?: string,
  ): Promise<ProviderResult<any>> {
    if (!this.client.enabled) {
      return { ...this.disabledResult(), error: 'NUITEE_API_KEY missing' };
    }
    const pageSize = this.boundedEnv('NUITEE_HOTEL_PAGE_SIZE', 200, 1, 5000);
    const maxHotels = this.boundedEnv(
      'NUITEE_HOTEL_MAX_PER_CITY',
      2000,
      pageSize,
      5000,
    );

    const hotels: any[] = [];
    const failedPages: number[] = [];
    let offset = 0;
    let pagesFetched = 0;
    let totalReported: number | null = null;

    try {
      while (offset < maxHotels) {
        const limit = Math.min(pageSize, maxHotels - offset);
        const page = await this.fetchHotelPage(
          city,
          country,
          language,
          offset,
          limit,
        );
        if (!page) {
          failedPages.push(offset);
          break;
        }
        pagesFetched += 1;
        const rows = this.hotelRows(page);
        const reported = Number(page?.total ?? page?.meta?.total);
        if (Number.isFinite(reported) && reported >= 0) {
          totalReported = reported;
        }
        if (rows.length === 0) break;
        hotels.push(...rows);
        if (rows.length < limit) break;
        offset += rows.length;
        if (totalReported !== null && offset >= totalReported) break;
      }

      if (hotels.length === 0 && failedPages.length > 0) {
        return {
          success: false,
          providerId: this.providerId,
          providerName: this.providerName,
          error: `Nuitee content failed after retries (city=${city})`,
          timestamp: new Date(),
          metadata: { pagesFetched, failedPages, complete: false },
        };
      }

      // The walk can end four ways: an empty page, a short page, the
      // provider's reported total, or the per-city cap. The first three prove
      // we saw everything. Without a reported total, reaching the cap means
      // inventory may continue past it, so the result must not claim to be
      // complete.
      const truncatedAtCap =
        failedPages.length === 0 &&
        offset >= maxHotels &&
        (totalReported === null || offset < totalReported);

      const complete =
        failedPages.length === 0 &&
        !truncatedAtCap &&
        (totalReported === null || hotels.length >= totalReported);
      return {
        success: true,
        providerId: this.providerId,
        providerName: this.providerName,
        data: hotels,
        timestamp: new Date(),
        metadata: {
          complete,
          truncatedAtCap,
          pagesFetched,
          failedPages,
          totalReported,
          fetched: hotels.length,
          pageSize,
          maxHotels,
        },
      };
    } catch (error) {
      return {
        success: false,
        providerId: this.providerId,
        providerName: this.providerName,
        error: `Nuitee content failed: ${(error as Error).message}`,
        timestamp: new Date(),
        metadata: { pagesFetched, failedPages, complete: false },
      };
    }
  }

  /** One metadata page with two bounded retries for transient failures. */
  private async fetchHotelPage(
    city: string,
    country: string | undefined,
    language: string | undefined,
    offset: number,
    limit: number,
  ): Promise<any | null> {
    const query = new URLSearchParams({
      cityName: city,
      offset: String(offset),
      limit: String(limit),
    });
    const countryCode = country ?? countryFor(city);
    if (countryCode) query.set('countryCode', countryCode);
    if (language) query.set('language', language);
    const path = `/data/hotels?${query.toString()}`;

    let lastError: Error | null = null;
    for (let attempt = 0; attempt < 3; attempt += 1) {
      try {
        return await this.client.request(path, { method: 'GET' });
      } catch (error) {
        lastError = error as Error;
        if (attempt < 2) {
          await new Promise((resolve) =>
            setTimeout(resolve, 300 * Math.pow(3, attempt)),
          );
        }
      }
    }
    this.logger.warn(
      `Nuitee content page offset=${offset} failed: ${lastError?.message ?? 'unknown'}`,
    );
    return null;
  }

  private hotelRows(page: any): any[] {
    if (Array.isArray(page?.data)) return page.data;
    if (Array.isArray(page?.hotels)) return page.hotels;
    if (Array.isArray(page?.data?.hotels)) return page.data.hotels;
    return [];
  }

  private boundedEnv(
    name: string,
    fallback: number,
    min: number,
    max: number,
  ): number {
    const value = Number(process.env[name]);
    if (!Number.isFinite(value)) return fallback;
    return Math.min(Math.max(Math.floor(value), min), max);
  }

  private async localizedHotelMetadata(
    hotelIds: string[],
    language: 'ar',
  ): Promise<Map<string, Record<string, any>>> {
    const localized = new Map<string, Record<string, any>>();
    const missing: string[] = [];

    for (const hotelId of hotelIds) {
      const key = localizedHotelCacheKey(language, hotelId);
      try {
        const cached = await this.contentCache?.get<Record<string, any>>(key);
        if (cached) {
          if (cached.unavailable !== true) localized.set(hotelId, cached);
          continue;
        }
      } catch (error) {
        this.logger.warn(
          `Localized hotel cache read failed for ${hotelId}: ${(error as Error).message}`,
        );
      }
      missing.push(hotelId);
    }

    if (missing.length === 0) return localized;

    try {
      const query = new URLSearchParams({
        hotelIds: missing.join(','),
        language,
      });
      const response = await this.client.request(
        `/data/hotels?${query.toString()}`,
        { method: 'GET' },
      );
      const hotels = response?.data ?? response?.hotels ?? [];
      if (!Array.isArray(hotels)) {
        this.logger.warn('Nuitee localized hotel content was not a list');
        return localized;
      }

      for (const hotel of hotels) {
        const id = String(hotel?.id ?? hotel?.hotelId ?? '');
        const name = typeof hotel?.name === 'string' ? hotel.name.trim() : '';
        if (!id || !missing.includes(id)) continue;
        if (!name || !containsArabicScript(name)) {
          try {
            await this.contentCache?.set(
              localizedHotelCacheKey(language, id),
              { unavailable: true },
              24 * 60 * 60,
            );
          } catch (error) {
            this.logger.warn(
              `Localized hotel cache write failed for ${id}: ${(error as Error).message}`,
            );
          }
          continue;
        }

        localized.set(id, { ...hotel, name });
        try {
          await this.contentCache?.set(
            localizedHotelCacheKey(language, id),
            { ...hotel, name },
            7 * 24 * 60 * 60,
          );
        } catch (error) {
          this.logger.warn(
            `Localized hotel cache write failed for ${id}: ${(error as Error).message}`,
          );
        }
      }

      const returnedIds = new Set(
        hotels
          .map((hotel: any) => String(hotel?.id ?? hotel?.hotelId ?? ''))
          .filter(Boolean),
      );
      for (const hotelId of missing) {
        if (returnedIds.has(hotelId)) continue;
        try {
          await this.contentCache?.set(
            localizedHotelCacheKey(language, hotelId),
            { unavailable: true },
            24 * 60 * 60,
          );
        } catch (error) {
          this.logger.warn(
            `Localized hotel cache write failed for ${hotelId}: ${(error as Error).message}`,
          );
        }
      }
    } catch (error) {
      this.logger.warn(
        `Nuitee Arabic hotel content unavailable: ${(error as Error).message}`,
      );
    }

    return localized;
  }

  /** Honest "provider disabled" payload — never fake availability. */
  /** Minimal live tracking (5C) — fetches booking details from provider. */
  async trackBooking(bookingId: string): Promise<ProviderResult<any>> {
    if (!this.client.enabled) return { ...this.disabledResult(), error: 'NUITEE_API_KEY missing' };
    try {
      const response = await this.client.request(`/bookings/${bookingId}`, { method: 'GET' });
      return {
        success: true,
        providerId: this.providerId,
        providerName: this.providerName,
        data: response?.data ?? response,
        timestamp: new Date(),
      };
    } catch (error: any) {
      return { ...this.disabledResult(), error: `Nuitee track failed: ${error.message}` };
    }
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
}

function localizedHotelCacheKey(language: string, hotelId: string): string {
  return `nuitee:hotel-content:${language}:${hotelId}`;
}

function containsArabicScript(value: string): boolean {
  return /[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]/.test(
    value,
  );
}

type ResolvedOccupancy = { adults: number; children: number[] };

/**
 * Nuitee takes ONE occupancy object per room, each with `adults` and the exact
 * child ages. A multi-room request without per-room occupancies cannot be
 * expressed honestly (distributing guests would be invented), so it is
 * rejected instead of collapsing into one invalid room.
 */
function resolveOccupancies(
  params: NuiteeSearchParams,
):
  | { ok: true; value: ResolvedOccupancy[] }
  | { ok: false; error: string } {
  const supplied = Array.isArray(params.occupancies)
    ? params.occupancies
    : [];

  if (supplied.length > 0) {
    const value: ResolvedOccupancy[] = [];
    for (const room of supplied) {
      const adults = Number(room?.adults);
      if (!Number.isInteger(adults) || adults < 1 || adults > 20) {
        return {
          ok: false,
          error: 'Each room requires between 1 and 20 adults',
        };
      }
      const children = Array.isArray(room?.children) ? room.children : [];
      for (const age of children) {
        if (!Number.isInteger(age) || age < 0 || age > 17) {
          return {
            ok: false,
            error: 'Each child requires an exact age between 0 and 17',
          };
        }
      }
      value.push({ adults, children: [...children] });
    }
    const rooms = params.rooms ?? value.length;
    if (rooms !== value.length) {
      return {
        ok: false,
        error: 'rooms must equal the number of room occupancies',
      };
    }
    return { ok: true, value };
  }

  const rooms = params.rooms ?? 1;
  if (rooms !== 1) {
    return {
      ok: false,
      error: 'A multi-room search requires one occupancy per room',
    };
  }
  const adults = params.guests ?? 2;
  if (!Number.isInteger(adults) || adults < 1 || adults > 20) {
    return {
      ok: false,
      error: 'A room requires between 1 and 20 adults',
    };
  }
  return { ok: true, value: [{ adults, children: [] }] };
}

function cleanText(value: any): string | undefined {
  return typeof value === 'string' && value.trim().length > 0
    ? value.trim()
    : undefined;
}

function normalizeHolder(holder: any): NuiteeBookingHolder | null {
  const firstName = cleanText(holder?.firstName);
  const lastName = cleanText(holder?.lastName);
  const email = cleanText(holder?.email);
  const phone = cleanText(holder?.phone);
  if (!firstName || !lastName || !email || !phone) return null;
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return null;
  return { firstName, lastName, email, phone };
}

function normalizeGuest(guest: any): NuiteeBookingGuest | null {
  const occupancyNumber = Number(guest?.occupancyNumber);
  if (!Number.isInteger(occupancyNumber) || occupancyNumber < 1) return null;
  const firstName = cleanText(guest?.firstName);
  const lastName = cleanText(guest?.lastName);
  const email = cleanText(guest?.email);
  if (!firstName || !lastName || !email) return null;
  return {
    occupancyNumber,
    firstName,
    lastName,
    email,
    phone: cleanText(guest?.phone),
    remarks: cleanText(guest?.remarks),
  };
}

