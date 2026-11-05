#!/usr/bin/env node
/**
 * Render the vulnerability database into a human-readable report + JSON/CSV exports.
 *
 *   node tool/vuln/report.mjs
 */
import fs from "node:fs";
import path from "node:path";
import { LATEST_JSON, REPORT_DIR, SEVERITY_ORDER, apiLabel } from "./lib/config.mjs";
import { openDb, nowIso } from "./lib/db.mjs";

const db = openDb(false);
const generatedAt = nowIso();
const today = generatedAt.slice(0, 10);

const one = (sql, ...params) => db.prepare(sql).get(...params);
const all = (sql, ...params) => db.prepare(sql).all(...params);

const severityCounts = Object.fromEntries(SEVERITY_ORDER.map((s) => [s, 0]));
for (const row of all("SELECT severity, COUNT(*) n FROM vulns GROUP BY severity")) {
  severityCounts[row.severity] = row.n;
}

const totalVulns = Object.values(severityCounts).reduce((a, b) => a + b, 0);
const reachableVulns = one("SELECT COUNT(DISTINCT vuln_id) n FROM vuln_assets").n;
const reachableKev = one(
  "SELECT COUNT(DISTINCT v.id) n FROM vulns v JOIN vuln_assets va ON va.vuln_id = v.id WHERE v.kev = 1"
).n;

// depFindings.channel: 'prod' (runtime — backend server + Flutter app) vs 'dev' (build/CI/test only)
const depFindings = all(`
  SELECT v.id, v.severity, v.cvss_score, v.summary, v.kev, v.kev_due,
         a.name, a.version, a.scope, a.ecosystem, a.channel, va.fixed, va.reachability
  FROM vulns v
  JOIN vuln_assets va ON va.vuln_id = v.id
  JOIN assets a ON a.id = va.asset_id
  WHERE a.kind IN ('pub', 'npm', 'maven')
  ORDER BY v.kev DESC, COALESCE(v.cvss_score, 0) DESC
`);

const apisByRelease = all(`
  SELECT CAST(a.version AS INTEGER) AS api,
         COUNT(DISTINCT v.id) AS total,
         COUNT(DISTINCT CASE WHEN v.severity = 'critical' THEN v.id END) AS critical,
         COUNT(DISTINCT CASE WHEN v.severity = 'high' THEN v.id END) AS high,
         COUNT(DISTINCT CASE WHEN v.severity = 'medium' THEN v.id END) AS medium,
         COUNT(DISTINCT CASE WHEN v.severity = 'low' THEN v.id END) AS low,
         COUNT(DISTINCT CASE WHEN v.kev = 1 THEN v.id END) AS kev
  FROM vuln_assets va
  JOIN assets a ON a.id = va.asset_id
  JOIN vulns v ON v.id = va.vuln_id
  WHERE a.kind = 'android-platform'
  GROUP BY CAST(a.version AS INTEGER)
  ORDER BY api
`);

const platformFindings = all(`
  SELECT v.id, v.severity, v.cvss_score, v.summary, v.kev, v.kev_due, v.published,
         MIN(CAST(a.version AS INTEGER)) AS min_api,
         MAX(CAST(a.version AS INTEGER)) AS max_api,
         COUNT(*) AS apis,
         MAX(CASE WHEN va.match_type = 'platform-generic' THEN 1 ELSE 0 END) AS generic
  FROM vulns v
  JOIN vuln_assets va ON va.vuln_id = v.id
  JOIN assets a ON a.id = va.asset_id
  WHERE a.kind = 'android-platform'
  GROUP BY v.id
  ORDER BY v.kev DESC, COALESCE(v.cvss_score, 0) DESC
`);

const reachBySeverity = Object.fromEntries(
  all(`
    SELECT v.severity, COUNT(DISTINCT v.id) n
    FROM vulns v JOIN vuln_assets va ON va.vuln_id = v.id
    GROUP BY v.severity
  `).map((r) => [r.severity, r.n])
);

const distinctByKind = Object.fromEntries(
  all(`
    SELECT CASE WHEN a.kind = 'android-platform' THEN 'platform' ELSE 'dependency' END kind,
           COUNT(DISTINCT v.id) n
    FROM vulns v JOIN vuln_assets va ON va.vuln_id = v.id JOIN assets a ON a.id = va.asset_id
    GROUP BY 1
  `).map((r) => [r.kind, r.n])
);

const pubAdvisories = one(`
  SELECT COUNT(DISTINCT v.id) n
  FROM vulns v JOIN vuln_assets va ON va.vuln_id = v.id JOIN assets a ON a.id = va.asset_id
  WHERE a.ecosystem = 'Pub'
`).n;

const yearRows = all(`
  SELECT substr(v.published, 1, 4) AS year, v.severity, COUNT(*) AS n
  FROM vulns v
  WHERE v.id IN (SELECT vuln_id FROM vuln_assets) AND v.published IS NOT NULL
  GROUP BY year, v.severity
  ORDER BY year DESC
`);

const syncRows = all("SELECT * FROM sync_state ORDER BY source");

const prevSnapshot = one("SELECT * FROM snapshots ORDER BY id DESC LIMIT 1");

const platformReachable = platformFindings.length;
const dependencyReachable = depFindings.length;
const productionDeps = depFindings.filter((r) => r.channel !== "dev");
const devDeps = depFindings.filter((r) => r.channel === "dev");
const productionDistinct = new Set(productionDeps.map((r) => r.id)).size;
const devDistinct = new Set(devDeps.map((r) => r.id)).size;

const sevOf = (rows, s) => rows.filter((r) => r.severity === s).length;
const fmt = (n) => Number(n ?? 0).toLocaleString("en-US");
const esc = (s) =>
  String(s ?? "")
    .replace(/\|/g, "\\|")
    .replace(/\r?\n/g, " ")
    .trim();

/* -------------------------------------------------------------- exports --- */

fs.mkdirSync(REPORT_DIR, { recursive: true });
fs.mkdirSync(path.dirname(LATEST_JSON), { recursive: true });

const latest = {
  generatedAt,
  database: "tool/vuln/data/tokigo-vuln.db",
  totals: {
    all: totalVulns,
    reachable: reachableVulns,
    reachableKev,
    severity: severityCounts,
    dependencies: {
      total: distinctByKind.dependency ?? 0,
      production: productionDistinct,
      dev: devDistinct,
    },
    platform: distinctByKind.platform ?? 0,
  },
  dependencyFindings: depFindings,
  platformFindings,
  sync: syncRows,
};
fs.writeFileSync(LATEST_JSON, JSON.stringify(latest, null, 2));

const csvPath = path.join(path.dirname(LATEST_JSON), "android-platform-reachable.csv");
const csv = [
  "cve,severity,cvss,kev,min_api,max_api,apis,generic,published,summary",
  ...platformFindings.map((r) =>
    [
      r.id,
      r.severity,
      r.cvss_score ?? "",
      r.kev ? "yes" : "no",
      r.min_api ?? "",
      r.max_api ?? "",
      r.apis,
      r.generic ? "yes" : "no",
      r.published ?? "",
      `"${esc(r.summary).replace(/"/g, '""')}"`,
    ].join(",")
  ),
].join("\n");
fs.writeFileSync(csvPath, csv);

/* --------------------------------------------------------------- report --- */

const delta = (key) => {
  if (!prevSnapshot) return "";
  const prev = prevSnapshot[key] ?? 0;
  const cur = severityCounts[key] ?? 0;
  const d = cur - prev;
  return d === 0 ? "" : ` (${d > 0 ? "+" : ""}${d})`;
};

const kevList = platformFindings.filter((r) => r.kev).concat(depFindings.filter((r) => r.kev));
const topPlatform = platformFindings
  .filter((r) => r.severity === "critical" || r.severity === "high")
  .slice(0, 60);

const yearHistogram = new Map();
for (const row of yearRows) {
  if (!row.year) continue;
  const entry = yearHistogram.get(row.year) ?? { critical: 0, high: 0, medium: 0, low: 0, unknown: 0 };
  entry[row.severity] = (entry[row.severity] ?? 0) + row.n;
  yearHistogram.set(row.year, entry);
}

const lines = [];
const p = (s = "") => lines.push(s);

p(`# TokiGo — Vulnerability Database Report (${today})`);
p();
p("> Generated by `tool/vuln/collect.mjs` + `tool/vuln/report.mjs`.");
p("> Sources: NVD 2.0 (Android OS CPE), OSV.dev (Pub / npm / Maven), CISA KEV.");
p("> Classification: CVSS v3.x base score — Critical >= 9.0, High 7.0–8.9, Medium 4.0–6.9, Low 0.1–3.9.");
p();
p("## ملخص تنفيذي (Arabic summary)");
p();
p(`- إجمالي الثغرات في قاعدة البيانات: **${fmt(totalVulns)}** (أندرويد + مكوّنات TokiGo).`);
p(`- ثغرات تمسّ TokiGo فعلياً (نظام أندرويد 7.0–16 أو حزمة مستخدمة): **${fmt(reachableVulns)}**.`);
p(`- منها مُستغَلّة فعلياً في البراري (CISA KEV): **${fmt(reachableKev)}**.`);
p(`- ثغرات حرجة: **${fmt(severityCounts.critical)}**${delta("critical")} — عالية: **${fmt(severityCounts.high)}**${delta("high")} — متوسطة: **${fmt(severityCounts.medium)}**${delta("medium")} — منخفضة: **${fmt(severityCounts.low)}**${delta("low")}.`);
p(`- ثغرات حزم المشروع (Dart/npm/build): **${fmt(distinctByKind.dependency ?? 0)}** (منها Pub/Dart: ${pubAdvisories}؛ الإنتاج: ${productionDistinct}، أدوات dev/build: ${devDistinct})، وثغرات منصة أندرويد ضمن نطاق API ${one("SELECT MIN(version) a FROM assets WHERE kind='android-platform'").a}–${one("SELECT MAX(version) a FROM assets WHERE kind='android-platform'").a}: **${fmt(distinctByKind.platform ?? 0)}**.`);
p();
p("## Scope and method");
p();
p("- **Android platform**: every NVD CVE whose CPE is `cpe:2.3:o:google:android`, intersected with the API levels TokiGo declares (`minSdk` / `targetSdk`).");
p("- **TokiGo dependencies**: exact resolved versions from `pubspec.lock`, `backend/package-lock.json`, and the pinned Android build toolchain (AGP, Kotlin, Gradle). Each npm/pub component is tagged `prod` or `dev` (build/CI/test only) from the lockfile `dev` flag.");
p("- **Known exploited**: CISA KEV catalog, matched by CVE id or OSV alias.");
p("- `platform-unconfirmed` means NVD gives no version range for the CVE; treat as *assume affected until the device patch level is verified*.");
p();
p("## Totals by severity");
p();
p("| Severity | All CVEs | Reachable by TokiGo |");
p("| --- | ---: | ---: |");
for (const s of SEVERITY_ORDER) {
  p(`| ${s} | ${fmt(severityCounts[s])} | ${fmt(reachBySeverity[s] ?? 0)} |`);
}
p(`| **total** | **${fmt(totalVulns)}** | **${fmt(reachableVulns)}** |`);
p();

p("## Known exploited in the wild (CISA KEV)");
p();
if (!kevList.length) {
  p("_No reachable KEV entries in this snapshot._");
} else {
  p("| CVE | Severity | CVSS | Component | Due date |");
  p("| --- | --- | ---: | --- | --- |");
  const seen = new Set();
  for (const r of kevList) {
    if (seen.has(r.id)) continue;
    seen.add(r.id);
    const component = r.name
      ? `${r.name} ${r.version}`
      : `Android ${apiLabel(r.min_api)}${r.max_api && r.max_api !== r.min_api ? ` – ${apiLabel(r.max_api)}` : ""}${r.generic ? " (version unconfirmed)" : ""}`;
    p(`| ${r.id} | ${r.severity} | ${r.cvss_score ?? "—"} | ${esc(component)} | ${r.kev_due ?? "—"} |`);
  }
}
p();

p("## TokiGo dependency findings");
p();
if (!depFindings.length) {
  p("_No advisories matched the resolved dependency versions in this snapshot._");
} else {
  if (pubAdvisories === 0) {
    p(`_No open advisories matched the ${one("SELECT COUNT(*) n FROM assets WHERE ecosystem='Pub'").n} Dart/Flutter packages in \`pubspec.lock\`._`);
    p();
  }
  p(`Of the ${dependencyReachable} package/advisory hits, **${productionDistinct}** are unique advisories against production code (backend + Flutter app), and **${devDistinct}** against dev/build-time tooling.`);
  p();

  const writeTable = (title, rows) => {
    p(`### ${title}`);
    p();
    if (!rows.length) {
      p("_None._");
      p();
      return;
    }
    p("| Advisory | Severity | CVSS | Package | Installed | Scope | Fixed in | KEV |");
    p("| --- | --- | ---: | --- | --- | --- | --- | --- |");
    for (const r of rows) {
      p(`| ${r.id} | ${r.severity} | ${r.cvss_score ?? "—"} | ${esc(r.name)} | ${esc(r.version)} | ${r.scope} | ${r.fixed ?? "—"} | ${r.kev ? "YES" : ""} |`);
    }
    p();
  };

  writeTable(`Production findings (${new Set(productionDeps.map((r) => r.id)).size} unique)`, productionDeps);
  writeTable(`Dev / build-time findings (${new Set(devDeps.map((r) => r.id)).size} unique)`, devDeps);
}
p();

p("## Android platform CVEs by release");
p();
p("Each Android release counts every CVE whose NVD range intersects it, so a CVE appears under each API it affects. The `platform-unconfirmed` column is included in Total.");
p();
p("| API | Android | Total | Critical | High | Medium | Low | KEV |");
p("| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |");
for (const r of apisByRelease) {
  const names = { 24: "7.0", 25: "7.1", 26: "8.0", 27: "8.1", 28: "9", 29: "10", 30: "11", 31: "12", 32: "12L", 33: "13", 34: "14", 35: "15", 36: "16" };
  p(`| ${r.api} | Android ${names[r.api] ?? "?"} | ${fmt(r.total)} | ${fmt(r.critical)} | ${fmt(r.high)} | ${fmt(r.medium)} | ${fmt(r.low)} | ${fmt(r.kev)} |`);
}
p();

p("## Android platform CVEs reachable on TokiGo's supported range");
p();
p(`TokiGo installs on API 24 (Android 7.0) through API 36 (Android 16). Showing the highest-scoring ${topPlatform.length} of ${platformReachable}. Full list: \`tool/vuln/data/android-platform-reachable.csv\`.`);
p();
if (topPlatform.length) {
  p("| CVE | Severity | CVSS | Affected APIs | KEV | Published | Summary |");
  p("| --- | --- | ---: | --- | --- | --- | --- |");
  for (const r of topPlatform) {
    const range = r.generic && r.apis === 0
      ? "unconfirmed"
      : `${r.min_api}${r.max_api !== r.min_api ? `–${r.max_api}` : ""}${r.generic ? " + unconfirmed" : ""}`;
    p(`| ${r.id} | ${r.severity} | ${r.cvss_score ?? "—"} | ${range} | ${r.kev ? "YES" : ""} | ${r.published?.slice(0, 10) ?? "—"} | ${esc(r.summary).slice(0, 140)} |`);
  }
} else {
  p("_No reachable platform CVEs in this snapshot._");
}
p();

p("## Reachable CVEs per publication year");
p();
p("| Year | Critical | High | Medium | Low | Unknown |");
p("| --- | ---: | ---: | ---: | ---: | ---: |");
for (const [year, e] of [...yearHistogram.entries()].sort((a, b) => b[0].localeCompare(a[0]))) {
  p(`| ${year} | ${e.critical} | ${e.high} | ${e.medium} | ${e.low} | ${e.unknown} |`);
}
p();

p("## Recommended actions");
p();
p("1. **Production (runtime) findings first** — fix the server-side packages: `proxy-addr` (critical), `multer`/`body-parser` via `@nestjs/platform-express`, `lodash` via `@nestjs/config`, plus `qs`, `file-type`, `uuid`, `brace-expansion`, `glob`/`minimatch`/`typeorm`. `npm audit fix` in `backend/` resolves what stays semver-compatible, but several fixes are NestJS major (12.x). Plan the upgrade and re-run this report with `npm test`.");
p("2. **Dev/build-time findings can be deferred** — `handlebars`, `webpack`, `tmp`, `picomatch`, `js-yaml`, `jest` and friends do not ship in the APK, but they execute on developers' machines and in CI. Upgrade `@nestjs/cli` to >= 12.0.11 and the jest/ts-jest stack in a dedicated PR, then re-run the audit.");
p("3. **Android platform is not fixable by app code** — the only real mitigation is an up-to-date device security patch. Enforce a minimum patch level in Play Console / MDM, and consider raising `minSdk` (currently 24) to exclude devices that can never receive fixes.");
p("3. **Treat every KEV row as urgent** — these are confirmed exploited in the wild. For Android ones, require a patched OS build before release approval of any new build.");
p("4. **`platform-unconfirmed` entries** — NVD provides no version range; verify against the target device's security patch level instead of the app's compile/target SDK.");
p("5. **Refresh after every lockfile change** — the workflow `.github/workflows/vuln-db.yml` does this automatically; keep `NVD_API_KEY` in repo secrets for full-speed syncs.");
p();

p("## Sync status");
p();
p("| Source | Last success | Records | Note |");
p("| --- | --- | ---: | --- |");
for (const s of syncRows) {
  p(`| ${s.source} | ${s.last_success ?? "never"} | ${fmt(s.total)} | ${esc(s.note)} |`);
}
p();

p("## Query the database");
p();
p("```bash");
p("# counts by severity, reachable only");
p("node tool/vuln/query.mjs \\");
p("  \"SELECT v.severity, COUNT(DISTINCT v.id) FROM vulns v JOIN vuln_assets va ON va.vuln_id = v.id GROUP BY 1;\"");
p();
p("# every reachable Android CVE affecting API 34 and above");
p("node tool/vuln/query.mjs \\");
p("  \"SELECT v.id, v.cvss_score, a.version FROM vulns v JOIN vuln_assets va ON va.vuln_id = v.id JOIN assets a ON a.id = va.asset_id WHERE a.kind='android-platform' AND CAST(a.version AS INTEGER) >= 34 ORDER BY v.cvss_score DESC;\"");
p("```");
p();
p("## Refresh");
p();
p("```bash");
p("node tool/vuln/collect.mjs --skip-nvd   # dependency advisories only (seconds)");
p("node tool/vuln/collect.mjs              # incremental NVD + OSV + KEV (minutes)");
p("node tool/vuln/collect.mjs --full       # full NVD re-download");
p("node tool/vuln/report.mjs               # regenerate this report");
p("```");
p();
p(`_Report generated at ${generatedAt}._`);

const reportPath = path.join(REPORT_DIR, `vuln-report-${today}.md`);
fs.writeFileSync(reportPath, lines.join("\n") + "\n");

db.prepare(
  `INSERT INTO snapshots (created_at, critical, high, medium, low, kev, reachable, payload)
   VALUES (?, ?, ?, ?, ?, ?, ?, ?)`
).run(
  generatedAt,
  severityCounts.critical,
  severityCounts.high,
  severityCounts.medium,
  severityCounts.low,
  reachableKev,
  reachableVulns,
  JSON.stringify({ severityCounts, totalVulns, reachableVulns, reachableKev })
);
db.close();

console.log(`report -> ${path.relative(process.cwd(), reportPath)}`);
console.log(`json   -> ${path.relative(process.cwd(), LATEST_JSON)}`);
console.log(`csv    -> ${path.relative(process.cwd(), csvPath)}`);
console.log(
  `totals: all=${totalVulns} reachable=${reachableVulns} kev=${reachableKev} ` +
    `c/h/m/l=${severityCounts.critical}/${severityCounts.high}/${severityCounts.medium}/${severityCounts.low}`
);
