import {
  Controller,
  Post,
  Body,
  Req,
  UseGuards,
  UnauthorizedException,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { Request } from 'express';
import { OptionalJwtAuthGuard } from '../auth/optional-jwt-auth.guard';
import { RevalidateOfferDto } from '../../common/dto/revalidate-offer.dto';
import {
  priceChangePercent,
  priceDifference,
  termsVersionOf,
} from '../../common/pricing/offer-terms';
import { DuffelService } from '../duffel/duffel.service';
import { NuiteeService } from '../nuitee/nuitee.service';
import { NuiteeFlightService } from '../nuitee/nuitee.flight.service';

/**
 * Wire shape shared by every provider's revalidation result. The client binds
 * a customer acceptance to `providerId + offerId + currentPrice + currency +
 * termsVersion`; any later change produces a different signature and requires
 * a new explicit acceptance.
 */
export interface OfferRevalidationResponse {
  status: 'OK' | 'PRICE_CHANGED' | 'UNAVAILABLE' | 'ERROR';
  offerId: string;
  providerId?: string;
  offerType?: string;
  /** Current provider price (also exposed as `newPrice` on a change). */
  price?: number;
  newPrice?: number;
  oldPrice?: number;
  previousPrice?: number;
  currentPrice?: number;
  currency?: string;
  priceDifference?: number;
  priceChangePercent?: number | null;
  priceChanged?: boolean;
  termsChanged?: boolean;
  terms?: Record<string, any>;
  termsVersion?: string;
  changedTerms?: string[];
  checkedAt?: string;
  expiresAt?: string;
  cancellationChanged?: boolean;
  boardChanged?: boolean;
  reason?: string;
  error?: string;
}

/**
 * Offer revalidation endpoint (spec points 7-8): refreshes the authoritative
 * price/availability of a selected offer right before checkout.
 *
 * Flow: SELECTED -> PRICE_REVALIDATED. When the price moved, the response is
 * a structured PRICE_CHANGED outcome — payment must never proceed silently
 * on a changed amount.
 *
 * SECURITY: the endpoint is reachable anonymously because the mobile client
 * calls it without an Authorization header (Home live validation runs before
 * sign-in, and `OfferRevalidationService` posts no token). Identity is
 * therefore resolved OPTIONALLY, and the one operation that has a real-world
 * side effect — the Nuitee hotel prebook, which freezes a quote/inventory hold
 * at the provider — is refused for anonymous callers. Read-only checks
 * (Nuitee flight verify, Duffel offer fetch) stay available so the existing
 * booking and Home flows keep working.
 */
@Controller('offers')
export class OffersController {
  constructor(
    private readonly duffelService: DuffelService,
    private readonly nuiteeService: NuiteeService,
    private readonly nuiteeFlightService: NuiteeFlightService,
  ) {}

  @Post('revalidate')
  @UseGuards(OptionalJwtAuthGuard)
  @Throttle({ default: { ttl: 60_000, limit: 10 } })
  async revalidate(
    @Req() req: Request,
    @Body() dto: RevalidateOfferDto,
  ): Promise<OfferRevalidationResponse> {
    // P0-S3: the Nuitee hotel path calls `prebookHotel`, which freezes a quote
    // at the provider — a real inventory hold. It must never be reachable
    // anonymously. Read-only provider checks stay open so the existing mobile
    // flows (which send no Authorization header) keep working.
    const userId = (req.user as { id?: string } | undefined)?.id;
    if (dto.providerId === 'nuitee' && !userId) {
      throw new UnauthorizedException(
        'Authentication required to revalidate this offer.',
      );
    }

    try {
      // P3-D7: Nuitee flights have a documented READ-ONLY offer check
      // (`POST /flights/verify`). It takes only the offerId — no passenger
      // identities and no inventory hold — so the review page's Continue is no
      // longer blocked and no prebook is created here.
      if (dto.providerId === 'nuitee-flight') {
        const verified = await this.nuiteeFlightService.verifyFlightOffer(
          dto.offerId,
        );
        if (!verified.success) {
          return {
            status: 'UNAVAILABLE',
            offerId: dto.offerId,
            reason: verified.error,
          };
        }
        // Fail closed: a verify result without a positive price and the
        // provider's own currency is not a usable revalidation. Defaulting to
        // USD/0 here would let checkout proceed on a fabricated amount.
        const newPrice = verified.price;
        const currency = verified.currency;
        if (
          typeof newPrice !== 'number' ||
          !Number.isFinite(newPrice) ||
          newPrice <= 0 ||
          typeof currency !== 'string' ||
          currency.trim() === ''
        ) {
          return {
            status: 'UNAVAILABLE',
            offerId: dto.offerId,
            reason: 'Provider returned no usable price',
          };
        }
        const oldPrice =
          verified.oldPrice ??
          (dto.knownPrice !== undefined ? Number(dto.knownPrice) : undefined);
        const priceChanged =
          verified.priceChanged === true ||
          (oldPrice !== undefined && Math.abs(oldPrice - newPrice) > 0.01);
        const terms = verified.terms;
        const termsVersion =
          verified.termsVersion ??
          (terms ? termsVersionOf(terms) : undefined);
        const changedTerms = Array.isArray(verified.changedTerms)
          ? verified.changedTerms
          : [];
        const termsChanged = changedTerms.length > 0;
        const checkedAt = new Date().toISOString();
        const difference = priceDifference(oldPrice, newPrice);
        const percent = priceChangePercent(oldPrice, newPrice);

        if (priceChanged || termsChanged) {
          return {
            status: 'PRICE_CHANGED',
            offerId: dto.offerId,
            providerId: dto.providerId,
            offerType: dto.offerType,
            oldPrice,
            previousPrice: oldPrice,
            newPrice,
            currentPrice: newPrice,
            price: newPrice,
            currency,
            priceChanged,
            termsChanged,
            priceDifference: difference,
            priceChangePercent: percent,
            ...(terms ? { terms } : {}),
            ...(termsVersion ? { termsVersion } : {}),
            ...(changedTerms.length > 0 ? { changedTerms } : {}),
            ...(changedTerms.includes('cancellationChanged')
              ? { cancellationChanged: true }
              : {}),
            ...(changedTerms.includes('boardChanged')
              ? { boardChanged: true }
              : {}),
            expiresAt: verified.expiresAt,
            checkedAt,
          };
        }
        return {
          status: 'OK',
          offerId: dto.offerId,
          providerId: dto.providerId,
          offerType: dto.offerType,
          price: newPrice,
          currentPrice: newPrice,
          newPrice,
          currency,
          priceChanged: false,
          termsChanged: false,
          priceDifference: difference,
          priceChangePercent: percent,
          ...(terms ? { terms } : {}),
          ...(termsVersion ? { termsVersion } : {}),
          expiresAt: verified.expiresAt,
          checkedAt,
        };
      }

      // Nuitee hotels: `prebookHotel` returns a FLAT result (not `{data}`) and
      // accepts only the room-type offer id. The documented response carries
      // `price`/`currency`; anything else is an unusable quote, never a
      // zero-price OK.
      if (dto.providerId === 'nuitee') {
        const prebook = await this.nuiteeService.prebookHotel({
          offerId: dto.offerId,
        });
        if (!prebook.success) {
          return {
            status: 'UNAVAILABLE',
            offerId: dto.offerId,
            reason: prebook.error,
          };
        }
        const newPrice = Number(prebook.newPrice ?? 0);
        const currency = prebook.currency;
        if (!currency || !Number.isFinite(newPrice) || newPrice <= 0) {
          return {
            status: 'UNAVAILABLE',
            offerId: dto.offerId,
            reason: 'Provider returned no usable price',
          };
        }
        const oldPrice =
          dto.knownPrice !== undefined ? Number(dto.knownPrice) : undefined;
        const priceChanged =
          prebook.priceChanged === true ||
          (oldPrice !== undefined && Math.abs(oldPrice - newPrice) > 0.01);
        // Terms the provider reports as changed ride along so the client can
        // re-confirm them instead of silently accepting different conditions.
        const changedTerms = Array.isArray(prebook.changedTerms)
          ? prebook.changedTerms
          : [
              ...(prebook.cancellationChanged
                ? ['cancellationChanged']
                : []),
              ...(prebook.boardChanged ? ['boardChanged'] : []),
            ];
        const termsChanged = changedTerms.length > 0;
        const terms = prebook.terms;
        const termsVersion =
          prebook.termsVersion ??
          (terms ? termsVersionOf(terms) : undefined);
        const checkedAt = new Date().toISOString();
        const difference = priceDifference(oldPrice, newPrice);
        const percent = priceChangePercent(oldPrice, newPrice);
        if (priceChanged || termsChanged) {
          return {
            status: 'PRICE_CHANGED',
            offerId: dto.offerId,
            providerId: dto.providerId,
            offerType: dto.offerType,
            oldPrice,
            previousPrice: oldPrice,
            newPrice,
            currentPrice: newPrice,
            price: newPrice,
            currency,
            priceChanged,
            termsChanged,
            priceDifference: difference,
            priceChangePercent: percent,
            ...(terms ? { terms } : {}),
            ...(termsVersion ? { termsVersion } : {}),
            ...(changedTerms.length > 0 ? { changedTerms } : {}),
            ...(changedTerms.includes('cancellationChanged')
              ? { cancellationChanged: true }
              : {}),
            ...(changedTerms.includes('boardChanged')
              ? { boardChanged: true }
              : {}),
            expiresAt: prebook.expiresAt,
            checkedAt,
          };
        }
        return {
          status: 'OK',
          offerId: dto.offerId,
          providerId: dto.providerId,
          offerType: dto.offerType,
          price: newPrice,
          currentPrice: newPrice,
          newPrice,
          currency,
          priceChanged: false,
          termsChanged: false,
          priceDifference: difference,
          priceChangePercent: percent,
          ...(terms ? { terms } : {}),
          ...(termsVersion ? { termsVersion } : {}),
          expiresAt: prebook.expiresAt,
          checkedAt,
        };
      }

      let result:
        | { success: boolean; data?: any; error?: string }
        | undefined;
      switch (dto.providerId) {
        case 'duffel-flight':
          result = await this.duffelService.revalidateOffer(dto.offerId);
          break;
        default:
          // Unknown/legacy provider ids fall back to a fresh provider-side
          // check when one exists; otherwise the offer cannot be trusted.
          return {
            status: 'UNAVAILABLE',
            offerId: dto.offerId,
            reason: `No revalidation path for provider ${dto.providerId}`,
          };
      }

      if (!result?.success) {
        return {
          status: 'UNAVAILABLE',
          offerId: dto.offerId,
          reason: result?.error,
        };
      }

      const data = result.data ?? {};
      const newPrice = Number(
        data.newPrice ?? data.price ?? data.total ?? data.net ?? 0,
      );
      // Defense in depth: a provider result without a positive price is not a
      // usable revalidation, even if the adapter forgot to fail closed.
      if (!Number.isFinite(newPrice) || newPrice <= 0) {
        return {
          status: 'UNAVAILABLE',
          offerId: dto.offerId,
          reason: 'Provider returned no usable price',
        };
      }
      // A revalidation without a currency cannot be compared to the quote the
      // customer saw; defaulting to USD would relabel provider money.
      if (typeof data.currency !== 'string' || data.currency.trim() === '') {
        return {
          status: 'UNAVAILABLE',
          offerId: dto.offerId,
          reason: 'Provider returned no currency',
        };
      }
      const currency = data.currency;
      const oldPrice = dto.knownPrice !== undefined ? Number(dto.knownPrice) : undefined;

      const priceChanged =
        oldPrice !== undefined &&
        Math.abs(oldPrice - newPrice) > 0.01;
      const terms = data.terms;
      const termsVersion =
        data.termsVersion ?? (terms ? termsVersionOf(terms) : undefined);
      const changedTerms = Array.isArray(data.changedTerms)
        ? data.changedTerms
        : [];
      const termsChanged = changedTerms.length > 0;
      const checkedAt = new Date().toISOString();
      const difference = priceDifference(oldPrice, newPrice);
      const percent = priceChangePercent(oldPrice, newPrice);

      if (priceChanged || termsChanged) {
        return {
          status: 'PRICE_CHANGED',
          offerId: dto.offerId,
          providerId: dto.providerId,
          offerType: dto.offerType,
          oldPrice,
          previousPrice: oldPrice,
          newPrice,
          currentPrice: newPrice,
          price: newPrice,
          currency,
          priceChanged,
          termsChanged,
          priceDifference: difference,
          priceChangePercent: percent,
          ...(terms ? { terms } : {}),
          ...(termsVersion ? { termsVersion } : {}),
          ...(changedTerms.length > 0 ? { changedTerms } : {}),
          expiresAt: data.expiresAt,
          checkedAt,
        };
      }
      return {
        status: 'OK',
        offerId: dto.offerId,
        providerId: dto.providerId,
        offerType: dto.offerType,
        price: newPrice,
        currentPrice: newPrice,
        newPrice,
        currency,
        priceChanged: false,
        termsChanged: false,
        priceDifference: difference,
        priceChangePercent: percent,
        ...(terms ? { terms } : {}),
        ...(termsVersion ? { termsVersion } : {}),
        // Provider expiry only. A fallback window invented here would reach the
        // client as a real booking deadline.
        expiresAt: data.expiresAt,
        checkedAt,
      };
    } catch (error) {
      // Do not leak provider/internal error details to the client.
      // eslint-disable-next-line no-console
      console.error('[offers/revalidate]', error);
      return {
        status: 'ERROR',
        offerId: dto.offerId,
        error: 'Revalidation failed',
      };
    }
  }
}
