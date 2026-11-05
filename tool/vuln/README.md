# TokiGo — Vulnerability Database

All documented vulnerabilities that can reach **TokiGo**, classified by severity, refreshed daily.

## What is covered

| Layer | Source | What is matched |
| --- | --- | --- |
| Android OS (platform) | **NVD 2.0** `cpe:2.3:o:google:android` | Every CVE touching the Android platform, intersected with TokiGo's `minSdk` → `targetSdk` (API 24 → 36) |
| Dart / Flutter packages | **OSV.dev** (`Pub`) | Exact resolved versions in `pubspec.lock` |
| Backend / build packages | **OSV.dev** (`npm`, `Maven`) | `backend/package-lock.json` + pinned AGP / Kotlin / Gradle |
| Exploited in the wild | **CISA KEV** (catalog 2026.11.03) | Flagged by CVE id / OSV alias |

## Severity classification

CVSS v3.x base score:

- **Critical** ≥ 9.0
- **High** 7.0–8.9
- **Medium** 4.0–6.9
- **Low** 0.1–3.9
- Unknown = feed provides no CVSS (none at the time of writing)

Reachability labels:

- `direct` / `transitive` — package in the dependency graph (direct vs transitive)
- `prod` / `dev` — from the lockfile `dev` flag: `dev` means build/test/CI tooling (`@nestjs/cli`, jest, webpack, TypeScript) that **does not ship**, `prod` means runtime code shipped in the backend or the APK (plus the Android platform assets themselves)
- `platform` — Android OS CVE with a version/range intersecting API 24–36
- `platform-unconfirmed` — NVD has no version constraint; treat as *assume affected* until the device's Security patch level is verified

Third-party apps merely running on Android (Flash, Chrome, NetApp appliances, …) are **excluded**: only the Android platform itself is matched, per-configuration.

## How to run

```bash
node tool/vuln/collect.mjs          # incremental sync (full on first run)
node tool/vuln/collect.mjs --full   # re-download all Android CVEs (~3 min)
node tool/vuln/collect.mjs --skip-nvd   # dependencies only (seconds)
node tool/vuln/report.mjs           # regenerate docs/security/vuln-report-<date>.md
node tool/vuln/query.mjs "SELECT severity, COUNT(*) n FROM vulns GROUP BY 1"
```

Without an NVD API key, NVD allows 5 requests / 30 s; the collector waits accordingly. Set `NVD_API_KEY` for 50 requests / 30 s.

Outputs:

- `tool/vuln/data/tokigo-vuln.db` — SQLite (git-ignored, regenerated)
- `tool/vuln/data/android-platform-reachable.csv` — all reachable platform CVEs
- `tool/vuln/data/latest.json` — full machine-readable snapshot
- `docs/security/vuln-report-<date>.md` — human report (committed)

## Automation

`.github/workflows/vuln-db.yml` refreshes the database daily at 04:17 UTC and on any change to `pubspec.lock`, `backend/package-lock.json` or `android/**`:

- cron / manual → incremental (or full when requested) + report, committed to the repo
- push → dependency-only refresh, report uploaded as artifact (no commit, avoids loops)

The workflow caches `tool/vuln/data/tokigo-vuln.db` between runs.

## Limitations (read this)

1. **Android Security Bulletin CVEs that carry no NVD CPE are not linked** to the platform set. Most do, but a small number of ASB CVEs are only published in the bulletin. Subscribe to `source.android.com/docs/security/bulletin` for those.
2. **Android reachability is an intersection of declared API levels, not of device patch levels.** A device on `security patch 2026-11-01` has already fixed most 2025/2026 CVEs. Use the CSV + your MDM/inventory to see which devices are actually exposed.
3. **OSV `Pub` advisories are sparse** — zero open advisories matched TokiGo's locked Dart packages at the time of writing. Backend `npm` advisories **are** affected (see report).
4. **Build-time components** (AGP, Kotlin, Gradle) can execute code on dev machines and in CI — they are included, but they are not shipped in the APK.
5. The database is **only as fresh as its last run**; schedule the workflow or you are reading a stale snapshot.

## First result (2026-11-04)

- 9,764 vulnerabilities in DB (7,793 reachable by TokiGo's supported API range)
- 20 known-exploited (CISA KEV), all Android platform CVEs
- 0 open advisories against the locked Dart/Flutter packages
- 41 backend/build advisories (handlebars, multer, lodash, proxy-addr, js-yaml, …)
