#!/usr/bin/env node
/**
 * Ad-hoc SQL against the TokiGo vulnerability database.
 *
 *   node tool/vuln/query.mjs "SELECT severity, COUNT(*) n FROM vulns GROUP BY severity"
 *   node tool/vuln/query.mjs --json "SELECT * FROM vulns WHERE kev = 1 LIMIT 5"
 */
import { openDb } from "./lib/db.mjs";

const argv = process.argv.slice(2);
const asJson = argv.includes("--json");
const sql = argv.filter((a) => a !== "--json").join(" ");
if (!sql) {
  console.error('usage: node tool/vuln/query.mjs [--json] "SELECT ..."');
  process.exit(1);
}

const db = openDb(true);
const rows = db.prepare(sql).all();

if (asJson) {
  console.log(JSON.stringify(rows, null, 2));
} else if (!rows.length) {
  console.log("(no rows)");
} else {
  const cols = Object.keys(rows[0]);
  const widths = cols.map((c) =>
    Math.max(c.length, ...rows.map((r) => String(r[c] ?? "").length))
  );
  const line = (cells) => cells.map((c, i) => String(c ?? "").padEnd(widths[i])).join("  ");
  console.log(line(cols));
  console.log(widths.map((w) => "-".repeat(w)).join("  "));
  for (const r of rows) console.log(line(cols.map((c) => r[c])));
}
db.close();
