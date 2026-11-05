#!/usr/bin/env node
/**
 * TokiGo vulnerability database collector.
 *
 * Sources
 *   - NVD 2.0            : every CVE whose CPE targets the Android OS platform
 *   - OSV.dev            : advisories for the exact package versions TokiGo ships
 *   - CISA KEV           : known-exploited-in-the-wild flag
 *
 * Usage
 *   node tool/vuln/collect.mjs                # incremental (full on first run)
 *   node tool/vuln/collect.mjs --full         # re-download everything
 *   node tool/vuln/collect.mjs --since 2019-01-01
 *   node tool/vuln/collect.mjs --skip-nvd     # dependency-only refresh (fast)
 */
import { ANDROID_MIN_API, ANDROID_TARGET_API } from "./lib/config.mjs";
import { collectAssets } from "./lib/assets.mjs";
import {
  getSyncState,
  linkVulnAsset,
  nowIso,
  openDb,
  setSyncState,
  upsertAsset,
  upsertVuln,
} from "./lib/db.mjs";
import { androidImpact, fixedVersionFor, normalizeNvd, normalizeOsv } from "./lib/classify.mjs";
import { cisaKev, fetchJson, nvdByCve, osvQueryBatch, osvVuln } from "./lib/sources.mjs";

const args = process.argv.slice(2);
const has = (flag) => args.includes(flag);
const valueOf = (flag, fallback = null) => {
  const i = args.indexOf(flag);
  return i >= 0 && args[i + 1] ? args[i + 1] : fallback;
};

const FULL = has("--full");
const SKIP_NVD = has("--skip-nvd");
const SKIP_OSV = has("--skip-osv");
const SINCE = valueOf("--since");
const fetchedAt = nowIso();

const log = (...a) => console.log(`[${new Date().toISOString().slice(11, 19)}]`, ...a);
const db = openDb();

const safeParse = (v) => {
  if (!v) return null;
  try {
    return JSON.parse(v);
  } catch {
    return null;
  }
};

/* ------------------------------------------------------------- assets ----- */

function syncAssets() {
  const assets = collectAssets();
  const ids = new Map();
  db.exec("BEGIN");
  try {
    for (const a of assets) {
      const id = upsertAsset(db, a);
      ids.set(`${a.kind}|${a.name}|${a.version}`, id);
    }
    db.exec("COMMIT");
  } catch (e) {
    db.exec("ROLLBACK");
    throw e;
  }
  log(`assets: ${assets.length} components (pub/npm/maven/build)`);

  // One synthetic asset per Android API level TokiGo supports.
  const platformIds = new Map();
  db.exec("BEGIN");
  try {
    for (let api = ANDROID_MIN_API; api <= ANDROID_TARGET_API; api++) {
      const id = upsertAsset(db, {
        kind: "android-platform",
        ecosystem: "Android",
        name: "android-os",
        version: String(api),
        scope: "platform",
        channel: "prod",
        sourceFile: "app minSdk/targetSdk",
      });
      platformIds.set(api, id);
    }
    db.exec("COMMIT");
  } catch (e) {
    db.exec("ROLLBACK");
    throw e;
  }
  log(`android platform: API ${ANDROID_MIN_API}..${ANDROID_TARGET_API}`);
  return { assets, platformIds };
}

/* ---------------------------------------------------------------- NVD ----- */

async function syncNvd(platformIds) {
  const state = getSyncState(db, "nvd");
  const incremental = !FULL && state?.last_success;

  let lastModStart = null;
  let lastModEnd = null;
  if (incremental) {
    // Re-read a 2-day overlap so late modifications are never missed.
    const from = new Date(new Date(state.last_success).getTime() - 2 * 86400_000);
    lastModStart = from.toISOString().slice(0, 19) + ".000";
    lastModEnd = new Date().toISOString().slice(0, 19) + ".000";
  }

  const params = new URLSearchParams({
    virtualMatchString: "cpe:2.3:o:google:android",
    resultsPerPage: "2000",
  });
  if (lastModStart) {
    params.set("lastModStartDate", lastModStart);
    params.set("lastModEndDate", lastModEnd);
  }
  if (SINCE && !incremental) params.set("pubStartDate", `${SINCE}T00:00:00.000`);

  const url = `https://services.nvd.nist.gov/rest/json/cves/2.0?${params}`;
  log(`nvd: ${incremental ? `incremental since ${lastModStart}` : "FULL sync"}${SINCE ? ` (published >= ${SINCE})` : ""}`);

  let total = 0;
  let inserted = 0;
  let reachable = 0;
  let startIndex = 0;
  const key = process.env.NVD_API_KEY;
  const gap = key ? 700 : 6500;

  while (true) {
    const pageUrl = `${url}&startIndex=${startIndex}`;
    const data = await fetchJson(pageUrl, { headers: key ? { apiKey: key } : {}, retries: 3 });

    total = data.totalResults ?? 0;
    const vulns = data.vulnerabilities ?? [];

    db.exec("BEGIN");
    try {
      for (const { cve } of vulns) {
        const normalized = normalizeNvd(cve, fetchedAt);
        upsertVuln(db, normalized);
        inserted++;

        const impact = androidImpact(cve);
        if (!impact?.reachable) continue;

        reachable++;
        const allApis = impact.generic && !impact.constrained;
        const from = allApis ? ANDROID_MIN_API : Math.max(ANDROID_MIN_API, impact.minApi ?? ANDROID_MIN_API);
        const to = allApis
          ? ANDROID_TARGET_API
          : Math.min(ANDROID_TARGET_API, impact.maxApi ?? ANDROID_TARGET_API);
        for (let api = from; api <= to; api++) {
          linkVulnAsset(db, normalized.id, platformIds.get(api), {
            matchType: impact.matchType,
            reachability: impact.reachability,
          });
        }
      }
      db.exec("COMMIT");
    } catch (e) {
      db.exec("ROLLBACK");
      throw e;
    }

    startIndex += 2000;
    log(`nvd: ${Math.min(startIndex, total)}/${total} (reachable on API ${ANDROID_MIN_API}-${ANDROID_TARGET_API}: ${reachable})`);
    if (startIndex >= total) break;
    await new Promise((r) => setTimeout(r, gap));
  }

  const totalVulns = db.prepare("SELECT COUNT(*) n FROM vulns").get().n;
  setSyncState(db, "nvd", {
    lastSuccess: fetchedAt,
    cursor: lastModStart ?? "full",
    total: totalVulns,
    note: incremental
      ? `+${total} modified since ${state.last_success?.slice(0, 10)}; full catalogue ${totalVulns}`
      : `full download; ${totalVulns} CVEs in DB (${reachable} inside API ${ANDROID_MIN_API}-${ANDROID_TARGET_API})`,
  });
}

/* ---------------------------------------------------------------- OSV ----- */

async function syncOsv(assets, assetIds) {
  const queryable = assets.filter(
    (a) => ["pub", "npm", "maven"].includes(a.kind) && a.version
  );
  if (!queryable.length) return;

  log(`osv: querying ${queryable.length} pinned components`);
  const queries = queryable.map((a) => ({
    package: { name: a.name, ecosystem: a.ecosystem },
    version: a.version,
  }));

  const results = await osvQueryBatch(queries);
  const hits = [];
  results.forEach((res, i) => {
    for (const v of res?.vulns ?? []) hits.push({ asset: queryable[i], vulnId: v.id });
  });
  log(`osv: ${hits.length} package/vulnerability hits`);

  const uniqueIds = [...new Set(hits.map((h) => h.vulnId))];
  const details = new Map();
  const CONCURRENCY = 6;
  for (let i = 0; i < uniqueIds.length; i += CONCURRENCY) {
    const chunk = uniqueIds.slice(i, i + CONCURRENCY);
    const settled = await Promise.allSettled(chunk.map((id) => osvVuln(id)));
    settled.forEach((s, j) => {
      if (s.status === "fulfilled") details.set(chunk[j], s.value);
    });
  }

  db.exec("BEGIN");
  try {
    for (const hit of hits) {
      const vuln = details.get(hit.vulnId);
      if (!vuln) continue;
      const normalized = normalizeOsv(vuln, fetchedAt);
      upsertVuln(db, normalized);
      const assetId = assetIds.get(
        `${hit.asset.kind}|${hit.asset.name}|${hit.asset.version}|${hit.asset.scope}|${hit.asset.channel ?? ""}`
      );
      if (!assetId) continue;
      linkVulnAsset(db, normalized.id, assetId, {
        matchType: "range",
        reachability: hit.asset.scope === "direct" ? "direct" : "transitive",
        fixed: fixedVersionFor(vuln, hit.asset.name, hit.asset.version),
      });
    }
    db.exec("COMMIT");
  } catch (e) {
    db.exec("ROLLBACK");
    throw e;
  }

  setSyncState(db, "osv", {
    lastSuccess: fetchedAt,
    total: uniqueIds.length,
    note: `${queryable.length} components queried; ${hits.length} package/advisory hits; ${uniqueIds.length} unique advisories`,
  });
}

/* ---------------------------------------------------------------- KEV ----- */

async function syncKev(platformIds) {
  log("kev: downloading CISA known-exploited catalog");
  const feed = await cisaKev();
  const entries = feed.vulnerabilities ?? [];
  log(`kev: catalog ${feed.catalogVersion ?? "?"} (${entries.length} entries)`);

  const byCve = new Map(entries.map((e) => [e.cveID, e]));

  const rows = db.prepare("SELECT id, aliases, severity, cvss_score FROM vulns").all();
  db.exec("BEGIN");
  try {
    for (const row of rows) {
      const aliases = safeParse(row.aliases) ?? [];
      const match = byCve.get(row.id) ?? aliases.map((a) => byCve.get(a)).find(Boolean);
      if (!match) continue;
      db.prepare(
        `UPDATE vulns SET kev = 1, kev_added = ?, kev_due = ?, kev_ransomware = ? WHERE id = ?`
      ).run(match.dateAdded ?? null, match.dueDate ?? null, match.knownRansomwareCampaignUse ?? null, row.id);
    }
    db.exec("COMMIT");
  } catch (e) {
    db.exec("ROLLBACK");
    throw e;
  }

  // KEV entries that are Android-platform relevant but absent from NVD's CPE set.
  const androidKev = entries.filter(
    (e) => /android/i.test(`${e.vendorProject} ${e.product} ${e.vulnerabilityName}`) && !db.prepare("SELECT 1 FROM vulns WHERE id = ?").get(e.cveID)
  );
  let added = 0;
  for (const e of androidKev.slice(0, 40)) {
    try {
      const cve = await nvdByCve(e.cveID);
      if (!cve) continue;
      const normalized = normalizeNvd(cve, fetchedAt);
      normalized.kev = true;
      normalized.kevAdded = e.dateAdded;
      normalized.kevDue = e.dueDate;
      normalized.kevRansomware = e.knownRansomwareCampaignUse;
      upsertVuln(db, normalized);
      const impact = androidImpact(cve);
      if (impact?.reachable) {
        const allApis = impact.generic && !impact.constrained;
        const from = allApis ? ANDROID_MIN_API : Math.max(ANDROID_MIN_API, impact.minApi ?? ANDROID_MIN_API);
        const to = allApis
          ? ANDROID_TARGET_API
          : Math.min(ANDROID_TARGET_API, impact.maxApi ?? ANDROID_TARGET_API);
        for (let api = from; api <= to; api++) {
          linkVulnAsset(db, normalized.id, platformIds.get(api), {
            matchType: impact.matchType,
            reachability: impact.reachability,
          });
        }
      }
      added++;
    } catch {
      /* best effort */
    }
  }
  log(`kev: flagged existing rows; added ${added} Android KEV-only CVEs`);

  setSyncState(db, "kev", {
    lastSuccess: fetchedAt,
    total: entries.length,
    note: `catalog ${feed.catalogVersion ?? "?"}`,
  });
}

/* --------------------------------------------------------------- main ----- */

const { assets, platformIds } = syncAssets();
const assetIds = new Map();
for (const a of assets) {
  const row = db
    .prepare(
      "SELECT id FROM assets WHERE kind = ? AND name = ? AND version = ? AND scope = ? AND channel IS ?"
    )
    .get(a.kind, a.name, a.version, a.scope, a.channel ?? null);
  if (row) assetIds.set(`${a.kind}|${a.name}|${a.version}|${a.scope}|${a.channel ?? ""}`, row.id);
}

if (!SKIP_NVD) await syncNvd(platformIds);
if (!SKIP_OSV) await syncOsv(assets, assetIds);
await syncKev(platformIds);

const counts = db
  .prepare(
    `SELECT severity, COUNT(*) AS n FROM vulns GROUP BY severity ORDER BY n DESC`
  )
  .all();
log("db:", counts.map((c) => `${c.severity}=${c.n}`).join(" "));
log("done -> tool/vuln/data/tokigo-vuln.db");
db.close();
