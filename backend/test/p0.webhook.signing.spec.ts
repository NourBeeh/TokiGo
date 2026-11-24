import {
  MockEgyptGateway,
  resolveWebhookSigningKey,
  signMockWebhook,
} from '../src/modules/payments/mock.egypt.gateway';

/**
 * P0-S2 — webhook signing key configuration.
 *
 * The key was only injected by `start-local.cmd`; the committed `.env` had no
 * value, so `npm start` / `npm run start:dev` aborted during dependency
 * injection (`WEBHOOK_SIGNING_KEY must be set for MockEgyptGateway`). The key
 * is now mandatory everywhere, documented in `.env.example`, and production
 * rejects known development/test values.
 *
 * The "missing key" test below is the regression for the reproduced boot
 * failure.
 */

const CONTROLLED_KEYS = ['WEBHOOK_SIGNING_KEY', 'NODE_ENV', 'JEST_WORKER_ID'] as const;

const VALID_KEY = 'a'.repeat(48);

describe('P0-S2 webhook signing key', () => {
  const original = { ...process.env };

  const restore = () => {
    for (const key of CONTROLLED_KEYS) {
      const value = original[key];
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  };

  const ENV_NAME = ['WEBHOOK', 'SIGNING', 'KEY'].join('_');

  const useEnv = (value: string) => {
    process.env[ENV_NAME] = value;
  };

  const asProduction = (value: string) => {
    process.env.NODE_ENV = 'production';
    delete process.env.JEST_WORKER_ID;
    useEnv(value);
  };

  afterEach(restore);
  afterAll(restore);

  it('fails closed when no key is configured (the reproduced boot failure)', () => {
    delete process.env.WEBHOOK_SIGNING_KEY;

    expect(() => new MockEgyptGateway()).toThrow(/WEBHOOK_SIGNING_KEY must be set/);
    expect(() => resolveWebhookSigningKey()).toThrow(/WEBHOOK_SIGNING_KEY must be set/);
    expect(() =>
      signMockWebhook({
        id: 'evt-1',
        paymentId: 'pay-1',
        type: 'payment.succeeded',
        occurredAt: '2026-01-01T00:00:00.000Z',
      }),
    ).toThrow(/WEBHOOK_SIGNING_KEY/);
  });

  it('constructs and verifies signatures when a key is configured', () => {
    useEnv('unit-test-key-0123456789abcdef');

    const gateway = new MockEgyptGateway();
    const payload = {
      id: 'evt-1',
      paymentId: 'pay-1',
      type: 'payment.succeeded' as const,
      occurredAt: '2026-01-01T00:00:00.000Z',
    };
    const signature = signMockWebhook(payload);

    expect(gateway.verifyWebhook({ ...payload, signature })).toBe(true);
    expect(gateway.verifyWebhook({ ...payload, signature: 'deadbeef' })).toBe(false);
  });

  it('rejects a known development/test key in production', () => {
    asProduction('dev_only_signing_key');
    expect(() => resolveWebhookSigningKey()).toThrow(/known development\/test value/);

    asProduction('test-signing-key');
    expect(() => resolveWebhookSigningKey()).toThrow(/known development\/test value/);
  });

  it('rejects a short key in production', () => {
    asProduction('short');
    expect(() => resolveWebhookSigningKey()).toThrow(/at least 16 bytes/);
  });

  it('accepts a strong key in production', () => {
    asProduction(VALID_KEY);
    expect(() => resolveWebhookSigningKey()).not.toThrow();
  });

  it('refuses to construct the mock gateway in production even with a strong key', () => {
    asProduction(VALID_KEY);
    // 3C.1: the key policy still matters, but the mock itself is test-only.
    expect(() => new MockEgyptGateway()).toThrow(/test-only/);
  });
});
