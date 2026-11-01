/**
 * Publishes the world's most famous tourist cities into the Discover rail
 * (owner request, 2026-10-30: "the cities shown should be the world's most
 * famous tourist destinations, with premium photos of the places themselves").
 *
 * Three rules, none negotiable:
 *
 *   1. A city is published only when the provider really returns stays for it
 *      in this run — the count on the card is the provider's own answer, and a
 *      tile that opens an empty search is a broken promise, not content.
 *   2. The cover is a real photo of the PLACE (Wikipedia/Wikidata → Commons,
 *      with the attribution its licence requires), never a hotel-room photo and
 *      never a montage/satellite/map frame. See `lib/destination-image.js`.
 *   3. Nothing is invented: no price, no rating, no "from $x" on a city tile.
 *
 * Ordering: the rows use NEGATIVE `order` values (rank 1 = the most negative =
 * first), so the world list leads the rail without rewriting the order values
 * the other seeds own (`seed-home-real.js` → 1..N,
 * `add-destination-cities.js` → 11..17). Any seed can be re-run in any sequence
 * and the rail stays stable.
 *
 * Re-running is safe: the rows have fixed ids, so a publish updates in place.
 * The photo pass at the end also repairs an already-published destination card
 * whose cover no longer passes the quality rules (Istanbul's montage collage
 * was one).
 *
 * Usage (from backend/, with the API + DB up):
 *   node scripts/seed-world-cities.js
 *   node scripts/seed-world-cities.js --photos-only   # skip the city searches
 */
const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '..', '.env') });

const { Client } = require('pg');
const { countryNameFor } = require('./lib/countries');
const { cityImageFor } = require('./lib/destination-image');
const WORLD_CITIES = require('./lib/world-cities');

const API = process.env.PUBLIC_API_URL || 'http://127.0.0.1:3000';
const DISCOVER_SECTION_ID = '00000000-0000-4000-8000-000000000002';

/** `30000000-...` is this script's own id space; no other seed uses it. */
const idFor = (rank) =>
  `30000000-0000-4000-8000-${String(rank).padStart(12, '0')}`;

const dbConfig = {
  host: process.env.DB_HOST || 'localhost',
  port: Number(process.env.DB_PORT || 5432),
  user: process.env.DB_USER || 'wetravellers',
  password: process.env.DB_PASSWORD || 'wetravellers',
  database: process.env.DB_NAME || 'wetravellers',
};

/**
 * A real, near-term window for the inventory check. One night: the card is a
 * city tile, so any bookable night proves the city has stays, and a single
 * night is the cheapest way to ask.
 */
function stayWindow() {
  const start = new Date();
  start.setUTCDate(start.getUTCDate() + 7);
  const end = new Date(start);
  end.setUTCDate(end.getUTCDate() + 1);
  return {
    checkIn: start.toISOString().slice(0, 10),
    checkOut: end.toISOString().slice(0, 10),
  };
}

/**
 * The provider's real stays for one city.
 *
 * Nuitee intermittently answers an empty list under burst traffic; retrying
 * before calling a city empty keeps a rate limit from silently unpublishing a
 * destination.
 */
async function nuiteeStays(city) {
  const { checkIn, checkOut } = stayWindow();
  for (let attempt = 0; attempt < 3; attempt += 1) {
    const response = await fetch(`${API}/search/hotels`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        city: city.search || city.name,
        country: city.countryCode,
        checkIn,
        checkOut,
        guests: 2,
      }),
    });
    if (!response.ok) {
      throw new Error(
        `/search/hotels answered ${response.status} for ${city.name}`,
      );
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

/** The card body for one city + its real stay count + its real photo. */
function cardContent(city, photo, staysCount) {
  const country = countryNameFor(city.countryCode);
  return {
    title: city.name,
    subtitle: country,
    imageUrl: photo?.imageUrl ?? null,
    metadata: {
      country,
      countryCode: city.countryCode,
      ...(city.region ? { region: city.region } : {}),
      ...(staysCount !== null ? { staysCount } : {}),
      ...(photo
        ? {
            imageCredit: photo.imageCredit,
            imageLicense: photo.imageLicense,
            imageSource: photo.imageSource,
          }
        : {}),
    },
  };
}

async function publishWorldCities(client) {
  for (const city of WORLD_CITIES) {
    const stays = await nuiteeStays(city);
    if (stays.length === 0) {
      console.log(
        `skip  ${city.name} — the provider returned no stays in the window`,
      );
      continue;
    }
    const photo = await cityImageFor(city.name, {
      wikiTitle: city.wikiTitle,
    });
    await client.query(
      `INSERT INTO home_cards (id, "sectionId", "cardType", content, "order", "isVisible", status)
       VALUES ($1,$2,'destination',$3::jsonb,$4,true,'published')
       ON CONFLICT (id) DO UPDATE SET
         content = EXCLUDED.content,
         "order" = EXCLUDED."order",
         "isVisible" = true,
         status = 'published',
         "updatedAt" = now()`,
      [
        idFor(city.rank),
        DISCOVER_SECTION_ID,
        JSON.stringify(cardContent(city, photo, stays.length)),
        // Negative, and most-famous first: the world list leads the rail
        // without touching the order values the other seeds own. The rank is
        // inverted so rank 1 is the smallest (leading) number.
        -(WORLD_CITIES.length + 1 - city.rank),
      ],
    );
    console.log(
      `ok    ${city.name.padEnd(16)} → ${String(stays.length).padStart(2)} stays · ` +
        `photo ${photo ? photo.imageFile : 'none'}`,
    );
  }
}

/**
 * Re-resolve the cover of every destination card already in the rail and update
 * the ones whose photo the resolver now judges unusable.
 *
 * This is a photo repair, not a re-publish: the title, order and count the other
 * seeds own are left exactly as they are.
 */
async function repairPhotos(client) {
  const { rows } = await client.query(
    `SELECT id, content FROM home_cards
      WHERE "sectionId" = $1 AND "cardType" = 'destination'
        AND id::text NOT LIKE '30000000%'
      ORDER BY "order" ASC`,
    [DISCOVER_SECTION_ID],
  );
  for (const row of rows) {
    const content = row.content || {};
    const title = String(content.title ?? '').trim();
    if (!title) continue;
    const photo = await cityImageFor(title);
    if (!photo) continue;
    if (photo.imageUrl === content.imageUrl) continue;

    const metadata = { ...(content.metadata || {}) };
    metadata.imageCredit = photo.imageCredit;
    metadata.imageLicense = photo.imageLicense;
    metadata.imageSource = photo.imageSource;

    await client.query(
      `UPDATE home_cards
          SET content = jsonb_set(
                jsonb_set(content, '{imageUrl}', to_jsonb($2::text)),
                '{metadata}', $3::jsonb, true
              ),
              "updatedAt" = now()
        WHERE id = $1`,
      [row.id, photo.imageUrl, JSON.stringify(metadata)],
    );
    console.log(
      `photo ${title.padEnd(16)} → ${photo.imageFile ?? photo.imageUrl}`,
    );
  }
}

(async () => {
  const photosOnly = process.argv.includes('--photos-only');
  const client = new Client(dbConfig);
  await client.connect();
  try {
    if (!photosOnly) await publishWorldCities(client);
    await repairPhotos(client);
  } finally {
    await client.end();
  }
})().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});