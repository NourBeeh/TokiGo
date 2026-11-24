import { ProviderFailureKind, ProviderResult } from './provider.result';

/**
 * Conservative classification of provider booking failures.
 *
 * The default is ALWAYS `ambiguous`: a booking may exist unless the provider
 * explicitly rejected the request. A false `definitive` is dangerous (it
 * reopens the idempotency key and allows a second provider submission), so
 * only evidence we can actually point at is accepted.
 */

/** HTTP statuses where a retry is never safe to infer from the status alone. */
const NON_DEFINITIVE_HTTP_STATUSES = new Set([408, 409, 425, 429]);

/**
 * Provider error codes that mean "this booking may already exist".
 *
 * Nuitee hotel `4005` is returned for a duplicate `clientReference` and
 * Nuitee flights `45035` for a concurrent duplicate of the same `prebookId`.
 * A duplicate is NEVER a rejection: the first request may have succeeded, so
 * it must stay ambiguous even when it arrives with a 4xx status.
 */
const NON_DEFINITIVE_PROVIDER_CODES = new Set(['4005', '45035']);

/**
 * A well-formed 4xx response (except the in-progress / retryable statuses
 * above) means the provider understood and refused the request. Everything
 * else — 2xx, 5xx, timeouts, no status — stays ambiguous.
 */
export function failureKindFromHttpStatus(
  status: number | undefined,
): ProviderFailureKind {
  if (typeof status !== 'number' || !Number.isInteger(status)) {
    return 'ambiguous';
  }
  if (
    status >= 400 &&
    status < 500 &&
    !NON_DEFINITIVE_HTTP_STATUSES.has(status)
  ) {
    return 'definitive';
  }
  return 'ambiguous';
}

/**
 * Nuitee's transport embeds the HTTP status in its error text, e.g.
 * `Nuitee /rates/book failed (422): ...`, and the provider code when present,
 * e.g. `Nuitee /rates/book failed (400) [4005]: Duplicate ...`. Parse only a
 * well-formed status; a message without one is ambiguous.
 */
export function failureKindFromProviderMessage(
  message: string | undefined,
): ProviderFailureKind {
  if (!message) return 'ambiguous';
  const providerCode = /\[(\d+)\]/.exec(message);
  if (providerCode && NON_DEFINITIVE_PROVIDER_CODES.has(providerCode[1])) {
    return 'ambiguous';
  }
  const match = /\((\d{3})\)/.exec(message);
  if (!match) return 'ambiguous';
  return failureKindFromHttpStatus(Number(match[1]));
}

/**
 * Classification for a failed `bookHotel` / `bookFlight` transport result.
 * An explicit `failureKind` from the transport wins; otherwise derive it from
 * the status embedded in the message. Missing config is a local failure and
 * therefore definitive (no request was sent).
 */
export function classifyBookingTransportFailure(input: {
  failureKind?: ProviderFailureKind;
  error?: string;
}): ProviderFailureKind {
  if (input.failureKind === 'definitive' || input.failureKind === 'ambiguous') {
    return input.failureKind;
  }
  if (input.error === 'NUITEE_API_KEY missing') return 'definitive';
  return failureKindFromProviderMessage(input.error);
}

/**
 * Service-side safety net: only an explicitly classified definitive failure
 * may reopen the booking. Anything else (including a malformed value) is
 * ambiguous.
 */
export function isDefinitiveBookingFailure(
  result: ProviderResult<unknown>,
): boolean {
  return result.success === false && result.failureKind === 'definitive';
}
