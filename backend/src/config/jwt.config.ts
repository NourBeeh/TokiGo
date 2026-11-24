import { registerAs } from '@nestjs/config';

/**
 * JWT signing configuration.
 *
 * There are NO development fallbacks. Both secrets must come from the
 * environment and carry at least {@link MIN_JWT_SECRET_BYTES} bytes of entropy;
 * the process refuses to boot without them. A hard-coded fallback is a
 * published signing key — anyone could mint a valid access token for any user.
 *
 * Access and refresh secrets must also be INDEPENDENT: a refresh token must
 * never be usable as an access token.
 *
 * Jest is the single exception: tests load this config without real secrets and
 * receive placeholders that never leave the test process.
 */

/** Minimum accepted secret length, in bytes. */
export const MIN_JWT_SECRET_BYTES = 32;

/** Values that must never be accepted as a real secret. */
const FORBIDDEN_SECRETS = new Set(['dev-access-secret', 'dev-refresh-secret']);

const TEST_ACCESS_SECRET = 'test-only-access-secret';
const TEST_REFRESH_SECRET = 'test-only-refresh-secret';

const isTestMode = (): boolean =>
  process.env.NODE_ENV === 'test' || Boolean(process.env.JEST_WORKER_ID);

const byteLength = (value: string): number => Buffer.byteLength(value, 'utf8');

export default registerAs('jwt', () => {
  const accessSecret = process.env.JWT_ACCESS_SECRET;
  const refreshSecret = process.env.JWT_REFRESH_SECRET;

  // Test runs have no real secrets; placeholders keep the config loadable.
  if (isTestMode()) {
    return {
      accessSecret: accessSecret || TEST_ACCESS_SECRET,
      refreshSecret: refreshSecret || TEST_REFRESH_SECRET,
      accessExpiresIn: process.env.JWT_ACCESS_EXPIRES_IN ?? '15m',
      refreshExpiresIn: process.env.JWT_REFRESH_EXPIRES_IN ?? '7d',
    };
  }

  const missing: string[] = [];
  if (!accessSecret) missing.push('JWT_ACCESS_SECRET');
  if (!refreshSecret) missing.push('JWT_REFRESH_SECRET');
  if (missing.length > 0) {
    throw new Error(
      `${missing.join(' and ')} must be set. Generate two independent secrets ` +
        `with 'openssl rand -base64 48' (at least ${MIN_JWT_SECRET_BYTES} ` +
        'bytes each). The backend will not start without them.',
    );
  }

  // Narrowed by the check above: both are present from here on.
  const access = accessSecret as string;
  const refresh = refreshSecret as string;

  for (const [name, value] of [
    ['JWT_ACCESS_SECRET', access],
    ['JWT_REFRESH_SECRET', refresh],
  ] as const) {
    if (FORBIDDEN_SECRETS.has(value)) {
      throw new Error(`${name} is set to a known development fallback.`);
    }
  }

  const tooShort: string[] = [];
  if (byteLength(access) < MIN_JWT_SECRET_BYTES) {
    tooShort.push(`JWT_ACCESS_SECRET (${byteLength(access)} bytes)`);
  }
  if (byteLength(refresh) < MIN_JWT_SECRET_BYTES) {
    tooShort.push(`JWT_REFRESH_SECRET (${byteLength(refresh)} bytes)`);
  }
  if (tooShort.length > 0) {
    throw new Error(
      `JWT secrets are too short: ${tooShort.join(', ')}. Minimum is ` +
        `${MIN_JWT_SECRET_BYTES} bytes of random material.`,
    );
  }

  if (access === refresh) {
    throw new Error(
      'JWT_ACCESS_SECRET and JWT_REFRESH_SECRET must be independent: a leaked ' +
        'refresh token must not be usable as an access token.',
    );
  }

  return {
    accessSecret: access,
    refreshSecret: refresh,
    accessExpiresIn: process.env.JWT_ACCESS_EXPIRES_IN ?? '15m',
    refreshExpiresIn: process.env.JWT_REFRESH_EXPIRES_IN ?? '7d',
  };
});
