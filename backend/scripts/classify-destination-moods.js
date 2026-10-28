/**
 * Mood taxonomy for the published destination cards (2026-10-22).
 *
 * Owner decision: the Home "Cities for your mood" rail and the Explore city
 * list are driven by an AUTHORED taxonomy, never by words in a city's name.
 * The vocabulary is the app's TravelMood enum:
 *
 *   shopping | beach | snow | nature | city
 *
 * The script is idempotent: it merges `metadata.moods` into the existing
 * `content` jsonb of every matching destination card and never touches any
 * other key (country, staysCount, image, …).
 *
 * Usage (from backend/):  node scripts/classify-destination-moods.js
 */
require('dotenv').config();
const { Client } = require('pg');

const MOODS_BY_CITY = {
  Cairo: ['city'],
  Dubai: ['shopping', 'city'],
  Riyadh: ['city'],
  Jeddah: ['city'],
  Hurghada: ['beach'],
  'Sharm El Sheikh': ['beach'],
  Luxor: ['city'],
  Aswan: ['nature'],
  Alexandria: ['beach'],
  Istanbul: ['city', 'shopping'],
  // Added with the mood-content pass (2026-10-22) — real Nuitee inventory.
  Dahab: ['nature', 'beach'],
  Nuweiba: ['nature', 'beach'],
  'Marsa Alam': ['nature', 'beach'],
  // Snow destinations — real winter inventory (February window).
  Gudauri: ['snow'],
  Shahdag: ['snow'],
  Innsbruck: ['snow'],
  Rovaniemi: ['snow'],
};

const dbConfig = {
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
};

async function main() {
  const client = new Client(dbConfig);
  await client.connect();
  try {
    for (const [title, moods] of Object.entries(MOODS_BY_CITY)) {
      const { rowCount, rows } = await client.query(
        `update home_cards
            set content = jsonb_set(
                  content,
                  '{metadata}',
                  coalesce(content->'metadata', '{}'::jsonb)
                    || jsonb_build_object('moods', $2::jsonb),
                  true
                )
          where "cardType" = 'destination'
            and content->>'title' = $1
            and content->'metadata'->'moods' is distinct from $2::jsonb
          returning content->'metadata' as metadata`,
        [title, JSON.stringify(moods)],
      );
      if (rowCount === 0) {
        const existing = await client.query(
          `select content->'metadata'->'moods' as moods
             from home_cards
            where "cardType" = 'destination'
              and content->>'title' = $1
            limit 1`,
          [title],
        );
        if (existing.rowCount === 0) {
          console.log(`skip  ${title} — no destination card with that title`);
        } else {
          console.log(`same  ${title} → ${JSON.stringify(existing.rows[0].moods)}`);
        }
      } else {
        console.log(`ok    ${title} → ${JSON.stringify(rows[0].metadata)}`);
      }
    }

    const { rows: publishedCities } = await client.query(
      `select content->>'title' as title,
              content->'metadata'->'moods' as moods
         from home_cards
        where "cardType" = 'destination'
          and "isVisible" = true
          and status = 'published'
          and ("publishAt" is null or "publishAt" <= now())
          and ("expiresAt" is null or "expiresAt" > now())`,
    );
    const counts = Object.fromEntries(
      ['shopping', 'beach', 'snow', 'nature', 'city'].map((mood) => [mood, 0]),
    );
    for (const city of publishedCities) {
      if (!Array.isArray(city.moods)) continue;
      for (const mood of new Set(city.moods)) {
        if (Object.hasOwn(counts, mood)) counts[mood] += 1;
      }
    }
    console.log(`published destination counts: ${JSON.stringify(counts)}`);
    const deficientMoods = Object.entries(counts)
      .filter(([, count]) => count < 2)
      .map(([mood]) => mood);
    if (deficientMoods.length > 0) {
      console.error(
        `Insufficient published destination cities for: ${deficientMoods.join(', ')}`,
      );
      process.exitCode = 1;
    }
  } finally {
    await client.end();
  }
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
