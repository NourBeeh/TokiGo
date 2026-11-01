#!/usr/bin/env node
/**
 * Warms the Home rail cache for the launch markets.
 *
 * A cold `/home/recommended` request asks the provider for every city in the
 * market (0.7–5s). Running this after a deploy means the first traveller gets
 * the ~80ms warm path. Safe to run repeatedly: the endpoint is idempotent and
 * the cache TTL (default 5 min) bounds staleness.
 *
 * Usage (from backend/):
 *   npm run prewarm:home
 *   BACKEND_URL=https://api.tokigo.app npm run prewarm:home
 */

const BASE_URL = (process.env.BACKEND_URL || 'http://localhost:3000').replace(
  /\/+$/,
  '',
);
const MARKETS = (process.env.PREWARM_MARKETS || 'EG,AE,SA,TR,GB')
  .split(',')
  .map((code) => code.trim().toUpperCase())
  .filter((code) => /^[A-Z]{2}$/.test(code));

async function warm(code) {
  const url = `${BASE_URL}/home/recommended?limit=6&code=${code}`;
  const started = Date.now();
  const response = await fetch(url, {
    headers: { accept: 'application/json' },
    signal: AbortSignal.timeout(60_000),
  });
  const body = await response.json().catch(() => ({}));
  const hotels = Array.isArray(body?.hotels) ? body.hotels.length : 0;
  return `${code}: HTTP ${response.status}, ${hotels} hotels, ${
    Date.now() - started
  }ms`;
}

async function main() {
  console.log(`Warming ${BASE_URL} for: ${MARKETS.join(', ')}`);
  for (const code of MARKETS) {
    try {
      console.log(`  ${await warm(code)}`);
    } catch (error) {
      console.error(`  ${code}: FAILED — ${error.message}`);
    }
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
