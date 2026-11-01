/**
 * Repairs the Discover destination cards in place (2026-10-30).
 *
 * Two problems had accumulated in the live rows:
 *
 *   1. The same city was published twice, because the recommendation feed
 *      stored the country as an ISO code ("EG") and the hand-written city list
 *      as a name ("Egypt"). Nothing deduplicated the two spellings.
 *   2. Every cover was one of the city's Nuitee hotel photos — a real photo,
 *      but of a room, not of the place the card names.
 *
 * This script groups the rows by normalised city + ISO country, merges the
 * metadata the duplicates each carried (moods union, real max stay count,
 * seasonal flag), keeps ONE canonical row, resolves the city's own
 * Wikipedia/Commons photo with its attribution, deletes the duplicates and
 * renumbers the survivors 1..N.
 *
 * Nothing is invented: a stay count is only kept when a row really carried a
 * number, and when no licensed city photo resolves the card is left WITHOUT an
 * image (the app renders its honest placeholder) instead of a hotel photo.
 *
 * Usage (from backend/):
 *   node scripts/fix-destination-cards.js --dry-run
 *   node scripts/fix-destination-cards.js
 */
const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '..', '.env') });

const { Client } = require('pg');
const { countryCodeFor, countryNameFor } = require('./lib/countries');
const { cityImageFor } = require('./lib/destination-image');

const DISCOVER_SECTION_ID = '00000000-0000-4000-8000-000000000002';
const DRY_RUN = process.argv.includes('--dry-run');

const dbConfig = {
  host: process.env.DB_HOST || 'localhost',
  port: Number(process.env.DB_PORT || 5432),
  user: process.env.DB_USER || 'wetravellers',
  password: process.env.DB_PASSWORD || 'wetravellers',
  database: process.env.DB_NAME || 'wetravellers',
};

/** " Sharm  El Sheikh " → "sharm el sheikh" (grouping key only). */
function cityKey(name) {
  return String(name ?? '')
    .trim()
    .replace(/\s+/g, ' ')
    .toLowerCase();
}

function isWikimedia(url) {
  if (typeof url !== 'string') return false;
  return /^https:\/\/(upload|thumb)\.wikimedia\.org\//.test(url);
}

/** The real stay count, or null when no row carried a number. */
function numericStays(value) {
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
}

/**
 * Which duplicate survives: the one with a real stay count first (it is the row
 * the provider actually measured), then the earliest authored order, then id so
 * the choice is deterministic across runs.
 */
function compareCanonical(a, b) {
  const aStays = numericStays(a.metadata?.staysCount);
  const bStays = numericStays(b.metadata?.staysCount);
  if (aStays !== null && bStays === null) return -1;
  if (aStays === null && bStays !== null) return 1;
  if (a.order !== b.order) return a.order - b.order;
  return String(a.id).localeCompare(String(b.id));
}

function mergeMoods(rows) {
  const seen = new Set();
  const moods = [];
  for (const row of rows) {
    const values = Array.isArray(row.metadata?.moods) ? row.metadata.moods : [];
    for (const mood of values) {
      const text = String(mood ?? '').trim();
      if (!text || seen.has(text)) continue;
      seen.add(text);
      moods.push(text);
    }
  }
  return moods;
}

async function loadCards(client) {
  const result = await client.query(
    `select id, "order" as ord, content
       from home_cards
      where "sectionId" = $1 and "cardType" = 'destination'
      order by "order", id`,
    [DISCOVER_SECTION_ID],
  );
  return result.rows.map((row) => ({
    id: row.id,
    order: Number(row.ord),
    content: row.content ?? {},
    title: String(row.content?.title ?? '').trim(),
    metadata: row.content?.metadata ?? {},
  }));
}

function groupByCity(cards) {
  const groups = new Map();
  for (const card of cards) {
    if (!card.title) {
      // A card without a city name cannot be attributed or deduplicated.
      groups.set(`__untitled__|${card.id}`, [card]);
      continue;
    }
    const countryCode = countryCodeFor(card.metadata?.country ?? card.content?.subtitle);
    const key = `${cityKey(card.title)}|${countryCode ?? String(card.metadata?.country ?? '').trim().toUpperCase()}`;
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(card);
  }
  return groups;
}

async function main() {
  const client = new Client(dbConfig);
  await client.connect();
  try {
    const cards = await loadCards(client);
    const groups = groupByCity(cards);

    const plan = [];
    for (const rows of groups.values()) {
      rows.sort(compareCanonical);
      const canonical = rows[0];
      const duplicates = rows.slice(1);
      const countryCode =
        countryCodeFor(canonical.metadata?.country ?? canonical.content?.subtitle) ??
        countryCodeFor(rows.find((row) => row.metadata?.countryCode)?.metadata?.countryCode);
      const country = countryNameFor(countryCode ?? canonical.metadata?.country) || null;

      const stays = rows
        .map((row) => numericStays(row.metadata?.staysCount))
        .filter((value) => value !== null)
        .reduce((max, value) => Math.max(max, value), 0);
      const moods = mergeMoods(rows);
      const seasonal = rows.some((row) => Boolean(row.metadata?.seasonal));

      const existingImage = canonical.content?.imageUrl;
      const photo = canonical.title ? await cityImageFor(canonical.title) : null;
      // Only keep an existing URL when it already IS a city photo. A Nuitee
      // hotel photo must never survive as the cover of a city.
      const keepExisting = photo === null && isWikimedia(existingImage);
      const imageUrl = photo?.imageUrl ?? (keepExisting ? existingImage : null);

      plan.push({
        canonical,
        duplicates,
        title: canonical.title,
        country,
        countryCode: countryCode ?? null,
        stays: stays > 0 ? stays : null,
        moods,
        seasonal,
        imageUrl,
        imageCredit:
          photo?.imageCredit ??
          (keepExisting ? canonical.metadata?.imageCredit ?? null : null),
        imageLicense:
          photo?.imageLicense ??
          (keepExisting ? canonical.metadata?.imageLicense ?? null : null),
        imageSource:
          photo?.imageSource ??
          (keepExisting ? canonical.metadata?.imageSource ?? null : null),
        photoResolved: photo !== null,
      });
    }

    plan.sort((a, b) => a.canonical.order - b.canonical.order);

    console.log(`\n${DRY_RUN ? 'DRY RUN — nothing is written' : 'Applying repair'}`);
    console.log(`${cards.length} destination cards → ${plan.length} cities\n`);

    for (const [index, entry] of plan.entries()) {
      const duplicateIds = entry.duplicates.map((row) => row.id);
      console.log(
        `${String(index + 1).padStart(2)}. ${entry.title} (${entry.countryCode ?? '?'})` +
          `  stays=${entry.stays ?? '—'}` +
          `  photo=${entry.photoResolved ? 'city' : entry.imageUrl ? 'kept' : 'NONE'}` +
          `${duplicateIds.length ? `  deletes=${duplicateIds.length}` : ''}`,
      );
      if (duplicateIds.length) {
        for (const id of duplicateIds) console.log(`      - ${id}`);
      }
      if (entry.imageCredit) {
        console.log(`      photo: ${entry.imageCredit} · ${entry.imageLicense ?? '—'}`);
      }
    }

    if (DRY_RUN) return;

    await client.query('BEGIN');
    for (const [index, entry] of plan.entries()) {
      const metadata = {
        ...entry.canonical.metadata,
        country: entry.country,
        ...(entry.countryCode ? { countryCode: entry.countryCode } : {}),
        ...(entry.stays !== null ? { staysCount: entry.stays } : {}),
        ...(entry.moods.length ? { moods: entry.moods } : {}),
        ...(entry.seasonal ? { seasonal: entry.canonical.metadata?.seasonal ?? 'winter' } : {}),
        ...(entry.imageCredit ? { imageCredit: entry.imageCredit } : {}),
        ...(entry.imageLicense ? { imageLicense: entry.imageLicense } : {}),
        ...(entry.imageSource ? { imageSource: entry.imageSource } : {}),
      };
      if (entry.stays === null) delete metadata.staysCount;
      if (entry.moods.length === 0) delete metadata.moods;
      if (!entry.seasonal) delete metadata.seasonal;
      if (!entry.imageUrl) {
        delete metadata.imageCredit;
        delete metadata.imageLicense;
        delete metadata.imageSource;
      }

      await client.query(
        `update home_cards
            set content = $2::jsonb, "order" = $3, "isVisible" = true, status = 'published'
          where id = $1`,
        [
          entry.canonical.id,
          JSON.stringify({
            ...entry.canonical.content,
            title: entry.title,
            subtitle: entry.country,
            imageUrl: entry.imageUrl,
            metadata,
          }),
          index + 1,
        ],
      );

      if (entry.duplicates.length) {
        await client.query(
          `delete from home_cards where id = any($1::uuid[])`,
          [entry.duplicates.map((row) => row.id)],
        );
      }
    }
    await client.query('COMMIT');

    const withoutPhoto = plan.filter((entry) => !entry.imageUrl).length;
    console.log(
      `\nDone: ${plan.length} cities, ${cards.length - plan.length} duplicates removed, ` +
        `${withoutPhoto} without a licensed city photo.`,
    );
  } catch (error) {
    await client.query('ROLLBACK').catch(() => undefined);
    console.error('Repair failed:', error.message);
    process.exitCode = 1;
  } finally {
    await client.end();
  }
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
