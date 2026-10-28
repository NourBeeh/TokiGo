/**
 * Publishes additional real destination cities (2026-10-22, owner-approved).
 *
 * Two content gaps were fixed here:
 *
 *   Nature  Dahab · Nuweiba · Marsa Alam            (nature + beach)
 *   Snow    Gudauri · Shahdag · Innsbruck           (snow)
 *
 * The earlier snow probe wrongly reported "no inventory anywhere": it queried
 * the rates endpoint without each city's country code (the fallback is EG), and
 * it used a same-week October window — both guaranteed an empty answer for a
 * ski resort. With the country sent and a February window, Nuitee returns real
 * winter stays for all three cities (and for 20+ other ski destinations).
 *
 * Nothing is invented: a city is published only when Nuitee returns real stays
 * for it, and the cover photo + count come from that same response. Duffel
 * Stays is deliberately ignored (its adapter serves a curated fake catalogue;
 * it is disabled in the provider registry).
 *
 * The rows use fixed ids inside the existing Discover section, so re-running
 * updates them in place. Existing cards are never touched.
 *
 * Usage (from backend/, with the API + DB up):
 *   node scripts/add-destination-cities.js
 */
const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '..', '.env') });

const { Client } = require('pg');

const API = process.env.PUBLIC_API_URL || 'http://127.0.0.1:3000';
const DISCOVER_SECTION_ID = '00000000-0000-4000-8000-000000000002';

const CITIES = [
  {
    id: '20000000-0000-4000-8000-000000000011',
    name: 'Dahab',
    country: 'Egypt',
    countryCode: 'EG',
    moods: ['nature', 'beach'],
    order: 11,
  },
  {
    id: '20000000-0000-4000-8000-000000000012',
    name: 'Nuweiba',
    country: 'Egypt',
    countryCode: 'EG',
    moods: ['nature', 'beach'],
    order: 12,
  },
  {
    id: '20000000-0000-4000-8000-000000000013',
    name: 'Marsa Alam',
    country: 'Egypt',
    countryCode: 'EG',
    moods: ['nature', 'beach'],
    order: 13,
  },
  // Snow is seasonal: the city itself is permanent, but a ski resort only has
  // rates in winter. The count below is a real February snapshot.
  {
    id: '20000000-0000-4000-8000-000000000014',
    name: 'Gudauri',
    country: 'Georgia',
    countryCode: 'GE',
    moods: ['snow'],
    seasonal: true,
    order: 14,
  },
  {
    id: '20000000-0000-4000-8000-000000000015',
    name: 'Shahdag',
    country: 'Azerbaijan',
    countryCode: 'AZ',
    moods: ['snow'],
    seasonal: true,
    order: 15,
  },
  {
    id: '20000000-0000-4000-8000-000000000016',
    name: 'Innsbruck',
    country: 'Austria',
    countryCode: 'AT',
    moods: ['snow'],
    seasonal: true,
    order: 16,
  },
  {
    id: '20000000-0000-4000-8000-000000000017',
    name: 'Rovaniemi',
    country: 'Finland',
    countryCode: 'FI',
    moods: ['snow'],
    seasonal: true,
    order: 17,
  },
];

const dbConfig = {
  host: process.env.DB_HOST || 'localhost',
  port: Number(process.env.DB_PORT || 5432),
  user: process.env.DB_USER || 'wetravellers',
  password: process.env.DB_PASSWORD || 'wetravellers',
  database: process.env.DB_NAME || 'wetravellers',
};

/// A same-week window for year-round cities; the upcoming 12–15 February for
/// snow cities (a ski resort has no autumn rates, and that is not "no city").
function stayWindow(seasonal) {
  if (seasonal) {
    const today = new Date();
    const pastFebruary = today.getMonth() > 1 ||
      (today.getMonth() === 1 && today.getDate() > 15);
    const year = today.getFullYear() + (pastFebruary ? 1 : 0);
    return { checkIn: `${year}-02-12`, checkOut: `${year}-02-15` };
  }
  const start = new Date();
  start.setDate(start.getDate() + 7);
  const end = new Date(start);
  end.setDate(end.getDate() + 3);
  return {
    checkIn: start.toISOString().slice(0, 10),
    checkOut: end.toISOString().slice(0, 10),
  };
}

/// Real Nuitee stays for one city (the Duffel fake catalogue is ignored).
/// Nuitee intermittently answers [] under burst traffic; retry before calling
/// a city empty, otherwise a rate limit would silently drop a real city.
async function nuiteeStays(city) {
  const { checkIn, checkOut } = stayWindow(city.seasonal);
  for (let attempt = 0; attempt < 3; attempt += 1) {
    const response = await fetch(`${API}/search/hotels`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        city: city.name,
        country: city.countryCode,
        checkIn,
        checkOut,
        guests: 2,
      }),
    });
    if (!response.ok) {
      throw new Error(`/search/hotels answered ${response.status} for ${city.name}`);
    }
    const payload = await response.json();
    const entry = (payload?.successes || []).find(
      (success) => success.providerId === 'nuitee',
    );
    const data = entry?.data;
    const stays = Array.isArray(data) ? data : data ? [data] : [];
    if (stays.length > 0) return stays;
    await new Promise((resolve) => setTimeout(resolve, 2000));
  }
  return [];
}

(async () => {
  const client = new Client(dbConfig);
  await client.connect();
  try {
    for (const city of CITIES) {
      const stays = await nuiteeStays(city);
      if (stays.length === 0) {
        console.log(`skip  ${city.name} — Nuitee has no real stays in the window`);
        continue;
      }
      const imageUrl = stays.find((stay) => stay?.imageUrl)?.imageUrl ?? null;
      await client.query(
        `INSERT INTO home_cards (id, "sectionId", "cardType", content, "order", "isVisible", status)
         VALUES ($1,$2,'destination',$3::jsonb,$4,true,'published')
         ON CONFLICT (id) DO UPDATE SET
           content = EXCLUDED.content,
           "order" = EXCLUDED."order",
           "isVisible" = true,
           status = 'published'`,
        [
          city.id,
          DISCOVER_SECTION_ID,
          JSON.stringify({
            title: city.name,
            subtitle: city.country,
            imageUrl,
            metadata: {
              country: city.country,
              countryCode: city.countryCode,
              staysCount: stays.length,
              moods: city.moods,
              ...(city.seasonal ? { seasonal: 'winter' } : {}),
            },
          }),
          city.order,
        ],
      );
      console.log(
        `ok    ${city.name} → ${stays.length} stays, moods ${city.moods.join('+')}`,
      );
    }
  } finally {
    await client.end();
  }
})().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
