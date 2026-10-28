import {
  NuiteeHotelOffer,
  NuiteeRateEntry,
  NuiteeSearchParams,
} from './nuitee.types';

/**
 * Nuitee response → TokiGo offer mapping. Pure functions only: no HTTP, no
 * logging, no clock-dependent branching (except the `retrievedAt` stamp).
 *
 * Two shapes are supported because the vendor and the fixtures differ:
 *   live:    { data: [{ hotelId, roomTypes: [{ rates }] }], hotels: [...] }
 *   fixture: same, with the hotels list floating on the root.
 */

/** First quoted amount of a `retailRate.total` array. */
export function firstAmount(total: any): number | undefined {
  const amount = total?.[0]?.amount;
  return typeof amount === 'number' ? amount : undefined;
}

/** Numeric passthrough that keeps "the provider said nothing" as undefined. */
export function numberOrUndefined(value: any): number | undefined {
  return typeof value === 'number' ? value : undefined;
}

/** `YYYY-MM-DD` as the rates endpoint expects (UTC, like the vendor docs). */
export function dateStr(value: Date | string): string {
  return value instanceof Date
    ? value.toISOString().split('T')[0]
    : String(value).split('T')[0];
}

/**
 * Flat list of `{hotelId, offerId, roomType, rate}` entries.
 * One entry per room type, carrying its CHEAPEST rate.
 */
export function extractRateResults(response: any): NuiteeRateEntry[] {
  // Live shape wraps the array in `data`; fixtures keep the raw array.
  const data = Array.isArray(response?.data)
    ? response.data
    : response?.data?.data;
  if (!Array.isArray(data)) return [];

  const entries: NuiteeRateEntry[] = [];
  for (const hotel of data) {
    for (const room of hotel?.roomTypes ?? []) {
      const rates = room?.rates ?? [];
      // Cheapest rate per room type keeps the offer list scannable.
      const cheapest = rates.reduce(
        (min: any, r: any) =>
          (firstAmount(r?.retailRate?.total) ?? Infinity) <
          (firstAmount(min?.retailRate?.total) ?? Infinity)
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

/** Hotel metadata keyed by id (names/photos/stars/rating). */
export function hotelMetaIndex(response: any): Map<string, any> {
  // Live shape nests hotels under data.hotels; fixtures keep response.hotels.
  const hotels = response?.hotels ?? response?.data?.hotels ?? [];
  const index = new Map<string, any>();
  for (const h of hotels) {
    index.set(String(h?.id ?? h?.hotelId), h);
  }
  return index;
}

/**
 * One entry per hotel — the cheapest available room.
 *
 * BUGFIX (user report 2026-09-08): the adapter used to emit one offer PER ROOM
 * TYPE, so the same hotel surfaced 2–3 times at different prices
 * (Standard/Deluxe/Suite) on the Home rail and search. The original comment
 * said "cheapest rate per hotel" but nothing deduplicated. The cheapest room's
 * rateId is preserved for the prebook path.
 */
export function cheapestPerHotel(
  entries: NuiteeRateEntry[],
): Map<string, { entry: NuiteeRateEntry; price: number }> {
  const cheapest = new Map<string, { entry: NuiteeRateEntry; price: number }>();
  for (const entry of entries) {
    const key = String(
      entry?.hotelId ?? entry?.rate?.rateId ?? entry?.offerId ?? '',
    );
    const price = firstAmount(entry?.rate?.retailRate?.total) ?? Infinity;
    const existing = cheapest.get(key);
    if (!existing || price < existing.price) {
      cheapest.set(key, { entry, price });
    }
  }
  return cheapest;
}

export interface NuiteeIdentity {
  providerId: string;
  providerName: string;
}

/**
 * Maps one `{hotelId, roomType, rate}` entry to the shared offer shape.
 *
 * Returns null when the rate has no id or no quoted amount: without a price we
 * cannot state one, and a placeholder 0 would be invented money.
 */
export function mapRateToOffer(
  entry: NuiteeRateEntry,
  hotelMeta: Map<string, any>,
  params: NuiteeSearchParams,
  checkInStr: string,
  checkOutStr: string,
  identity: NuiteeIdentity,
): NuiteeHotelOffer | null {
  const rate = entry?.rate;
  const rateId = rate?.rateId;
  if (!rateId) return null;

  // Live metadata shape (snake_case): main_photo / city_name / review_count.
  const meta = hotelMeta.get(String(entry?.hotelId)) ?? {};
  const total = firstAmount(rate?.retailRate?.total);
  // No quoted amount means we cannot state a price at all — dropping the
  // rate is the only honest option.
  if (total === undefined) return null;

  const currency = rate?.retailRate?.total?.[0]?.currency ?? 'USD';
  const refundable = rate?.cancellationPolicies?.refundableTag === 'RFN';
  const rating = typeof meta?.rating === 'number' ? meta.rating : undefined;
  // Nuitee rates hotels on a 10 scale — halve for the 5-star display scale.
  const displayRating =
    rating !== undefined ? Math.min(5, rating / 2) : undefined;
  // Verbatim room naming only: an unnamed room stays unnamed (the UI hides an
  // empty room type) rather than being called "Standard Room".
  const roomName = entry?.roomType ?? rate?.name ?? rate?.boardName ?? '';

  // 3D — provider-verbatim detail fields (never invented):
  // taxesAndFees: the first total entry Nuitee quotes.
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
    providerId: identity.providerId,
    providerName: identity.providerName,
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
    imageUrl:
      meta?.main_photo ?? meta?.images?.[0]?.url ?? meta?.thumbnail,
    price: total,
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
      refundable,
      boardType: rate?.boardType,
      // 3D — verbatim detail fields for the details page.
      stars: typeof meta?.stars === 'number' ? meta.stars : undefined,
      boardName: rate?.boardName,
      taxesAndFees,
      cancellationPolicy,
    },
  };
}
