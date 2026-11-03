/**
 * Publishes TWO real home sections from the provider's own live data.
 *
 *   1. "Hotels recommended for you" — the stays `/home/recommended` really
 *      returns (card A: photo, rating, price, all the provider's own numbers).
 *   2. "Discover" — the cities those stays are in (card D: the small city
 *      tile), with the city's own Wikipedia/Commons photo (a hotel room photo
 *      is not a photo of the place the card names).
 *
 * Nothing here is invented: every title, price, rating and count comes from the
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

const dbConfig = {
  host: process.env.DB_HOST || 'localhost',
  port: Number(process.env.DB_PORT || 5432),
  user: process.env.DB_USER || 'wetravellers',
  password: process.env.DB_PASSWORD || 'wetravellers',
  database: process.env.DB_NAME || 'wetravellers',
};

const API = process.env.PUBLIC_API_URL || 'http://127.0.0.1:3000';

const SECTIONS = {
  stays: {
    id: '00000000-0000-4000-8000-000000000001',
    title: 'Hotels recommended for you',
    subtitle: 'Hand-picked stays, live from the provider',
    layout: 'horizontalPeek',
    order: 1,
  },
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
const uuidFor = (section, index) =>
  `${section === 'stays' ? '10000000' : '20000000'}-0000-4000-8000-${String(
    section === 'stays' ? index : 100 + index,
  ).padStart(12, '0')}`;

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

async function fetchStays() {
  const response = await fetch(`${API}/home/recommended?limit=12`);
  if (!response.ok) {
    throw new Error(`The API answered ${response.status} for /home/recommended`);
  }
  const payload = await response.json();
  const hotels = Array.isArray(payload?.hotels) ? payload.hotels : [];
  return hotels;
}

(async () => {
  const stays = await fetchStays();
  if (stays.length === 0) {
    console.error(
      'The provider returned no stays — nothing was published. ' +
        'Start the backend and check that the hotel provider is live.',
    );
    process.exitCode = 1;
    return;
  }

  // The cities the provider really has stays in: the recommended feed first,
  // then the app's own destination list (a city with no stays is not
  // published — the tile would be an empty promise).
  //
  // The feed answers with ISO codes ("EG") and the list above with names
  // ("Egypt"); both resolve to ONE key, otherwise the same city would be
  // published twice under two country spellings.
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

  for (const stay of stays) {
    const city = (
      stay.city ||
      (stay.subtitle ? String(stay.subtitle).split(' · ')[0] : '') ||
      ''
    ).trim();
    if (!city) continue;
    // The recommended feed carries no country; the app's own destination list
    // does — so the two never publish the same city twice.
    const known = CITIES.find((c) => c.name.toLowerCase() === city.toLowerCase());
    const country = (stay.country || '').trim() || (known ? known.country : '');
    remember(city, country);
  }

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
      'DELETE FROM home_cards WHERE "sectionId" = $1',
      [SECTIONS.stays.id],
    );
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
        SECTIONS.stays.id,
        SECTIONS.stays.title,
        SECTIONS.stays.subtitle,
        SECTIONS.stays.layout,
        SECTIONS.stays.order,
      ],
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

    // The stays (card A).
    let index = 1;
    for (const stay of stays) {
      await client.query(
        `INSERT INTO home_cards (id, "sectionId", "cardType", content, "order", "isVisible", status)
         VALUES ($1,$2,'hotel',$3::jsonb,$4,true,'published')
         ON CONFLICT (id) DO UPDATE SET
           content = EXCLUDED.content,
           "order" = EXCLUDED."order",
           "isVisible" = true,
           status = 'published'`,
        [
          uuidFor('stays', index),
          SECTIONS.stays.id,
          JSON.stringify({
            title: stay.title || stay.name || '',
            // The provider's own line ("Cairo · 4.8★") — nothing rewritten.
            subtitle: stay.subtitle || null,
            imageUrl: stay.imageUrl || null,
            price: stay.price ?? null,
            currency: stay.currency || null,
            rating: stay.rating ?? null,
            reviewCount: stay.reviewCount ?? null,
            metadata: {
              city: stay.city || null,
              country: stay.country || null,
              // `/home/recommended` nests the provider provenance under
              // `metadata`; the card needs it to open the rate it shows.
              providerId: stay.metadata?.providerId ?? null,
              providerName: stay.metadata?.providerName ?? null,
              // The rate's own window and nightly figure. `/home/recommended`
              // prices ONE night (the cheapest the current month still sells),
              // so `price` and `pricePerNight` agree — and the card opens the
              // details page for the exact night it shows instead of guessing
              // dates or falling back to a fresh city search.
              checkIn: stay.checkIn || null,
              checkOut: stay.checkOut || null,
              pricePerNight: stay.pricePerNight ?? stay.price ?? null,
              providerRateId: stay.metadata?.providerRateId ?? null,
              providerOfferId: stay.metadata?.providerOfferId ?? null,
              providerHotelId: stay.metadata?.providerHotelId ?? null,
              // These ARE the recommended stays, so the Home must not also
              // render its standalone list of the same stays.
              semanticId: 'picked-for-you',
            },
          }),
          index,
        ],
      );
      index += 1;
    }

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
          uuidFor('discover', index),
          SECTIONS.discover.id,
          JSON.stringify({
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
      `Published 2 real sections: ${stays.length} stays and ${publishedCities} cities.`,
    );
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Publish failed:', error.message);
    process.exitCode = 1;
  } finally {
    await client.end();
  }
})();
