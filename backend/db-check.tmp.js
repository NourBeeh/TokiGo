
require('dotenv').config();
const { Client } = require('pg');
(async () => {
  const c = new Client({ host: process.env.DB_HOST, user: process.env.DB_USER, password: process.env.DB_PASSWORD, database: process.env.DB_NAME });
  await c.connect();
  const sec = await c.query('SELECT id, title FROM home_sections ORDER BY "order" ASC');
  console.log('Sections:', sec.rows.length, sec.rows.map(r => r.title));
  const cards = await c.query('SELECT COUNT(*) as c FROM home_cards');
  console.log('Total cards:', cards.rows[0].c);
  await c.end();
})();
