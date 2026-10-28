import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { HotelProvider } from '../../common/providers/hotel.provider';
import { ProviderResult } from '../../common/providers/provider.result';
import { NuiteeClient } from './nuitee.client';
import { countryFor } from './nuitee.cities';
import {
  cheapestPerHotel,
  dateStr,
  extractRateResults,
  firstAmount,
  hotelMetaIndex,
  mapRateToOffer,
  numberOrUndefined,
} from './nuitee.mapper';
import {
  NuiteeHotelOffer,
  NuiteePrebookResult,
  NuiteeSearchParams,
} from './nuitee.types';

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

  constructor(configService: ConfigService) {
    this.client = new NuiteeClient(configService);
  }

  /**
   * Rates search mapped into the shared hotel offer shape.
   * One offer per (hotel, cheapest rate) so every bookable hotel surfaces once
   * with its live provider price.
   */
  async searchHotels(params: NuiteeSearchParams): Promise<ProviderResult<any[]>> {
    if (!this.client.enabled) {
      return this.disabledResult();
    }

    const checkInStr = dateStr(params.checkIn);
    const checkOutStr = dateStr(params.checkOut);
    const guests = params.guests ?? 2;
    const rooms = params.rooms ?? 1;

    try {
      const body = {
        cityName: params.city,
        countryCode: params.country ?? countryFor(params.city) ?? 'EG',
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
      const response = await this.client.request('/hotels/rates', {
        method: 'POST',
        body,
      });

      const hotelMeta = hotelMetaIndex(response);
      const perHotel = cheapestPerHotel(extractRateResults(response));

      const mapped = [...perHotel.values()]
        .map(({ entry }) =>
          mapRateToOffer(
            entry,
            hotelMeta,
            params,
            checkInStr,
            checkOutStr,
            this,
          ),
        )
        .filter((offer): offer is NuiteeHotelOffer => offer !== null)
        // Cheapest-first order; capped hotel set keeps responses lean.
        .sort((a, b) => a.price - b.price)
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
      const message = (error as Error).message;
      this.logger.warn(`Rates search failed: ${message}`);
      return {
        ...this.disabledResult(),
        error: `Failed Nuitee rates search: ${message}`,
      };
    }
  }

  /**
   * Prebook — revalidates price/availability and freezes the quote
   * (spec points 8, 27). Preserves prebookId/transactionId because Nuitee
   * docs state they are NOT recoverable after the response is lost.
   */
  async prebookHotel(input: {
    rateId: string;
    guests?: number;
    rooms?: number;
  }): Promise<NuiteePrebookResult> {
    if (!this.client.enabled) {
      return {
        success: false,
        providerId: this.providerId,
        error: 'NUITEE_API_KEY missing',
      };
    }
    try {
      const response = await this.client.request('/rates/prebook', {
        method: 'POST',
        body: {
          offerId: input.rateId,
          rooms: input.rooms ?? 1,
          adults: input.guests ?? 2,
          usePaymentSdk: false,
        },
      });
      const data = response?.data ?? response;
      return {
        success: true,
        providerId: this.providerId,
        prebookId: data?.prebookId,
        transactionId: data?.transactionId,
        priceChanged: Boolean(data?.priceChanged),
        newPrice:
          numberOrUndefined(data?.net) ?? firstAmount(data?.retailRate?.total),
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
   * Book with the ACC_CREDIT_CARD strategy — TokiGo is merchant of record for
   * the customer payment; sandbox keys charge the attached hidden test account
   * card (spec point 27 / O.3).
   */
  async bookHotel(input: {
    prebookId: string;
    transactionId: string;
    holderName: string;
    holderEmail?: string;
    guestNames: string[];
  }): Promise<ProviderResult<any>> {
    if (!this.client.enabled) {
      return {
        ...this.disabledResult(),
        error: 'NUITEE_API_KEY missing',
      };
    }
    try {
      const response = await this.client.request('/rates/book', {
        method: 'POST',
        body: {
          prebookId: input.prebookId,
          transactionId: input.transactionId,
          payment: { method: 'ACC_CREDIT_CARD' },
          holder: {
            firstName: firstNameOf(input.holderName),
            lastName: lastNameOf(input.holderName),
            email: input.holderEmail ?? 'guest@tokigo.app',
          },
          guests: input.guestNames.map((name, i) => ({
            name: {
              firstName: firstNameOf(name),
              lastName: lastNameOf(name),
            },
            adult: i === 0,
          })),
        },
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
          total: firstAmount(data?.total) ?? numberOrUndefined(data?.net),
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
  async hotelContent(
    city: string,
    country?: string,
  ): Promise<ProviderResult<any>> {
    if (!this.client.enabled) {
      return { ...this.disabledResult(), error: 'NUITEE_API_KEY missing' };
    }
    try {
      const query = new URLSearchParams({ cityName: city });
      const countryCode = country ?? countryFor(city);
      if (countryCode) query.set('countryCode', countryCode);

      const response = await this.client.request(
        `/data/hotels?${query.toString()}`,
        { method: 'GET' },
      );
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

function firstNameOf(fullName: string): string {
  return fullName.trim().split(' ')[0];
}

/** Single-word holder names keep `-` rather than inventing a surname. */
function lastNameOf(fullName: string): string {
  return fullName.trim().split(' ').slice(1).join(' ') || '-';
}
