import { Controller, Post, Body } from '@nestjs/common';
import { RevalidateOfferDto } from '../../common/dto/revalidate-offer.dto';
import { DuffelService } from '../duffel/duffel.service';
import { NuiteeService } from '../nuitee/nuitee.service';

/**
 * Offer revalidation endpoint (spec points 7-8): refreshes the authoritative
 * price/availability of a selected offer right before checkout.
 *
 * Flow: SELECTED -> PRICE_REVALIDATED. When the price moved, the response is
 * a structured PRICE_CHANGED outcome — payment must never proceed silently
 * on a changed amount.
 */
@Controller('offers')
export class OffersController {
  constructor(
    private readonly duffelService: DuffelService,
    private readonly nuiteeService: NuiteeService,
  ) {}

  @Post('revalidate')
  async revalidate(@Body() dto: RevalidateOfferDto): Promise<
    | {
        status: 'OK';
        offerId: string;
        price: number;
        currency: string;
        /** Provider expiry when one was sent; absent otherwise. */
        expiresAt?: string;
      }
    | {
        status: 'PRICE_CHANGED';
        offerId: string;
        oldPrice?: number;
        newPrice: number;
        currency: string;
        expiresAt?: string;
      }
    | {
        status: 'UNAVAILABLE';
        offerId: string;
        reason?: string;
      }
    | { status: 'ERROR'; error: string }
  > {
    try {
      let result:
        | { success: boolean; data?: any; error?: string }
        | undefined;
      switch (dto.providerId) {
        case 'duffel-flight':
          result = await this.duffelService.revalidateOffer(dto.offerId);
          break;
        case 'nuitee':
          result = await this.nuiteeService.prebookHotel({
            rateId: dto.offerId,
            guests: dto.guests,
          });
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
      const currency = String(data.currency ?? 'USD');
      const oldPrice = dto.knownPrice !== undefined ? Number(dto.knownPrice) : undefined;

      const priceChanged =
        oldPrice !== undefined &&
        Math.abs(oldPrice - newPrice) > 0.01;

      if (priceChanged) {
        return {
          status: 'PRICE_CHANGED',
          offerId: dto.offerId,
          oldPrice,
          newPrice,
          currency,
          expiresAt: data.expiresAt,
        };
      }
      return {
        status: 'OK',
        offerId: dto.offerId,
        price: newPrice,
        currency,
        // Provider expiry only. A fallback window invented here would reach the
        // client as a real booking deadline.
        expiresAt: data.expiresAt,
      };
    } catch (error) {
      // Do not leak provider/internal error details to the client.
      // eslint-disable-next-line no-console
      console.error('[offers/revalidate]', error);
      return { status: 'ERROR', error: 'Revalidation failed' };
    }
  }
}
