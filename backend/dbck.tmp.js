require('dotenv').config();
const { Client } = require('pg');
(async () => {
  const c = new Client({ host: process.env.DB_HOST, user: process.env.DB_USER, password: process.env.DB_PASSWORD, database: process.env.DB_NAME });
  await c.connect();
  const secs = await c.query('SELECT id, title FROM home_sections ORDER BY "order"');
  for (const s of secs.rows) {
    console.log(`== ${s.title} (${s.id.slice(-4)})`);
    const cards = await c.query('SELECT "cardType", content, "order" FROM home_cards WHERE "sectionId" = $1 ORDER BY "order" ASC', [s.id]);
    for (const row of cards.rows) {
      const it = row.content || {};
      const title = it.title ?? it.name ?? it.city ?? '?';
      const meta = it.metadata ?? {};
      const moods = Array.isArray(meta?.moods) ? meta.moods.join('+') : (meta?.mood ?? '');
      console.log(`  ${String(row["order"]).padStart(2)} [${row.cardType}] ${title} ${moods ? `moods=${moods}` : ''}`);
    }
  }
  await c.end();
})();
