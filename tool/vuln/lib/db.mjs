import fs from "node:fs";
import path from "node:path";
import { DatabaseSync } from "node:sqlite";
import { DB_PATH, DATA_DIR } from "./config.mjs";

export const SCHEMA = `
PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS meta (
  key   TEXT PRIMARY KEY,
  value TEXT
);

CREATE TABLE IF NOT EXISTS assets (
  id          INTEGER PRIMARY KEY,
  kind        TEXT NOT NULL,          -- pub | npm | maven | android-platform
  ecosystem   TEXT NOT NULL,          -- Pub | npm | Maven | Android
  name        TEXT NOT NULL,
  version     TEXT,
  scope       TEXT NOT NULL,          -- direct | transitive | platform | build
  channel     TEXT,                   -- prod | dev (npm/pub/maven build separation)
  source_file TEXT,
  UNIQUE (kind, name, version, scope, channel)
);

CREATE TABLE IF NOT EXISTS vulns (
  id          TEXT PRIMARY KEY,       -- CVE-... | GHSA-... | ASB-...
  source      TEXT NOT NULL,          -- nvd | osv | kev
  aliases     TEXT,                   -- JSON array
  summary     TEXT,
  details     TEXT,
  published   TEXT,
  modified    TEXT,
  cvss_score  REAL,
  cvss_vector TEXT,
  severity    TEXT NOT NULL DEFAULT 'unknown',
  cwe         TEXT,                   -- JSON array
  kev         INTEGER NOT NULL DEFAULT 0,
  kev_added   TEXT,
  kev_due     TEXT,
  kev_ransomware TEXT,
  refs        TEXT,                   -- JSON array
  fetched_at  TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS vuln_assets (
  vuln_id      TEXT NOT NULL REFERENCES vulns(id) ON DELETE CASCADE,
  asset_id     INTEGER NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
  match_type   TEXT NOT NULL,         -- exact | range | platform-os | platform-generic
  reachability TEXT NOT NULL,         -- direct | transitive | platform | platform-unconfirmed
  fixed        TEXT,                  -- first fixed version when the feed exposes one
  PRIMARY KEY (vuln_id, asset_id)
);

CREATE TABLE IF NOT EXISTS sync_state (
  source       TEXT PRIMARY KEY,
  last_success TEXT,
  cursor       TEXT,
  total        INTEGER,
  note         TEXT
);

CREATE TABLE IF NOT EXISTS snapshots (
  id          INTEGER PRIMARY KEY,
  created_at  TEXT NOT NULL,
  critical    INTEGER NOT NULL,
  high        INTEGER NOT NULL,
  medium      INTEGER NOT NULL,
  low         INTEGER NOT NULL,
  kev         INTEGER NOT NULL,
  reachable   INTEGER NOT NULL,
  payload     TEXT
);

CREATE INDEX IF NOT EXISTS idx_vulns_sev ON vulns(severity);
CREATE INDEX IF NOT EXISTS idx_vulns_kev ON vulns(kev);
CREATE INDEX IF NOT EXISTS idx_va_reach ON vuln_assets(reachability);
`;

export function openDb(readonly = false) {
  fs.mkdirSync(DATA_DIR, { recursive: true });
  const db = new DatabaseSync(DB_PATH, { readOnly: readonly });
  if (!readonly) {
    db.exec(SCHEMA);
    migrate(db);
  }
  return db;
}

function migrate(db) {
  const cols = db.prepare("PRAGMA table_info(assets)").all();
  if (cols.some((c) => c.name === "channel")) return;

  db.exec("PRAGMA foreign_keys = OFF");
  db.exec(`
    ALTER TABLE assets RENAME TO assets_pre_channel;
    CREATE TABLE assets (
      id          INTEGER PRIMARY KEY,
      kind        TEXT NOT NULL,
      ecosystem   TEXT NOT NULL,
      name        TEXT NOT NULL,
      version     TEXT,
      scope       TEXT NOT NULL,
      channel     TEXT,
      source_file TEXT,
      UNIQUE (kind, name, version, scope, channel)
    );
    INSERT INTO assets(id, kind, ecosystem, name, version, scope, channel, source_file)
    SELECT id, kind, ecosystem, name, version, scope,
           CASE WHEN kind = 'maven' THEN 'dev' ELSE 'prod' END,
           source_file
    FROM assets_pre_channel;
    DROP TABLE assets_pre_channel;
  `);
  db.exec("PRAGMA foreign_keys = ON");
}

export function nowIso() {
  return new Date().toISOString();
}

export function getMeta(db, key, fallback = null) {
  const row = db.prepare("SELECT value FROM meta WHERE key = ?").get(key);
  return row ? row.value : fallback;
}

export function setMeta(db, key, value) {
  db.prepare(
    "INSERT INTO meta(key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value"
  ).run(key, String(value));
}

export function upsertAsset(db, asset) {
  db.prepare(
    `INSERT INTO assets (kind, ecosystem, name, version, scope, channel, source_file)
     VALUES (?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT (kind, name, version, scope, channel) DO UPDATE SET
       ecosystem = excluded.ecosystem,
       source_file = excluded.source_file`
  ).run(
    asset.kind,
    asset.ecosystem,
    asset.name,
    asset.version ?? null,
    asset.scope,
    asset.channel ?? null,
    asset.sourceFile ?? null
  );
  return db
    .prepare(
      "SELECT id FROM assets WHERE kind = ? AND name = ? AND version IS ? AND scope = ? AND channel IS ?"
    )
    .get(asset.kind, asset.name, asset.version ?? null, asset.scope, asset.channel ?? null).id;
}

export function upsertVuln(db, v) {
  db.prepare(
    `INSERT INTO vulns (
       id, source, aliases, summary, details, published, modified,
       cvss_score, cvss_vector, severity, cwe, kev, kev_added, kev_due,
       kev_ransomware, refs, fetched_at
     ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT (id) DO UPDATE SET
       aliases        = COALESCE(excluded.aliases, vulns.aliases),
       summary        = COALESCE(excluded.summary, vulns.summary),
       details        = COALESCE(excluded.details, vulns.details),
       published      = COALESCE(excluded.published, vulns.published),
       modified       = COALESCE(excluded.modified, vulns.modified),
       cvss_score     = COALESCE(excluded.cvss_score, vulns.cvss_score),
       cvss_vector    = COALESCE(excluded.cvss_vector, vulns.cvss_vector),
       severity       = CASE
                          WHEN excluded.severity = 'unknown' THEN vulns.severity
                          ELSE excluded.severity
                        END,
       cwe            = COALESCE(excluded.cwe, vulns.cwe),
       kev            = MAX(vulns.kev, excluded.kev),
       kev_added      = COALESCE(excluded.kev_added, vulns.kev_added),
       kev_due        = COALESCE(excluded.kev_due, vulns.kev_due),
       kev_ransomware = COALESCE(excluded.kev_ransomware, vulns.kev_ransomware),
       refs           = COALESCE(excluded.refs, vulns.refs),
       fetched_at     = excluded.fetched_at`
  ).run(
    v.id,
    v.source,
    json(v.aliases),
    v.summary ?? null,
    v.details ?? null,
    v.published ?? null,
    v.modified ?? null,
    v.cvssScore ?? null,
    v.cvssVector ?? null,
    v.severity ?? "unknown",
    json(v.cwe),
    v.kev ? 1 : 0,
    v.kevAdded ?? null,
    v.kevDue ?? null,
    v.kevRansomware ?? null,
    json(v.refs),
    v.fetchedAt ?? nowIso()
  );
}

export function linkVulnAsset(db, vulnId, assetId, link) {
  db.prepare(
    `INSERT INTO vuln_assets (vuln_id, asset_id, match_type, reachability, fixed)
     VALUES (?, ?, ?, ?, ?)
     ON CONFLICT (vuln_id, asset_id) DO UPDATE SET
       match_type   = excluded.match_type,
       reachability = excluded.reachability,
       fixed        = COALESCE(excluded.fixed, vuln_assets.fixed)`
  ).run(
    vulnId,
    assetId,
    link.matchType ?? "exact",
    link.reachability ?? "direct",
    link.fixed ?? null
  );
}

export function setSyncState(db, source, { lastSuccess, cursor, total, note }) {
  db.prepare(
    `INSERT INTO sync_state (source, last_success, cursor, total, note)
     VALUES (?, ?, ?, ?, ?)
     ON CONFLICT (source) DO UPDATE SET
       last_success = COALESCE(excluded.last_success, sync_state.last_success),
       cursor       = COALESCE(excluded.cursor, sync_state.cursor),
       total        = COALESCE(excluded.total, sync_state.total),
       note         = COALESCE(excluded.note, sync_state.note)`
  ).run(source, lastSuccess ?? null, cursor ?? null, total ?? null, note ?? null);
}

export function getSyncState(db, source) {
  return db.prepare("SELECT * FROM sync_state WHERE source = ?").get(source) ?? null;
}

function json(v) {
  if (v == null) return null;
  if (typeof v === "string") return v;
  return JSON.stringify(v);
}

export function ensureDir(p) {
  fs.mkdirSync(path.dirname(p), { recursive: true });
}
