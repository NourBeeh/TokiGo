/**
 * Shared Home-card price policy for the seed scripts (P0-S4 / L2).
 *
 * The key lists live in `src/common/dto/card_price_policy.json` — the SAME
 * file `backend/src/common/dto/home.dto.ts` imports — so the direct-SQL seeds
 * and the admin API can never drift apart. Edit the JSON, not this file.
 *
 * Kept as a plain CommonJS module because the scripts run under plain node.
 */

const policy = require('../../src/common/dto/card_price_policy.json');

/** Key names that always denote a live travel price (compared lower-cased). */
const PRICE_KEYS = new Set(policy.priceKeys);

/** Keys whose object value is a price structure (parent context). */
const PRICE_CONTAINER_KEYS = new Set(policy.priceContainerKeys);

/** Keys that mark a sibling `amount`/`value` as a displayed price. */
const CURRENCY_KEYS = new Set(policy.currencyKeys);

/** Generic value keys stripped only with currency or price-parent context. */
const GENERIC_AMOUNT_KEYS = new Set(policy.genericAmountKeys);

/**
 * A card's presentation tree is small. Beyond this depth a subtree is dropped
 * outright so a pathologically nested payload cannot smuggle a price past the
 * walker.
 */
const MAX_DEPTH = policy.maxDepth;

function stripPrices(value, depth, active, parentKey) {
  if (value === null || typeof value !== 'object') return value;
  if (depth > MAX_DEPTH) return undefined;

  if (Array.isArray(value)) {
    const out = [];
    for (const item of value) {
      const cleaned = stripPrices(item, depth + 1, active, parentKey);
      if (cleaned !== undefined) out.push(cleaned);
    }
    return out;
  }

  if (active.has(value)) return undefined; // cyclic -> drop, never loop
  active.add(value);
  try {
    const keys = Object.keys(value);
    const hasCurrency = keys.some((key) =>
      CURRENCY_KEYS.has(key.toLowerCase()),
    );
    const parentIsPriceContainer =
      parentKey != null &&
      PRICE_CONTAINER_KEYS.has(parentKey.toLowerCase());

    const out = {};
    for (const key of keys) {
      const lower = key.toLowerCase();
      if (PRICE_KEYS.has(lower)) continue;
      if (
        GENERIC_AMOUNT_KEYS.has(lower) &&
        (hasCurrency || parentIsPriceContainer)
      ) {
        continue;
      }

      const cleaned = stripPrices(value[key], depth + 1, active, key);
      if (cleaned !== undefined) out[key] = cleaned;
    }
    return out;
  } finally {
    active.delete(value);
  }
}

/**
 * Returns a copy of `content` with every live price removed.
 * Non-object input yields `{}`.
 */
function sanitizeCardContent(content) {
  const cleaned = stripPrices(content, 0, new Set(), undefined);
  if (cleaned === null || typeof cleaned !== 'object' || Array.isArray(cleaned)) {
    return {};
  }
  return cleaned;
}

module.exports = {
  sanitizeCardContent,
  PRICE_KEYS,
  PRICE_CONTAINER_KEYS,
  CURRENCY_KEYS,
  GENERIC_AMOUNT_KEYS,
  MAX_DEPTH,
};
