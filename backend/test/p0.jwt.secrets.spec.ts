import jwtConfig, { MIN_JWT_SECRET_BYTES } from '../src/config/jwt.config';

/**
 * P0-S1 — JWT signing secrets.
 *
 * The previous config shipped a hard-coded `dev-access-secret` fallback, so any
 * process started without JWT_* set (i.e. anything not literally named
 * "production") signed access tokens with a secret published in the source
 * tree. These tests pin the fail-closed behaviour: required, independent, and
 * at least 32 bytes of entropy.
 */

type JwtConfig = ReturnType<typeof jwtConfig>;

const VALID_ACCESS = 'a'.repeat(48);
const VALID_REFRESH = 'b'.repeat(48);

const CONTROLLED_KEYS = [
  'JWT_ACCESS_SECRET',
  'JWT_REFRESH_SECRET',
  'NODE_ENV',
  'JEST_WORKER_ID',
] as const;

describe('P0-S1 JWT secrets', () => {
  const original = { ...process.env };

  const load = (env: Record<string, string | undefined>): JwtConfig => {
    for (const key of CONTROLLED_KEYS) {
      const value = env[key];
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
    return (jwtConfig as () => JwtConfig)();
  };

  const restore = () => {
    for (const key of CONTROLLED_KEYS) {
      const value = original[key];
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  };

  afterEach(restore);
  afterAll(restore);

  it('returns both secrets unchanged when they are strong and independent', () => {
    const config = load({
      JWT_ACCESS_SECRET: VALID_ACCESS,
      JWT_REFRESH_SECRET: VALID_REFRESH,
      NODE_ENV: 'production',
      JEST_WORKER_ID: undefined,
    });

    expect(config.accessSecret).toBe(VALID_ACCESS);
    expect(config.refreshSecret).toBe(VALID_REFRESH);
    expect(config.accessSecret).not.toBe(config.refreshSecret);
  });

  it('refuses to boot when a secret is missing', () => {
    expect(() =>
      load({
        JWT_ACCESS_SECRET: VALID_ACCESS,
        JWT_REFRESH_SECRET: undefined,
        NODE_ENV: 'production',
        JEST_WORKER_ID: undefined,
      }),
    ).toThrow(/JWT_REFRESH_SECRET must be set/);

    expect(() =>
      load({
        JWT_ACCESS_SECRET: undefined,
        JWT_REFRESH_SECRET: VALID_REFRESH,
        NODE_ENV: 'production',
        JEST_WORKER_ID: undefined,
      }),
    ).toThrow(/JWT_ACCESS_SECRET must be set/);
  });

  it('refuses to boot when a secret is shorter than 32 bytes', () => {
    expect(Buffer.byteLength('short', 'utf8')).toBeLessThan(MIN_JWT_SECRET_BYTES);

    expect(() =>
      load({
        JWT_ACCESS_SECRET: 'short',
        JWT_REFRESH_SECRET: VALID_REFRESH,
        NODE_ENV: 'production',
        JEST_WORKER_ID: undefined,
      }),
    ).toThrow(/too short/);
  });

  it('refuses to boot when access and refresh share one secret', () => {
    expect(() =>
      load({
        JWT_ACCESS_SECRET: VALID_ACCESS,
        JWT_REFRESH_SECRET: VALID_ACCESS,
        NODE_ENV: 'production',
        JEST_WORKER_ID: undefined,
      }),
    ).toThrow(/must be independent/);
  });

  it('refuses the removed development fallbacks', () => {
    expect(() =>
      load({
        JWT_ACCESS_SECRET: 'dev-access-secret',
        JWT_REFRESH_SECRET: VALID_REFRESH,
        NODE_ENV: 'production',
        JEST_WORKER_ID: undefined,
      }),
    ).toThrow(/known development fallback/);

    expect(() =>
      load({
        JWT_ACCESS_SECRET: VALID_ACCESS,
        JWT_REFRESH_SECRET: 'dev-refresh-secret',
        NODE_ENV: 'production',
        JEST_WORKER_ID: undefined,
      }),
    ).toThrow(/known development fallback/);
  });

  it('still loads in test mode so the existing suite can boot', () => {
    const config = load({
      JWT_ACCESS_SECRET: undefined,
      JWT_REFRESH_SECRET: undefined,
      NODE_ENV: 'test',
      JEST_WORKER_ID: original.JEST_WORKER_ID,
    });

    expect(config.accessSecret).toBeTruthy();
    expect(config.refreshSecret).toBeTruthy();
  });
});
