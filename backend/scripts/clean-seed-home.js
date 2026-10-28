/**
 * Removes the dev seed's footprint from the home feed.
 *
 * The seed (`seed-home.js`) writes four demo sections and ten demo cards with
 * FIXED UUIDs and upserts them. That means: a section the owner deleted in the
 * admin comes straight back the next time anyone runs the seed. This script is
 * the way back: it deletes exactly the rows the seed owns — by their fixed
 * UUIDs — and touches nothing else in the tables.
 *
 * Run:  npm run seed:home:clean     (from backend/)
 */
const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '..', '.env') });

const { Client } = require('pg');

const dbConfig = {
  host: process.env.DB_HOST || 'localhost',
  port: Number(process.env.DB_PORT || 5432),
  user: process.env.DB_USER || 'wetravellers',
  password: process.env.DB_PASSWORD || 'wetravellers',
  database: process.env.DB_NAME || 'wetravellers',
};

const SEED_SECTION_IDS = [
  '00000000-0000-4000-8000-000000000001',
  '00000000-0000-4000-8000-000000000002',
  '00000000-0000-4000-8000-000000000003',
  '00000000-0000-4000-8000-000000000004',
];

(async () => {
  const client = new Client(dbConfig);
  await client.connect();
  try {
    await client.query('BEGIN');
    const cards = await client.query(
      'DELETE FROM home_cards WHERE "sectionId" = ANY($1::varchar[]) RETURNING id',
      [SEED_SECTION_IDS],
    );
    const sections = await client.query(
      'DELETE FROM home_sections WHERE id = ANY($1::uuid[]) RETURNING title',
      [SEED_SECTION_IDS],
    );
    await client.query('COMMIT');
    console.log(
      `Removed ${sections.rows.length} seeded sections and ${cards.rows.length} seeded cards.`,
    );
    for (const row of sections.rows) console.log(`  - ${row.title}`);
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Clean failed:', error.message);
    process.exitCode = 1;
  } finally {
    await client.end();
  }
})();
