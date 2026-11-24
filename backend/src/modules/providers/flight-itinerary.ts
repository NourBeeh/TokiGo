/**
 * Phase 2D — flight itinerary grouping.
 *
 * A search row is ONE physical itinerary (the same ordered flights), carrying
 * EVERY valid fare offer the providers returned for it. The row's own fields
 * are the cheapest valid offer (the summary), and `offers` keeps each fare's
 * exact provider identity and original offer id.
 *
 * The grouping key is derived from the itinerary itself — never from a
 * provider-specific hash alone and never from origin/destination alone:
 *
 *   ordered segments, each identified by
 *     origin, destination,
 *     departure instant, arrival instant,
 *     marketing carrier + marketing flight number,
 *     operating carrier + operating flight number,
 *     technical stop count
 *
 * Cabin class and fare brand are deliberately NOT part of the key: they are
 * fare variants of the same itinerary, not a different itinerary.
 *
 * Normalisation is conservative. A date-time keeps its offset when one is
 * present and stays distinct from the same local clock time without one; a
 * missing field is never guessed. Offers whose itinerary identity cannot be
 * proven get their own row (keyed by provider + offer id) instead of being
 * merged into a group they may not belong to.
 */

/** A normalized segment identity, used only inside this module. */
interface SegmentIdentity {
  origin: string;
  destination: string;
  departure: string;
  arrival: string;
  marketingCarrier: string;
  marketingFlightNumber: string;
  operatingCarrier: string;
  operatingFlightNumber: string;
  stopCount: number | null;
}

export interface FlightItineraryGroupResult {
  results: any[];
  duplicatesDropped: number;
  invalidOffersDropped: number;
}

/** Uppercase IATA-style code, whitespace removed. Missing stays ''. */
export function normalizeCarrierCode(value: any): string {
  return String(value ?? '')
    .trim()
    .toUpperCase()
    .replace(/\s+/g, '');
}

/** Uppercase flight number without spaces. Missing stays ''. */
export function normalizeFlightNumber(value: any): string {
  return String(value ?? '')
    .trim()
    .toUpperCase()
    .replace(/\s+/g, '');
}

/**
 * Marketing/operating designator ("DE" + "2017" → "DE2017").
 *
 * Some providers already send the carrier prefix inside the flight number;
 * prefixing again would fabricate a different flight ("DEDE2017").
 */
export function flightDesignator(
  carrierCode: any,
  flightNumber: any,
): string {
  const code = normalizeCarrierCode(carrierCode);
  const number = normalizeFlightNumber(flightNumber);
  if (!number) return '';
  if (!code) return number;
  return number.startsWith(code) ? number : `${code}${number}`;
}

/**
 * Normalizes an ISO-8601-ish instant for comparison without converting it.
 *
 * - `2026-07-01T16:10` and `2026-07-01T16:10:00.123` become
 *   `2026-07-01T16:10:00`.
 * - An offset (`Z`, `+02:00`, `+0200`) is preserved. An offset-bearing
 *   instant and the same local clock text without one remain DIFFERENT: they
 *   are not provably the same moment.
 * - Text that does not look like a date-time is lowercased/trimmed verbatim.
 */
export function normalizeInstant(value: any): string | null {
  if (value === null || value === undefined) return null;
  const text = String(value).trim();
  if (!text) return null;
  const match =
    /^(\d{4}-\d{2}-\d{2})[T ](\d{2}:\d{2})(?::(\d{2}))?(?:\.\d+)?(Z|[+-]\d{2}:?\d{2})?$/.exec(
      text,
    );
  if (!match) return text.toLowerCase();
  const [, date, hoursMinutes, seconds, offset] = match;
  const zone = offset ? normalizeOffset(offset) : '';
  return `${date}T${hoursMinutes}:${seconds ?? '00'}${zone}`;
}

function normalizeOffset(offset: string): string {
  if (offset === 'Z' || offset === 'z') return 'Z';
  if (/^[+-]\d{2}:\d{2}$/.test(offset)) return offset;
  const match = /^([+-])(\d{2})(\d{2})$/.exec(offset);
  return match ? `${match[1]}${match[2]}:${match[3]}` : offset;
}

function nonEmptyString(value: any): string | null {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  return trimmed ? trimmed : null;
}

function finiteNumber(value: any): number | null {
  const number = typeof value === 'number' ? value : Number(value);
  return Number.isFinite(number) ? number : null;
}

function stopCountOf(segment: any): number | null {
  const raw =
    segment?.stopCount ??
    (Array.isArray(segment?.stops) ? segment.stops.length : undefined);
  const number = finiteNumber(raw);
  if (number === null || number < 0) return null;
  return Math.trunc(number);
}

/**
 * The ordered segments of a normalized offer.
 *
 * New provider mappers attach a normalized `segments` array. Older/other
 * payloads fall back to the top-level route/time/carrier fields, which is
 * enough for a conservative single-segment identity — never enough to invent
 * a connection.
 */
export function flightSegmentsOf(offer: any): any[] {
  if (Array.isArray(offer?.segments) && offer.segments.length > 0) {
    return offer.segments;
  }
  const origin = nonEmptyString(offer?.origin);
  const destination = nonEmptyString(offer?.destination);
  const departure = offer?.departureTime ?? offer?.departure;
  const arrival = offer?.arrivalTime ?? offer?.arrival;
  if (!origin || !destination || departure == null || arrival == null) {
    return [];
  }
  const airline = nonEmptyString(offer?.airline) ?? '';
  return [
    {
      origin,
      destination,
      departureAt: departure,
      arrivalAt: arrival,
      marketingCarrier: { code: airline, name: airline },
      operatingCarrier: { code: airline, name: airline },
      marketingFlightNumber: offer?.flightNumber ?? '',
      operatingFlightNumber: offer?.flightNumber ?? '',
      // The row-level `stops` count is connections, not technical stops; it
      // cannot prove a segment's en-route stop count.
      stopCount: null,
    },
  ];
}

function segmentIdentity(segment: any): SegmentIdentity | null {
  const origin = normalizeCarrierCode(
    segment?.origin ?? segment?.originCode,
  );
  const destination = normalizeCarrierCode(
    segment?.destination ?? segment?.destinationCode,
  );
  const departure = normalizeInstant(
    segment?.departureAt ?? segment?.departing_at ?? segment?.departureTime,
  );
  const arrival = normalizeInstant(
    segment?.arrivalAt ?? segment?.arriving_at ?? segment?.arrivalTime,
  );
  if (!origin || !destination || !departure || !arrival) return null;

  const marketingCarrier = normalizeCarrierCode(
    segment?.marketingCarrier?.code ??
      segment?.marketing_carrier?.iata_code ??
      segment?.carrier?.marketingCode,
  );
  const operatingCarrier = normalizeCarrierCode(
    segment?.operatingCarrier?.code ??
      segment?.operating_carrier?.iata_code ??
      segment?.carrier?.operatingCode,
  );
  const marketingFlightNumber = normalizeFlightNumber(
    segment?.marketingFlightNumber ??
      segment?.marketing_carrier_flight_number ??
      segment?.flight?.marketingNumber,
  );
  const operatingFlightNumber = normalizeFlightNumber(
    segment?.operatingFlightNumber ??
      segment?.operating_carrier_flight_number ??
      segment?.flight?.operatingNumber,
  );

  // A segment with no flight designator at all cannot be proven identical to
  // anything; its offer becomes a singleton row.
  if (!marketingFlightNumber && !operatingFlightNumber) return null;

  return {
    origin,
    destination,
    departure,
    arrival,
    marketingCarrier,
    marketingFlightNumber,
    operatingCarrier,
    operatingFlightNumber,
    stopCount: stopCountOf(segment),
  };
}

function segmentIdentityKey(segment: any): string | null {
  const identity = segmentIdentity(segment);
  if (!identity) return null;
  return [
    identity.origin,
    identity.destination,
    identity.departure,
    identity.arrival,
    identity.marketingCarrier,
    identity.marketingFlightNumber,
    identity.operatingCarrier,
    identity.operatingFlightNumber,
    identity.stopCount === null ? '?' : String(identity.stopCount),
  ].join('~');
}

/**
 * The canonical itinerary key: every ordered segment must have a proven
 * identity. Returns null when any segment is unprovable.
 */
export function flightItineraryKey(offer: any): string | null {
  const segments = flightSegmentsOf(offer);
  if (segments.length === 0) return null;
  const identities: string[] = [];
  for (const segment of segments) {
    const identity = segmentIdentityKey(segment);
    if (!identity) return null;
    identities.push(identity);
  }
  return `flight-itinerary:v1|${identities.join('||')}`;
}

/** A valid offer is one the customer can actually see and eventually book. */
export function isValidFlightOffer(offer: any): boolean {
  if (!offer || typeof offer !== 'object') return false;
  if (offer.type !== 'flight') return false;
  if (!nonEmptyString(offer.id)) return false;
  if (!nonEmptyString(offer.providerId)) return false;
  const price = finiteNumber(offer.price);
  if (price === null || price <= 0) return false;
  if (!nonEmptyString(offer.currency)) return false;

  const segments = flightSegmentsOf(offer);
  if (segments.length === 0) return false;
  return segments.every((segment) => {
    const origin = nonEmptyString(segment?.origin ?? segment?.originCode);
    const destination = nonEmptyString(
      segment?.destination ?? segment?.destinationCode,
    );
    const departure = normalizeInstant(
      segment?.departureAt ?? segment?.departing_at ?? segment?.departureTime,
    );
    const arrival = normalizeInstant(
      segment?.arrivalAt ?? segment?.arriving_at ?? segment?.arrivalTime,
    );
    return Boolean(origin && destination && departure && arrival);
  });
}

/**
 * The amount used to rank offers inside one row: the customer total when the
 * pricing engine attached one, otherwise the provider amount.
 */
function effectiveAmount(offer: any): number {
  const quote = offer?.customerPrice;
  if (
    quote &&
    typeof quote.customerAmount === 'number' &&
    Number.isFinite(quote.customerAmount) &&
    quote.customerAmount > 0
  ) {
    return quote.customerAmount;
  }
  return finiteNumber(offer?.price) ?? Number.POSITIVE_INFINITY;
}

function effectiveCurrency(offer: any): string {
  const quote = offer?.customerPrice;
  if (
    quote &&
    typeof quote.customerAmount === 'number' &&
    quote.customerAmount > 0 &&
    nonEmptyString(quote.customerCurrency)
  ) {
    return normalizeCarrierCode(quote.customerCurrency);
  }
  return normalizeCarrierCode(offer?.currency);
}

/**
 * Cheapest-first within a row. Currencies sort first so amounts in different
 * currencies are never falsely ranked against each other; the tie-breakers
 * make the order deterministic across identical searches.
 */
export function compareFlightOffers(a: any, b: any): number {
  const currencyA = effectiveCurrency(a);
  const currencyB = effectiveCurrency(b);
  if (currencyA !== currencyB) return currencyA < currencyB ? -1 : 1;

  const amountA = effectiveAmount(a);
  const amountB = effectiveAmount(b);
  if (amountA !== amountB) return amountA < amountB ? -1 : 1;

  const providerA = String(a?.providerId ?? '');
  const providerB = String(b?.providerId ?? '');
  if (providerA !== providerB) return providerA < providerB ? -1 : 1;

  return String(a?.id ?? '').localeCompare(String(b?.id ?? ''));
}

/**
 * Groups every valid offer into one row per identical itinerary.
 *
 * - Invalid offers are excluded from `results` (they stay untouched in the
 *   caller's raw provider buckets) and counted.
 * - Duplicate `(providerId, id)` inside one row is deduped, first one wins.
 * - Rows keep first-appearance order (deterministic provider/registry order);
 *   offers inside a row are cheapest-first.
 */
export function buildFlightItineraryGroups(
  successes: any[],
): FlightItineraryGroupResult {
  const groups = new Map<string, { key: string; offers: any[] }>();
  const seenByGroup = new Map<string, Set<string>>();
  let duplicatesDropped = 0;
  let invalidOffersDropped = 0;

  for (const success of successes ?? []) {
    const offers = Array.isArray(success?.data) ? success.data : [];
    for (const offer of offers) {
      if (!isValidFlightOffer(offer)) {
        invalidOffersDropped++;
        continue;
      }
      const itineraryKey =
        flightItineraryKey(offer) ??
        `flight-offer:${offer.providerId}:${offer.id}`;

      let group = groups.get(itineraryKey);
      if (!group) {
        group = { key: itineraryKey, offers: [] };
        groups.set(itineraryKey, group);
      }
      let seen = seenByGroup.get(itineraryKey);
      if (!seen) {
        seen = new Set<string>();
        seenByGroup.set(itineraryKey, seen);
      }
      const offerIdentity = `${offer.providerId}|${offer.id}`;
      if (seen.has(offerIdentity)) {
        duplicatesDropped++;
        continue;
      }
      seen.add(offerIdentity);
      group.offers.push(offer);
    }
  }

  const results: any[] = [];
  for (const group of groups.values()) {
    const offers = [...group.offers].sort(compareFlightOffers);
    const summary = offers[0];
    if (!summary) continue;

    const providerIds: string[] = [];
    for (const offer of offers) {
      const providerId = String(offer.providerId ?? '');
      if (providerId && !providerIds.includes(providerId)) {
        providerIds.push(providerId);
      }
    }

    const row: any = {
      ...summary,
      type: 'flight',
      // The row's own fields are the cheapest valid offer; the exact offer id
      // and provider identity stay on that summary AND on every nested offer.
      id: summary.id,
      providerId: summary.providerId,
      providerName: summary.providerName,
      offers,
      offerCount: offers.length,
      providerIds,
      providerOfferIds: offers.map((offer) => offer.id),
      itineraryKey: group.key,
      segments: Array.isArray(summary.segments) ? summary.segments : [],
      metadata: {
        ...(summary.metadata ?? {}),
        itineraryKey: group.key,
        groupedOfferCount: offers.length,
        providerIds,
        providerOfferIds: offers.map((offer) => offer.id),
      },
    };

    results.push(row);
  }

  return { results, duplicatesDropped, invalidOffersDropped };
}
