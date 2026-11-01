#!/usr/bin/env node
/**
 * Warms the hotel search cache for the popular cities of the launch markets.
 *
 * A cold `POST /search/hotels` costs 3.5–5s because that is Nuitee's own
 * latency. Running this on a schedule (cron, or `SEARCH_WARM_INTERVAL_MINUTES`
 * in the backend) means the first traveller of the weekend gets the warm path
 * (~10ms) instead of paying for the provider call.
 *
 * The body is exactly what the app sends, and the backend's cache key is
 * canonical, so the warmed entry matches real requests regardless of field
 * order or city casing.
 *
 * Usage (from backend/):
 *   npm run prewarm:search
 *   BACKEND_URL=https://api.tokigo.app PREWARM_WEEKS=1 npm run prewarm:search
 *   PREWARM_CITIES="Cairo,EG;Dubai,AE" npm run prewarm:search
 */

const BASE_URL = (process.env.BACKEND_URL || 'http://localhost:3000').replace(
  /\/+$/,
  '',
);

const DEFAULT_CITIES = [
  ['Cairo', 'EG'],
  ['Hurghada', 'EG'],
  ['Sharm El Sheikh', 'EG'],
  ['Dubai', 'AE'],
  ['Abu Dhabi', 'AE'],
  ['Riyadh', 'SA'],
  ['Jeddah', 'SA'],
  ['Istanbul', 'TR'],
  ['Antalya', 'TR'],
  ['London', 'GB'],
];

const DAY_MS = 24 * 60 * 60 * 1000;

const cities = (process.env.PREWARM_CITIES || '')
  .split(';')
  .map((entry) => entry.trim())
  .filter(Boolean)
  .map((entry) => entry.split(',').map((part) => part.trim()))
  .filter((parts) => parts.length === 2 && /^[A-Za-z]{2}$/.test(parts[1]))
  .map(([city, country]) => [city, country.toUpperCase()]);

const targets = cities.length > 0 ? cities : DEFAULT_CITIES;
const weeks = Math.max(Number(process.env.PREWARM_WEEKS) || 2, 1);

/** Friday → Sunday of the upcoming weekend (same rule as the backend). */
function weekendWindow(weeksAhead) {
  const now = new Date();
  const today = new Date(
    Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()),
  );
  const untilFriday = (5 - today.getUTCDay() + 7) % 7 || 7;
  const friday = new Date(
    today.getTime() + (untilFriday + weeksAhead * 7) * DAY_MS,
  );
  const sunday = new Date(friday.getTime() + 2 * DAY_MS);
  return {
    checkIn: friday.toISOString().slice(0, 10),
    checkOut: sunday.toISOString().slice(0, 10),
  };
}

async function warm(city, country, window) {
  const body = {
    city,
    country,
    checkIn: window.checkIn,
    checkOut: window.checkOut,
    guests: 2,
    rooms: 1,
    market: country,
  };
  const started = Date.now();
  const response = await fetch(`${BASE_URL}/search/hotels`, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      accept: 'application/json',
      'accept-encoding': 'gzip',
    },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(60_000),
  });
  const payload = await response.json().catch(() => ({}));
  const offers = Array.isArray(payload?.successes)
    ? payload.successes.reduce(
        (sum, entry) => sum + (Array.isArray(entry?.data) ? entry.data.length : 0),
        0,
      )
    : 0;
  const failures = Array.isArray(payload?.failures)
    ? payload.failures.length
    : 0;
  return {
    line:
      `${city}/${country} ${window.checkIn}: HTTP ${response.status}, ` +
      `${offers} offers, ${failures} failure(s), ${Date.now() - started}ms`,
    cached: response.ok && failures === 0,
  };
}

async function main() {
  console.log(`Warming ${BASE_URL} — ${targets.length} city(ies), ${weeks} weekend(s)`);
  let warmed = 0;
  for (let week = 0; week < weeks; week += 1) {
    const stayWindow = weekendWindow(week);
    for (const [city, country] of targets) {
      try {
        const result = await warm(city, country, stayWindow);
        if (result.cached) warmed += 1;
        console.log(`  ${result.line}`);
      } catch (error) {
        console.error(`  ${city}/${country}: FAILED — ${error.message}`);
      }
    }
  }
  console.log(`\n${warmed} search(es) cached.`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
