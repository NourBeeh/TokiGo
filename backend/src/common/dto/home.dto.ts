import { TravelMood } from '../travel_mood';
import policy from './card_price_policy.json';

export interface HomeCardMetadataDto extends Record<string, any> {
  moods?: TravelMood[];
}

/**
 * Home card wire contract — METADATA AND PRESENTATION ONLY.
 *
 * `price` and `rawPrice` were removed (P0-S4 / L2): a Home card is authored
 * content, and a price persisted in `home_cards.content` is served
 * indefinitely with no TTL and no provider revalidation. Live prices belong to
 * the search/revalidation path, never to a durable content row.
 */
export interface HomeCardDto {
  id: string;
  type: string;
  title?: string;
  subtitle?: string;
  description?: string;
  imageUrl?: string;
  currency?: string;
  rating?: number;
  reviewCount?: number;
  badge?: string;
  highlights?: string[];
  tags?: string[];
  action?: string;
  actionLabel?: string;
  metadata?: HomeCardMetadataDto;
  expiration?: Date;
  visibility?: boolean;
}

export interface HomeSectionDto {
  id: string;
  title: string;
  subtitle?: string;
  layout: string;
  cards: HomeCardDto[];
  isPaginated?: boolean;
  metadata?: Record<string, any>;
  expiration?: Date;
  visibility?: boolean;
}

/**
 * Key names that always denote a live travel price. Compared lower-cased, so
 * `price`, `Price` and `PRICE` are all covered. See {@link HomeCardDto}.
 *
 * The list lives in `card_price_policy.json` — the SAME file the plain-node
 * seed scripts read — so the admin API and the direct-SQL seeds can never
 * drift apart. Re-run the table-driven tests after editing it.
 */
export const CARD_PRICE_KEYS: readonly string[] = policy.priceKeys;

/**
 * Keys whose OBJECT value is a price structure: an `amount`/`value` inside one
 * of these is a travel price even without a sibling currency. Measurement
 * parents (`weight`, `dimensions`, `baggage`, …) are deliberately NOT here,
 * so their amounts survive.
 */
export const CARD_PRICE_CONTAINER_KEYS: readonly string[] =
  policy.priceContainerKeys;

/** Keys that mark a sibling `amount`/`value` as a displayed price. */
export const CARD_CURRENCY_KEYS: readonly string[] = policy.currencyKeys;

/**
 * Generic value keys stripped ONLY with local evidence: a sibling currency or
 * a price-specific parent (see {@link CARD_PRICE_CONTAINER_KEYS}). A bare
 * `amount` on an unrelated object is left untouched.
 */
export const CARD_GENERIC_AMOUNT_KEYS: readonly string[] =
  policy.genericAmountKeys;

/**
 * A card's presentation tree is small. Beyond this depth a subtree is dropped
 * outright: no legitimate card needs it, and it guarantees a pathologically
 * nested payload cannot smuggle a price past the walker.
 */
export const MAX_SANITIZE_DEPTH: number = policy.maxDepth;

const PRICE_KEYS = new Set(CARD_PRICE_KEYS);
const PRICE_CONTAINER_KEYS = new Set(CARD_PRICE_CONTAINER_KEYS);
const CURRENCY_KEYS = new Set(CARD_CURRENCY_KEYS);
const GENERIC_AMOUNT_KEYS = new Set(CARD_GENERIC_AMOUNT_KEYS);

/**
 * Recursively remove live prices from a Home card content/metadata tree.
 *
 * Admin clients send a free-form `content` object, so the rule is enforced on
 * the way in (admin create/update) AND on the way out (`HomeService` applies
 * this to every card before serialising). Nested objects and arrays are walked
 * at any depth, keys are matched case-insensitively, and cyclic references are
 * dropped — so a crafted structure cannot bypass the policy.
 *
 * `amount`/`value` is treated as a price ONLY with local evidence: either its
 * own object also carries a `currency`/`currencyCode` key, or the object is
 * reached through a documented price-specific parent (`total`, `fare`,
 * `taxesAndFees`, …). A bare `amount` elsewhere is left alone: the rule is
 * scoped strictly to Home Card content and must not delete unrelated fields
 * elsewhere in the application (a `weight.amount` in kilograms survives).
 *
 * Unrelated descriptive metadata (titles, badges, provider ids, dates,
 * coordinates, free-text description, …) passes through untouched.
 */
export function sanitizeCardContent(
  content: Record<string, unknown> | null | undefined,
): Record<string, unknown> {
  const cleaned = stripCardPrices(content, 0, new WeakSet<object>());
  if (cleaned === null || typeof cleaned !== 'object' || Array.isArray(cleaned)) {
    return {};
  }
  return cleaned as Record<string, unknown>;
}

function stripCardPrices(
  value: unknown,
  depth: number,
  active: WeakSet<object>,
  parentKey?: string,
): unknown {
  if (value === null || typeof value !== 'object') return value;
  if (depth > MAX_SANITIZE_DEPTH) return undefined;

  if (Array.isArray(value)) {
    const out: unknown[] = [];
    for (const item of value) {
      const cleaned = stripCardPrices(item, depth + 1, active, parentKey);
      if (cleaned !== undefined) out.push(cleaned);
    }
    return out;
  }

  const record = value as Record<string, unknown>;
  if (active.has(record)) return undefined; // cyclic → drop, never loop
  active.add(record);
  try {
    const keys = Object.keys(record);
    const hasCurrency = keys.some((key) =>
      CURRENCY_KEYS.has(key.toLowerCase()),
    );
    // `amount`/`value` is a price when the object it sits in is reached
    // through a documented price-specific parent (`total`, `fare`, …).
    const parentIsPriceContainer =
      parentKey != null &&
      PRICE_CONTAINER_KEYS.has(parentKey.toLowerCase());

    const out: Record<string, unknown> = {};
    for (const key of keys) {
      const lower = key.toLowerCase();
      if (PRICE_KEYS.has(lower)) continue;
      if (
        GENERIC_AMOUNT_KEYS.has(lower) &&
        (hasCurrency || parentIsPriceContainer)
      ) {
        continue;
      }

      const cleaned = stripCardPrices(record[key], depth + 1, active, key);
      if (cleaned !== undefined) out[key] = cleaned;
    }
    return out;
  } finally {
    active.delete(record);
  }
}
