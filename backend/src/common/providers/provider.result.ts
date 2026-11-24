/**
 * How certain a failed provider call is that the provider did NOT create
 * anything.
 *
 * - `definitive`: the provider explicitly refused the request before creating
 *   a booking (local validation, an auth/config failure, or a well-formed
 *   provider rejection). Retrying is safe.
 * - `ambiguous`: the request may have reached the provider and may have
 *   created a booking (timeout, lost response, 5xx, malformed response,
 *   unknown transport state). Retrying is NOT safe until the outcome is
 *   reconciled.
 *
 * Callers MUST treat an absent or malformed value on a failed result as
 * `ambiguous`. `success: true` ignores this field.
 */
export type ProviderFailureKind = 'definitive' | 'ambiguous';

export interface ProviderResult<T> {
  success: boolean;
  providerId: string;
  providerName: string;
  data?: T;
  error?: string;
  /**
   * Only meaningful when `success` is false. See [ProviderFailureKind].
   * Omitted means `ambiguous` for fail-safe consumers.
   */
  failureKind?: ProviderFailureKind;
  timestamp: Date;
  metadata?: Record<string, any>;
}
