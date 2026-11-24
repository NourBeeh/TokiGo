/**
 * Publishes the real "Discover" section from the provider's own live data.
 *
 * The old "Hotels recommended for you" section was removed with the legacy
 * Home system; Home now renders the bundled Explore catalog plus the
 * promotional Nearby Stays rail, and the Explore Cities page merges the
 * destination cards this script publishes.
 *
 * Nothing here is invented: every city and stay count comes from the
 * provider's response; the city photo comes from the city's own Wikidata image
 * with the attribution its licence requires. A city with no stays is simply not
 * published.
 *
 * The rows are written with FIXED ids, so re-running replaces them in place
 * and never duplicates. `npm run seed:home:clean` removes them again.
 *
 * Run:  npm run seed:home:real      (from backend/, with the API running)
 */
const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '..', '.env') });

const { Client } = require('pg');
const { countryCodeFor, countryNameFor } = require('./lib/countries');
const { cityImageFor } = require('./lib/destination-image');
const { sanitizeCardContent } = require('./lib/sanitize_card_content');

/// P0-S4 / L2: card content is sanitized with the SAME policy as the admin API
/// before it is written, so this direct-SQL seed cannot persist a live price
/// (including one nested in `metadata`).
const json = (content) => JSON.stringify(sanitizeCardContent(content));

const dbConfig = {
  host: process.env.DB_HOST || 'localhost',
  port: Number(process.env.DB_PORT || 5432),
  user: process.env.DB_USER || 'wetravellers',
  password: process.env.DB_PASSWORD || 'wetravellers',
  database: process.env.DB_NAME || 'wetravellers',
};

const API = process.env.PUBLIC_API_URL || 'http://127.0.0.1:3000';

const SECTIONS = {
  discover: {
    id: '00000000-0000-4000-8000-000000000002',
    title: 'Explore',
    subtitle: 'Where travellers are going',
    layout: 'grid',
    order: 2,
  },
};

/// A fixed id per row, per section — so re-running replaces the row in place
/// (and the two sections never share an id). Discover ids are offset by 100
/// so they can never collide with the authored destination-city ids
/// (20000000-…-011…017) that add-destination-cities.js owns.
const uuidFor = (index) =>
  `20000000-0000-4000-8000-${String(100 + index).padStart(12, '0')}`;

/// The app's own destination list (lib/features/search/presentation/widgets/
/// destination_picker_sheet.dart) — the same cities the traveller can pick.
/// A city is published only if the provider really has stays in it.
const CITIES = [
  { name: 'Cairo', country: 'Egypt', code: 'EG' },
  { name: 'Dubai', country: 'UAE', code: 'AE' },
  { name: 'Riyadh', country: 'Saudi Arabia', code: 'SA' },
  { name: 'Jeddah', country: 'Saudi Arabia', code: 'SA' },
  { name: 'Hurghada', country: 'Egypt', code: 'EG' },
  { name: 'Sharm El Sheikh', country: 'Egypt', code: 'EG' },
  { name: 'Luxor', country: 'Egypt', code: 'EG' },
  { name: 'Aswan', country: 'Egypt', code: 'EG' },
  { name: 'Alexandria', country: 'Egypt', code: 'EG' },
  { name: 'Istanbul', country: 'Turkey', code: 'TR' },
];

/// A date window the provider accepts: a week from today, three nights.
function window() {
  const start = new Date();
  start.setDate(start.getDate() + 7);
  const end = new Date(start);
  end.setDate(end.getDate() + 3);
  return { checkIn: start.toISOString().slice(0, 10), checkOut: end.toISOString().slice(0, 10) };
}

/// The provider's real stays in one city (empty when it has none).
async function searchCity(candidate) {
  const city = candidate.name;
  const { checkIn, checkOut } = window();
  try {
    const response = await fetch(`${API}/search/hotels`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ city, country: candidate.code, checkIn, checkOut, guests: 2 }),
    });
    if (!response.ok) return [];
    const payload = await response.json();
    const successes = Array.isArray(payload?.successes) ? payload.successes : [];
    const offers = [];
    for (const entry of successes) {
      const data = entry?.data;
      if (Array.isArray(data)) offers.push(...data);
      else if (data) offers.push(data);
    }
    return offers;
  } catch (_) {
    return [];
  }
}

(async () => {
  // The cities the provider really has stays in, from the app's own
  // destination list (a city with no stays is not published — the tile would
  // be an empty promise).
  const cities = new Map();
  const cityKey = (city, country) => {
    const code = countryCodeFor(country) ?? String(country ?? '').trim().toUpperCase();
    return {
      key: `${String(city ?? '').trim().toLowerCase()}|${code}`,
      code: code || null,
      country: countryNameFor(country) || null,
    };
  };
  const remember = (city, country) => {
    const resolved = cityKey(city, country);
    if (!cities.has(resolved.key)) {
      cities.set(resolved.key, {
        city: String(city).trim(),
        country: resolved.country,
        code: resolved.code,
        count: 0,
      });
    }
    const entry = cities.get(resolved.key);
    entry.count += 1;
    return entry;
  };

  for (const candidate of CITIES) {
    const key = cityKey(candidate.name, candidate.country).key;
    if (cities.has(key)) continue;
    const offers = await searchCity(candidate);
    if (offers.length === 0) continue;
    // The real count of stays the provider returned for that city.
    remember(candidate.name, candidate.code).count = offers.length;
  }

  // Real city photography (not a hotel photo): resolved once per published
  // city, with the attribution Commons requires. Null → honest placeholder.
  for (const entry of cities.values()) {
    entry.photo = await cityImageFor(entry.city);
  }

  const client = new Client(dbConfig);
  await client.connect();
  try {
    await client.query('BEGIN');

    // Start from a clean slate for the rows this script owns, so a shorter
    // list never leaves a stale card behind. The authored destination cities
    // (20000000-…-011…017, owned by add-destination-cities.js) are NOT ours to
    // delete — re-seeding the recommended stays must not unpublish them.
    await client.query(
      `DELETE FROM home_cards
        WHERE "sectionId" = $1
          AND id::text LIKE '20000000-0000-4000-8000-0000000001%'`,
      [SECTIONS.discover.id],
    );

    await client.query(
      `INSERT INTO home_sections (id, title, subtitle, layout, "order", "isVisible", status)
       VALUES ($1,$2,$3,$4,$5,true,'published')
       ON CONFLICT (id) DO UPDATE SET
         title = EXCLUDED.title,
         subtitle = EXCLUDED.subtitle,
         layout = EXCLUDED.layout,
         "order" = EXCLUDED."order",
         "isVisible" = true,
         status = 'published'`,
      [
        SECTIONS.discover.id,
        SECTIONS.discover.title,
        SECTIONS.discover.subtitle,
        SECTIONS.discover.layout,
        SECTIONS.discover.order,
      ],
    );

    // The cities (card D) — a city tile carries no price of its own: the
    // card shows the city, its country and how many real stays are in it.
    //
    // A city another script already published (add-destination-cities.js owns
    // Dahab…Rovaniemi) must not be inserted a second time just because the
    // recommended feed now happens to include it: one city, one card.
    const existing = await client.query(
      `select content->>'title' as title, content->'metadata' as metadata
         from home_cards
        where "sectionId" = $1 and "cardType" = 'destination'`,
      [SECTIONS.discover.id],
    );
    const alreadyPublished = new Set(
      existing.rows.map((row) =>
        cityKey(row.title, row.metadata?.country ?? row.metadata?.countryCode).key,
      ),
    );

    index = 1;
    let publishedCities = 0;
    for (const entry of cities.values()) {
      if (alreadyPublished.has(cityKey(entry.city, entry.code).key)) {
        console.log(`skip  ${entry.city} — already published by another script`);
        continue;
      }
      await client.query(
        `INSERT INTO home_cards (id, "sectionId", "cardType", content, "order", "isVisible", status)
         VALUES ($1,$2,'destination',$3::jsonb,$4,true,'published')
         ON CONFLICT (id) DO UPDATE SET
           content = EXCLUDED.content,
           "order" = EXCLUDED."order",
           "isVisible" = true,
           status = 'published'`,
        [
          uuidFor(index),
          SECTIONS.discover.id,
          json({
            title: entry.city,
            subtitle: entry.country || null,
            imageUrl: entry.photo?.imageUrl ?? null,
            metadata: {
              country: entry.country || null,
              countryCode: entry.code || null,
              staysCount: entry.count,
              ...(entry.photo
                ? {
                    imageCredit: entry.photo.imageCredit,
                    imageLicense: entry.photo.imageLicense,
                    imageSource: entry.photo.imageSource,
                  }
                : {}),
            },
          }),
          index,
        ],
      );
      index += 1;
      publishedCities += 1;
    }

    await client.query('COMMIT');
    console.log(
      `Published the real Discover section: ${publishedCities} cities.`,
    );
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Publish failed:', error.message);
    process.exitCode = 1;
  } finally {
    await client.end();
  }
})();
