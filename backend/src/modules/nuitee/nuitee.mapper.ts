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
 *   live:    { data: [{ hotelId, roomTypes: [{ offerId, rates }] }], hotels: [...] }
 *   fixture: same, with the hotels list floating on the root.
 */

/** First quoted amount of a `retailRate.total` / `offerRetailRate` array. */
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

function nonEmptyString(value: any): string | undefined {
  return typeof value === 'string' && value.trim().length > 0
    ? value.trim()
    : undefined;
}

/**
 * Flat list of bookable room-type offers.
 *
 * `roomTypes[].offerId` is the identity prebook/book accept; `rates[]` are the
 * per-room components of that ONE offer (one rate per requested occupancy).
 * Every room type is kept — nothing is collapsed to the cheapest rate.
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
      const rates = Array.isArray(room?.rates) ? room.rates : [];
      // A room type with no quoted rate cannot be offered at all. It is
      // dropped here; the mapper also refuses it (defence in depth).
      if (rates.length === 0) continue;
      entries.push({
        hotelId: hotel?.hotelId,
        offerId: room?.offerId,
        roomTypeId: room?.roomTypeId,
        roomType:
          nonEmptyString(room?.roomTypeName) ??
          nonEmptyString(room?.name) ??
          nonEmptyString(room?.roomType?.name),
        rates,
        offerRetailRate: Array.isArray(room?.offerRetailRate)
          ? room.offerRetailRate
          : undefined,
        room,
      });
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
    const id = nonEmptyString(h?.id) ?? nonEmptyString(h?.hotelId);
    if (id) index.set(id, h);
  }
  return index;
}

export interface NuiteeIdentity {
  providerId: string;
  providerName: string;
}

/**
 * The provider's own address can be a string (rates `hotels[]`) or an object
 * (content API). Read both shapes; never synthesize one.
 */
function hotelLocation(meta: any): {
  city?: string;
  country?: string;
  address?: string;
  latitude?: number;
  longitude?: number;
} {
  const rawAddress = meta?.address;
  const addressObject =
    rawAddress && typeof rawAddress === 'object' ? rawAddress : undefined;
  return {
    city:
      nonEmptyString(meta?.city_name) ??
      nonEmptyString(meta?.city) ??
      nonEmptyString(addressObject?.cityName) ??
      nonEmptyString(addressObject?.city),
    country:
      nonEmptyString(meta?.country_code) ??
      nonEmptyString(meta?.country) ??
      nonEmptyString(addressObject?.countryName) ??
      nonEmptyString(addressObject?.country),
    address:
      nonEmptyString(rawAddress) ??
      nonEmptyString(addressObject?.addressLine1) ??
      nonEmptyString(addressObject?.address) ??
      nonEmptyString(meta?.address_line_1),
    latitude: numberOrUndefined(
      meta?.latitude ??
        meta?.location?.latitude ??
        meta?.location?.lat ??
        addressObject?.latitude ??
        addressObject?.lat,
    ),
    longitude: numberOrUndefined(
      meta?.longitude ??
        meta?.location?.longitude ??
        meta?.location?.lng ??
        addressObject?.longitude ??
        addressObject?.lng,
    ),
  };
}

/**
 * Refundability is tri-state: true only when every room rate is tagged `RFN`,
 * false when any is `NRFN`, and `null` when the provider sent no tag. A
 * missing tag is "unknown", never "non-refundable".
 */
function refundability(rates: any[]): boolean | null {
  const tags = rates
    .map((rate) => nonEmptyString(rate?.cancellationPolicies?.refundableTag))
    .filter((tag): tag is string => tag !== undefined);
  if (tags.length === 0) return null;
  if (tags.some((tag) => tag.toUpperCase() === 'NRFN')) return false;
  if (tags.every((tag) => tag.toUpperCase() === 'RFN')) return true;
  return null;
}

function sameCurrency(values: Array<string | undefined>): string | undefined {
  const present = values.filter((v): v is string => v !== undefined);
  if (present.length === 0) return undefined;
  const first = present[0];
  return present.every((v) => v === first) ? first : undefined;
}

function sumDefined(values: Array<number | undefined>): number | undefined {
  if (values.length === 0 || values.some((v) => v === undefined)) {
    return undefined;
  }
  return (values as number[]).reduce((sum, value) => sum + value, 0);
}

function uniqueStrings(values: any[]): string[] {
  return [...new Set(values.filter((v): v is string => typeof v === 'string'))];
}

/**
 * Maps one bookable room-type offer (one `offerId`, all its per-room rates).
 *
 * Returns null when the provider gave no `offerId` (the booking identity), no
 * quoted total, or no currency. A placeholder id, 0 price or `USD` would be
 * invented provider truth.
 */
export function mapRateToOffer(
  entry: NuiteeRateEntry,
  hotelMeta: Map<string, any>,
  params: NuiteeSearchParams,
  checkInStr: string,
  checkOutStr: string,
  identity: NuiteeIdentity,
): NuiteeHotelOffer | null {
  const offerId = nonEmptyString(entry?.offerId);
  if (!offerId) return null;

  const rates = Array.isArray(entry?.rates) ? entry.rates : [];
  if (rates.length === 0) return null;

  const rateTotals = rates.map((rate) =>
    firstAmount(rate?.retailRate?.total),
  );
  const rateCurrencies = rates.map((rate) =>
    nonEmptyString(rate?.retailRate?.total?.[0]?.currency),
  );
  const offerCurrency = nonEmptyString(entry?.offerRetailRate?.[0]?.currency);
  const currency = offerCurrency ?? sameCurrency(rateCurrencies);
  const total =
    firstAmount(entry?.offerRetailRate) ?? sumDefined(rateTotals);
  // No quoted total or no single currency means we cannot state a price.
  if (total === undefined || currency === undefined) return null;

  const meta = hotelMeta.get(String(entry?.hotelId)) ?? {};
  const location = hotelLocation(meta);
  const refundable = refundability(rates);

  const rating = typeof meta?.rating === 'number' ? meta.rating : undefined;
  // Nuitee rates hotels on a 10 scale — halve for the 5-star display scale.
  const displayRating =
    rating !== undefined ? Math.min(5, rating / 2) : undefined;

  const firstRate = rates[0];
  const roomName =
    entry?.roomType ??
    nonEmptyString(firstRate?.name) ??
    nonEmptyString(firstRate?.boardName) ??
    '';

  const taxes = firstRate?.retailRate?.taxesAndFees?.[0];
  const taxesAndFees =
    typeof taxes?.amount === 'number'
      ? {
          amount: taxes.amount,
          currency: taxes.currency ?? currency,
          included: taxes.included === true,
          description: taxes.description,
        }
      : undefined;

  // Cancellation: the LAST policy window (closest to check-in) of the first
  // room rate, verbatim. Every rate's own policy is preserved below.
  const policyInfos = firstRate?.cancellationPolicies?.cancelPolicyInfos ?? [];
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

  const occupancyAdults = rates.reduce(
    (sum, rate) =>
      sum + (typeof rate?.adultCount === 'number' ? rate.adultCount : 0),
    0,
  );
  const occupancyChildren = rates.reduce(
    (sum, rate) =>
      sum + (typeof rate?.childCount === 'number' ? rate.childCount : 0),
    0,
  );
  const childrenAges = rates.flatMap((rate) =>
    Array.isArray(rate?.childrenAges) ? rate.childrenAges : [],
  );

  return {
    id: offerId,
    type: 'hotel',
    providerId: identity.providerId,
    providerName: identity.providerName,
    // The provider's own name, or nothing. Never a synthesized "Hotel <id>".
    title: nonEmptyString(meta?.name) ?? nonEmptyString(meta?.hotelName) ?? '',
    subtitle: [
      location.city ?? params.city,
      displayRating !== undefined ? `${displayRating.toFixed(1)}★` : null,
      meta?.stars ? `${meta.stars}★ hotel` : null,
      refundable === true ? 'Free cancellation' : null,
    ]
      .filter(Boolean)
      .join(' · '),
    description: meta?.description ?? '',
    imageUrl:
      nonEmptyString(meta?.main_photo) ??
      nonEmptyString(meta?.images?.[0]?.url) ??
      nonEmptyString(meta?.thumbnail),
    price: total,
    currency,
    rating: displayRating,
    reviewCount: meta?.review_count ?? meta?.reviewCount,
    city: location.city ?? params.city,
    country: location.country,
    checkIn: checkInStr,
    checkOut: checkOutStr,
    roomType: roomName,
    amenities: (meta?.facilities ?? meta?.amenities ?? []).slice(0, 6),
    // Provider provenance (spec point 7): raw ids survive as metadata.
    metadata: {
      providerOfferId: offerId,
      providerRateId: nonEmptyString(firstRate?.rateId),
      providerRateIds: uniqueStrings(rates.map((rate) => rate?.rateId)),
      providerHotelId: entry?.hotelId,
      roomTypeId: nonEmptyString(entry?.roomTypeId),
      hotelNameEn: meta?.nameEn ?? meta?.name,
      hotelNameAr: meta?.nameAr,
      retrievedAt: new Date().toISOString(),
      refundable,
      refundableTag: nonEmptyString(
        firstRate?.cancellationPolicies?.refundableTag,
      ),
      boardType: nonEmptyString(firstRate?.boardType),
      boardName: nonEmptyString(firstRate?.boardName),
      // Occupancy of the whole offer (all rooms), verbatim where supplied.
      occupancy: {
        rooms: rates.length,
        adults: occupancyAdults,
        children: occupancyChildren,
        childrenAges,
        occupancyNumbers: rates
          .map((rate) => rate?.occupancyNumber)
          .filter((n): n is number => typeof n === 'number'),
        maxOccupancy: rates
          .map((rate) => rate?.maxOccupancy)
          .filter((n): n is number => typeof n === 'number'),
      },
      paymentTypes: uniqueStrings(
        rates.flatMap((rate) =>
          Array.isArray(rate?.paymentTypes) ? rate.paymentTypes : [],
        ),
      ),
      remarks: uniqueStrings(rates.map((rate) => rate?.remarks)),
      priceType: nonEmptyString(firstRate?.priceType),
      // Every per-room rate and its own conditions, verbatim.
      rates: rates.map((rate) => ({
        rateId: nonEmptyString(rate?.rateId),
        occupancyNumber: numberOrUndefined(rate?.occupancyNumber),
        maxOccupancy: numberOrUndefined(rate?.maxOccupancy),
        adultCount: numberOrUndefined(rate?.adultCount),
        childCount: numberOrUndefined(rate?.childCount),
        childrenAges: Array.isArray(rate?.childrenAges)
          ? rate.childrenAges
          : undefined,
        boardType: nonEmptyString(rate?.boardType),
        boardName: nonEmptyString(rate?.boardName),
        refundableTag: nonEmptyString(
          rate?.cancellationPolicies?.refundableTag,
        ),
        cancellationPolicies: rate?.cancellationPolicies,
        taxesAndFees: rate?.retailRate?.taxesAndFees,
        paymentTypes: Array.isArray(rate?.paymentTypes)
          ? rate.paymentTypes
          : undefined,
        perks: Array.isArray(rate?.perks) ? rate.perks : undefined,
        promotions: Array.isArray(rate?.promotions)
          ? rate.promotions
          : undefined,
        remarks: nonEmptyString(rate?.remarks),
      })),
      // 3D — verbatim detail fields for the details page.
      stars: typeof meta?.stars === 'number' ? meta.stars : undefined,
      taxesAndFees,
      cancellationPolicy,
      // Where the hotel is (verbatim): the Home card offers "open in maps"
      // and measures the distance to the centre. Coordinates/address the
      // provider omitted stay absent — the client must never invent them.
      latitude: location.latitude,
      longitude: location.longitude,
      address: location.address,
      distanceToCenter: numberOrUndefined(
        meta?.distance_to_center ?? meta?.distanceFromCenter,
      ),
    },
  };
}

/**
 * Groups mapped room-type offers by hotel. The cheapest offer is the hotel
 * row's own identity; ALL valid offers ride along in `offers` so the details
 * page can compare room, board, price and cancellation terms. Nothing is
 * discarded to enforce one row per hotel.
 */
export function mapHotelOffers(
  entries: NuiteeRateEntry[],
  hotelMeta: Map<string, any>,
  params: NuiteeSearchParams,
  checkInStr: string,
  checkOutStr: string,
  identity: NuiteeIdentity,
): NuiteeHotelOffer[] {
  const groups = new Map<string, NuiteeHotelOffer[]>();
  for (const entry of entries) {
    const offer = mapRateToOffer(
      entry,
      hotelMeta,
      params,
      checkInStr,
      checkOutStr,
      identity,
    );
    if (!offer) continue;
    const hotelKey = String(entry?.hotelId ?? offer.id);
    const group = groups.get(hotelKey) ?? [];
    // The same offerId is one bookable offer; a duplicate page entry must not
    // multiply it.
    if (!group.some((existing) => existing.id === offer.id)) {
      group.push(offer);
    }
    groups.set(hotelKey, group);
  }

  const hotels: NuiteeHotelOffer[] = [];
  for (const group of groups.values()) {
    group.sort(
      (a, b) => a.price - b.price || a.id.localeCompare(b.id),
    );
    const best = group[0];
    hotels.push({ ...best, offers: group });
  }
  return hotels;
}
