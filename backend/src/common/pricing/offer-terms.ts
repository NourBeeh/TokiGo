import { createHash } from 'crypto';

/**
 * Provider-agnostic offer-terms snapshot used by the price-change confirmation
 * flow.
 *
 * The snapshot only contains fields a provider actually returned. A missing
 * field stays missing — it is never replaced with a guessed default. This is
 * what makes `termsVersion` safe to bind a customer acceptance to: the same
 * normalized facts always produce the same version, and any documented change
 * (fare brand, cabin, baggage, cancellation/change conditions, itinerary)
 * produces a different one.
 */
export type OfferTermsSnapshot = Record<string, any>;

/** Deterministic JSON: object keys are sorted recursively. */
export function canonicalJson(value: any): string {
  if (value === null || value === undefined) return 'null';
  if (Array.isArray(value)) {
    return `[${value.map((entry) => canonicalJson(entry)).join(',')}]`;
  }
  if (typeof value === 'object') {
    const keys = Object.keys(value).sort();
    return `{${keys
      .map((key) => `${JSON.stringify(key)}:${canonicalJson(value[key])}`)
      .join(',')}}`;
  }
  return JSON.stringify(value);
}

/**
 * Stable version of a terms snapshot. The prefix makes the version
 * self-describing and keeps it usable as an opaque client token.
 */
export function termsVersionOf(terms: any): string {
  const hash = createHash('sha256')
    .update(canonicalJson(terms ?? {}))
    .digest('hex');
  return `terms-v1-${hash}`;
}

/**
 * Lists the top-level terms fields that differ. Unknown/missing snapshots
 * return an empty list: "we have no previous facts" is not evidence of a
 * change, and inventing one would force a needless customer confirmation.
 */
export function diffOfferTerms(
  previous: OfferTermsSnapshot | null | undefined,
  current: OfferTermsSnapshot | null | undefined,
): string[] {
  if (!previous || !current) return [];
  const keys = new Set([...Object.keys(previous), ...Object.keys(current)]);
  const changed: string[] = [];
  for (const key of keys) {
    if (canonicalJson(previous[key]) !== canonicalJson(current[key])) {
      changed.push(key);
    }
  }
  return changed.sort();
}

/**
 * The itinerary/fare facts shared by both flight mappers
 * (`mapDuffelOffer` and Nuitee `mapOffer`). Only fields present on the
 * normalized offer are copied, so unknown provider facts stay unknown.
 */
export function termsFromNormalizedFlightOffer(
  offer: any,
): OfferTermsSnapshot | null {
  if (!offer || typeof offer !== 'object') return null;
  const terms: OfferTermsSnapshot = {};
  if (offer.fareBrand) terms.fareBrand = offer.fareBrand;
  if (offer.cabinClass) terms.cabinClass = offer.cabinClass;
  if (offer.conditions) terms.conditions = offer.conditions;
  if (Array.isArray(offer.baggageAllowances)) {
    terms.baggageAllowances = offer.baggageAllowances;
  }
  if (Array.isArray(offer.segments)) {
    terms.segments = offer.segments.map((segment: any) => ({
      sliceIndex: segment?.sliceIndex ?? null,
      segmentIndex: segment?.segmentIndex ?? null,
      origin: segment?.origin ?? null,
      destination: segment?.destination ?? null,
      departureAt: segment?.departureAt ?? null,
      arrivalAt: segment?.arrivalAt ?? null,
      marketingCarrier: segment?.marketingCarrier ?? null,
      operatingCarrier: segment?.operatingCarrier ?? null,
      marketingFlightNumber: segment?.marketingFlightNumber ?? null,
      operatingFlightNumber: segment?.operatingFlightNumber ?? null,
      stopCount: segment?.stopCount ?? null,
      cabinClass: segment?.cabinClass ?? null,
      fareBasisCode: segment?.fareBasisCode ?? null,
      baggage: segment?.baggage ?? null,
    }));
  }
  return Object.keys(terms).length > 0 ? terms : null;
}

/**
 * Provider-reported change flags (Nuitee hotel prebook / flight verify). Only
 * booleans the provider actually set to `true` are included — a false/absent
 * flag is not a condition value and must not enter the version.
 */
export function termsFromChangedFlags(
  source: Record<string, any> | null | undefined,
): OfferTermsSnapshot {
  const terms: OfferTermsSnapshot = {};
  if (!source) return terms;
  for (const [key, value] of Object.entries(source)) {
    if (value === true && /changed$/i.test(key)) {
      terms[key] = true;
    }
  }
  return terms;
}

/** Price difference rounded to cents; never `-0`. */
export function priceDifference(
  previous: number | null | undefined,
  current: number,
): number {
  if (typeof previous !== 'number' || !Number.isFinite(previous)) return 0;
  const difference = Math.round((current - previous) * 100) / 100;
  return Object.is(difference, -0) ? 0 : difference;
}

/** Percentage change, or null when there is no usable previous amount. */
export function priceChangePercent(
  previous: number | null | undefined,
  current: number,
): number | null {
  if (
    typeof previous !== 'number' ||
    !Number.isFinite(previous) ||
    previous <= 0
  ) {
    return null;
  }
  const percent = ((current - previous) / previous) * 100;
  if (!Number.isFinite(percent)) return null;
  return Math.round(percent * 100) / 100;
}
