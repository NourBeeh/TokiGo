import { ProviderConfirmationState } from './booking-provider.interface';

/**
 * Provider-status vocabulary shared by the booking adapters.
 *
 * Only an explicit provider confirmation may become a confirmed TokiGo
 * booking. This module never guesses: an unpublished/unknown status is
 * `unknown`, and every intermediate lifecycle state is `pending`.
 */

const CONFIRMED_STATUSES = new Set(['CONFIRMED', 'TICKETED', 'BOOKED']);

const FAILED_STATUSES = new Set([
  'CANCELED',
  'CANCELLED',
  'CANCELLED_WITH_CHARGES',
  'FAILED',
  'REJECTED',
]);

const PENDING_STATUSES = new Set([
  'CREATED',
  'PENDING',
  'PENDING_CONFIRMATION',
  'REQUESTED',
  'PROCESSING',
  'IN_PROGRESS',
]);

/** Normalize a provider booking status into the shared confirmation state. */
export function confirmationStateOfStatus(
  status: unknown,
): ProviderConfirmationState {
  if (typeof status !== 'string') return 'unknown';
  const normalized = status.trim().toUpperCase();
  if (!normalized) return 'unknown';
  if (CONFIRMED_STATUSES.has(normalized)) return 'confirmed';
  if (FAILED_STATUSES.has(normalized)) return 'failed';
  if (PENDING_STATUSES.has(normalized)) return 'pending';
  return 'unknown';
}

/**
 * Build the deterministic, non-sensitive provider labels that bind a provider
 * booking to the TokiGo booking/payment. Keys are valid both for Nuitee
 * `customTags` (uppercase `[A-Z0-9_-]+`) and Duffel order metadata
 * (`[A-Za-z0-9_-]`), and no customer PII is included.
 *
 * At most five tags are produced, which is Nuitee's documented maximum.
 */
export function bookingProviderTags(input: {
  bookingId?: string;
  amount?: number;
  currency?: string;
  priceVersion?: string;
  paymentAttemptId?: string;
}): Record<string, string> {
  const tags: Record<string, string> = {};
  const put = (key: string, value: unknown): void => {
    if (Object.keys(tags).length >= 5) return;
    if (typeof value !== 'string') return;
    const trimmed = value.trim();
    if (!trimmed) return;
    tags[key] = trimmed.slice(0, 255);
  };

  put('BOOKING_ID', input.bookingId);
  put('PRICE_VERSION', input.priceVersion);
  put('PAYMENT_ATTEMPT', input.paymentAttemptId);
  if (
    typeof input.amount === 'number' &&
    Number.isFinite(input.amount) &&
    input.amount > 0
  ) {
    put('AMOUNT', String(input.amount));
  }
  put('CURRENCY', input.currency?.trim().toUpperCase());
  return tags;
}
