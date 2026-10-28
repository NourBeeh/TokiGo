/**
 * Dev seed for the admin workstream (ADM-A1).
 *
 * Creates (or promotes) one admin user so the /admin/* endpoints are
 * reachable during development. Idempotent: re-runs upsert in place.
 *
 *  - Email:  ADMIN_EMAIL  (default admin@tokigo.app)
 *  - Password: ADMIN_PASSWORD (default admin1234 — DEV ONLY, never reuse in
 *    production; production accounts must rotate it on first login).
 *
 * Run:  npm run seed:admin     (from backend/)
 *
 * Tables must already exist — start the backend once first (TypeORM
 * synchronize creates them in non-production environments).
 */
const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '..', '.env') });

const bcrypt = require('bcryptjs');
const { Client } = require('pg');

const dbConfig = {
  host: process.env.DB_HOST || 'localhost',
  port: Number(process.env.DB_PORT || 5432),
  user: process.env.DB_USER || 'wetravellers',
  password: process.env.DB_PASSWORD || 'wetravellers',
  database: process.env.DB_NAME || 'wetravellers',
};

const ADMIN_EMAIL = (process.env.ADMIN_EMAIL || 'admin@tokigo.app').toLowerCase();
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'admin1234';
const ADMIN_NAME = process.env.ADMIN_NAME || 'TokiGo Admin';

async function main() {
  const passwordHash = await bcrypt.hash(ADMIN_PASSWORD, 10);
  const client = new Client(dbConfig);
  await client.connect();
  try {
    await client.query(
      // Column names are camelCase: the project does not configure a
      // snake_case naming strategy, so TypeORM persists `displayName`,
      // `passwordHash` and `isActive` verbatim.
      `INSERT INTO users (email, "displayName", "passwordHash", "isActive", role)
       VALUES ($1, $2, $3, true, 'admin')
       ON CONFLICT (email) DO UPDATE
         SET role = 'admin',
             "isActive" = true,
             "passwordHash" = EXCLUDED."passwordHash",
             "displayName" = EXCLUDED."displayName"`,
      [ADMIN_EMAIL, ADMIN_NAME, passwordHash],
    );
    console.log(`Admin user ready: ${ADMIN_EMAIL} (role=admin)`);
  } finally {
    await client.end();
  }
}

main().catch((error) => {
  console.error('Admin seed failed:', error.message);
  process.exit(1);
});
